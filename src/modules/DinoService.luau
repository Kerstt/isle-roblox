--!strict
--[[
	DinoService: owns each player's dino character (doc 05 sections 1.2 and 2).

	T02 SPIKE SCOPE. This is the seed of the layer-2 DinoService that T04 grows (LifeState, RequestSpawn, kill,
	attributes, life mirror). What the spike does:
	- Players.CharacterAutoLoads = false at server start: no Roblox avatar is ever used.
	- Every player spawns as the Velociraptor rig (Shared/Dino/RigBuilder) at the SpawnLocation, as
	  player.Character, parented to Workspace, and respawns Players.RespawnTime seconds after the dino dies,
	  falls out of the world or is removed.
	- Registers the collision groups (Shared/CollisionGroups): the root is in "Dino" (Dino x Dino off), hitboxes
	  are in "DinoHitbox".
	- setStage(player, stage) rescales the LIVE character in place with RigBuilder.scaleTo (no character swap)
	  and sets WalkSpeed from species data (Shared/Species/Velociraptor). It checks that the player still owns
	  the root's physics afterwards.
	- Studio-only debug remote DebugSetStage(stage): Guard gate drops every call outside Studio.

	Spike shortcuts that T03/T04 replace (doc 05 section 1.5):
	- Listens to Players.PlayerAdded/PlayerRemoving itself. Rule 4 says only DataService does that: T04 spawns
	  from RequestSpawn after DataService.ProfileLoaded and clears state on ProfileReleased.
	- Death is Humanoid.Died (or the model/root leaving the world). T04 makes DinoService.kill the only death
	  path and stops using Humanoid health (doc 05 section 2.3).
	- The spawn stage is kept in server memory (the last stage set, Hatchling at first). T13 stores it in the slot.
	- The rig is built with base (Adult) proportions at every stage, so a stage change is a pure ScaleTo. The
	  Hatchling/Juvenile head bonus (doc 04 section 2.5) needs a rebuild when crossing those stages: T10 decides.
	- Spawns into Workspace, not workspace.Dinos (WorldService, T04).
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Attributes = require(Shared.Attributes)
local CollisionGroups = require(Shared.CollisionGroups)
local Config = require(Shared.Config)
local Growth = require(Shared.Logic.Growth)
local Net = require(Shared.Net)
local RigBuilder = require(Shared.Dino.RigBuilder)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local VelociraptorRig = require(Shared.Dino.RigSpecs.Velociraptor)
local Velociraptor = require(Shared.Species.Velociraptor)
local Check = require(script.Parent.Lib.Check)
local Guard = require(script.Parent.Lib.Guard)

export type Life = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	stage: number,
	generation: number,
}

local SPECIES: Types.SpeciesDef = Velociraptor
local FIRST_SPAWN_STAGE = 1 -- Hatchling, like a real first spawn
local STREAM_TIMEOUT = 10 -- seconds RequestStreamAroundAsync may wait before the dino is placed anyway

local DinoService = {}

-- Rule 1: signals and per-player state at the top level.
DinoService.Spawned = Signal.new() :: Signal.Signal<Player, Model>
DinoService.StageChanged = Signal.new() :: Signal.Signal<Player, number>
DinoService.Died = Signal.new() :: Signal.Signal<Player, string>

local lives: { [Player]: Life } = {}
local generations: { [Player]: number } = {} -- bumped on every spawn; stale respawns and death events compare it
local spawnStages: { [Player]: number } = {}
local lifeConnections: { [Player]: { RBXScriptConnection } } = {}

local function debugPrint(...: any): ()
	if Config.Debug then
		print("[DinoService]", ...)
	end
end

local function disconnectLife(player: Player): ()
	local list = lifeConnections[player]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
	end
	lifeConnections[player] = nil
end

local function ensureCollisionGroup(name: string): ()
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

local function registerCollisionGroups(): ()
	ensureCollisionGroup(CollisionGroups.Dino)
	ensureCollisionGroup(CollisionGroups.DinoHitbox)
	-- Client-owned dinos pushing each other is the main fling exploit and causes jitter (doc 05 section 2.2).
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Dino, CollisionGroups.Dino, false)
	-- DinoHitbox parts have CanCollide off, so they never collide; the group exists so combat queries can
	-- filter on it. Its collidability is left at the default so an OverlapParams query group can still see it.
end

-- Ground CFrame (feet level) on top of the place's SpawnLocation, facing its front, level.
-- T07 replaces this with tagged spawn points (Tags.SpawnPoint) chosen by WorldService.
local function spawnCFrame(): CFrame
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation and spawnLocation:IsA("SpawnLocation") then
		local top = spawnLocation.CFrame * CFrame.new(0, spawnLocation.Size.Y / 2, 0)
		local flat = top.LookVector * Vector3.new(1, 0, 1)
		local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
		return CFrame.lookAlong(top.Position, look)
	end
	local hit = Workspace:Raycast(Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0))
	return CFrame.new(if hit then hit.Position else Vector3.zero)
end

local function applyStage(model: Model, humanoid: Humanoid, stage: Types.StageDef, stageIndex: number): ()
	RigBuilder.scaleTo(model, stage.scale) -- also sets HipHeight = BaseHipHeight x scale
	humanoid.WalkSpeed = stage.walkSpeed -- ScaleTo does not scale WalkSpeed; sprint comes in T05/T06
	model:SetAttribute(Attributes.Stage, stageIndex)
end

local function ownerName(root: BasePart): string
	local ok, owner = pcall(root.GetNetworkOwner, root)
	if not ok then
		return "error: " .. tostring(owner)
	end
	return if owner then (owner :: Player).Name else "server"
end

local function onLifeEnded(player: Player, generation: number, cause: string): ()
	local life = lives[player]
	if life == nil or life.generation ~= generation then
		return
	end
	lives[player] = nil
	disconnectLife(player)
	debugPrint(player.Name, "died:", cause)
	DinoService.Died:Fire(player, cause)
	task.delay(Players.RespawnTime, function()
		if player.Parent == Players and generations[player] == generation then
			DinoService.trySpawn(player, "respawn")
		end
	end)
end

--[[
	Builds the dino, places it on the SpawnLocation and makes it the player's character. Replaces any current
	character (including a default avatar that loaded before CharacterAutoLoads was turned off). Yields while
	streaming in the spawn area; returns nil if the player left or a newer spawn started meanwhile.
]]
function DinoService.spawn(player: Player): Model?
	if player.Parent ~= Players then
		return nil
	end
	local generation = (generations[player] or 0) + 1
	generations[player] = generation
	lives[player] = nil
	disconnectLife(player)

	local stageIndex = spawnStages[player] or FIRST_SPAWN_STAGE
	local stage = Growth.stageAt(SPECIES.stages, stageIndex)
	assert(stage, "[DinoService] no stage " .. tostring(stageIndex) .. " for " .. SPECIES.id)

	local model = RigBuilder.build(VelociraptorRig)
	model.Name = player.Name
	model:SetAttribute(Attributes.Species, SPECIES.id)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart
	root.CollisionGroup = CollisionGroups.Dino
	applyStage(model, humanoid, stage, stageIndex)

	local target = spawnCFrame()
	if Workspace.StreamingEnabled then
		local ok, err = pcall(player.RequestStreamAroundAsync, player, target.Position, STREAM_TIMEOUT)
		if not ok then
			warn("[DinoService] RequestStreamAroundAsync failed for " .. player.Name .. ": " .. tostring(err))
		end
		if player.Parent ~= Players or generations[player] ~= generation then
			model:Destroy()
			return nil
		end
	end
	model:PivotTo(target) -- the pivot is the ground point under the root, so the feet land on the surface

	local previous = player.Character
	player.Character = model
	model.Parent = Workspace
	if previous and previous ~= model then
		previous:Destroy()
	end

	local life: Life = {
		model = model,
		humanoid = humanoid,
		root = root,
		stage = stageIndex,
		generation = generation,
	}
	lives[player] = life
	lifeConnections[player] = {
		humanoid.Died:Connect(function()
			onLifeEnded(player, generation, "Died")
		end),
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				onLifeEnded(player, generation, "Removed")
			end
		end),
		root.AncestryChanged:Connect(function()
			if not root:IsDescendantOf(model) then
				onLifeEnded(player, generation, "Fell") -- FallenPartsDestroyHeight removed the root
			end
		end),
	}
	debugPrint(player.Name, "spawned as", SPECIES.id, Growth.StageNames[stageIndex], "scale", stage.scale)
	DinoService.Spawned:Fire(player, model)
	return model
end

--[[
	Rescales the live character in place to `stageIndex` (1..4) and applies that stage's walk speed. No character
	swap: the camera subject, controls and network ownership stay. Returns false when the player has no live dino
	or the stage is invalid. Does not yield.
]]
function DinoService.setStage(player: Player, stageIndex: number): boolean
	local life = lives[player]
	local stage = Growth.stageAt(SPECIES.stages, stageIndex)
	if life == nil or stage == nil or not life.model:IsDescendantOf(Workspace) then
		return false
	end
	applyStage(life.model, life.humanoid, stage, stageIndex)
	life.stage = stageIndex
	spawnStages[player] = stageIndex

	-- T02 asks: does ScaleTo keep the player's network ownership? Check it, and put it back if not.
	local ok, owner = pcall(life.root.GetNetworkOwner, life.root)
	if ok and owner ~= player then
		local message = "[DinoService] %s lost root ownership after ScaleTo (owner %s); giving it back"
		warn(string.format(message, player.Name, ownerName(life.root)))
		pcall(life.root.SetNetworkOwner, life.root, player)
	end
	debugPrint(player.Name, "stage", Growth.StageNames[stageIndex], "scale", stage.scale, "owner", ownerName(life.root))
	DinoService.StageChanged:Fire(player, stageIndex)
	return true
end

-- spawn under xpcall: a failure is logged with the player's name instead of silently leaving them without a dino.
function DinoService.trySpawn(player: Player, reason: string): ()
	local ok, err = xpcall(DinoService.spawn, debug.traceback, player)
	if not ok then
		warn(string.format("[DinoService] %s failed for %s (%d): %s", reason, player.Name, player.UserId, err))
	end
end

function DinoService.getLife(player: Player): Life?
	return lives[player]
end

function DinoService.getStage(player: Player): number?
	local life = lives[player]
	return if life then life.stage else nil
end

local function onPlayerRemoving(player: Player): ()
	local life = lives[player]
	lives[player] = nil
	generations[player] = nil -- cancels a pending respawn
	spawnStages[player] = nil
	disconnectLife(player)
	Guard.forget(player)
	if life then
		task.defer(life.model.Destroy, life.model)
	end
end

function DinoService:Init(): ()
	Players.CharacterAutoLoads = false -- also set it in the place file (doc 05 section 2.2)
	registerCollisionGroups()

	Guard.on(Net.serverEvent("DebugSetStage"), {
		limit = { burst = 4, perSecond = 2 },
		args = { Check.integer(1, Growth.StageCount) },
		-- Studio only: outside Studio every call is a Gate drop (no strike, no effect).
		gate = function(player: Player): Life?
			if not RunService:IsStudio() then
				return nil
			end
			return lives[player]
		end,
	}, function(player: Player, _life: Life, stageIndex: number)
		DinoService.setStage(player, stageIndex)
	end)
end

function DinoService:Start(): ()
	Players.PlayerAdded:Connect(function(player: Player)
		DinoService.trySpawn(player, "spawn")
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(DinoService.trySpawn, player, "spawn")
	end
end

return DinoService
