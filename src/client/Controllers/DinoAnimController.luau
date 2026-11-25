--!strict
--!native
--[[
	DinoAnimController: procedural animation for dino rigs (doc 04 section 3.2).

	SPIKE CODE (T02). Just enough motion that the raptor does not slide like a statue: a biped gait (thighs swing,
	knees lift the foot on the forward swing, feet stay level, small arm swing, hip bounce) driven by the root's
	real horizontal speed, a delayed tail wave and an idle breath. T05 grows this into the shared animator:
	PARAMS moves to Shared/Dino/AnimProfiles per species, quadruped gaits, run vs walk params, Action overlays
	(bite, eat, rest, hurt, death) from replicated attributes, footfall events for dust and sounds, and hiding
	Detail/Pattern zones past 150 studs (doc 04 section 6.4).

	How it works:
	- A set of tracked dinos is kept from CharacterAdded / CharacterRemoving (any player character with a Species
	  attribute), removed explicitly on CharacterRemoving, Destroying or when found unparented. Nothing scans the
	  players every frame.
	- Each rig caches its existing joints (per side, the tail chain) and its scale (updated on HipHeight change).
	  A rig missing a required joint is marked incomplete and only rescanned after a DescendantAdded, so a
	  half-streamed or broken rig costs nothing per frame. A joint that is removed marks the rig for a rescan.
	- Distance LOD from the camera (doc 04 section 6.4): every frame under 60 studs, 30 Hz to 150, 10 Hz with the
	  tail frozen to 300, frozen beyond. Dead dinos are skipped.
	- Motor6D.Transform is written in PreSimulation. Transforms are local only (nothing replicates), and the
	  server keeps seeing the rest pose, which is what hit detection uses (doc 04 section 2.6). Rotations need no
	  scaling; translations and stride length are multiplied by the model's scale.
	- Grounded comes from the replicated Humanoid state plus vertical speed, not FloorMaterial (which only the
	  network owner updates), so other players' dinos animate too.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Joint axes are the model's axes (rest pose = identity): +X rotation swings a hanging limb forward (-Z).
local PARAMS = table.freeze({
	strideLength = 7, -- studs travelled per full gait cycle at scale 1
	referenceSpeed = 14, -- speed (studs/s, adult walk) at which the gait reaches full amplitude
	thighSwing = math.rad(32),
	kneeBend = math.rad(40),
	armSwing = math.rad(12),
	hipBounce = 0.15, -- studs at scale 1, twice per cycle
	tailAmplitude = math.rad(7), -- per segment; segments add up down the chain
	tailFrequency = 0.6, -- Hz when idle; speeds up with movement
	tailLag = 0.7, -- radians of phase delay per tail segment
	breathRate = 1.6, -- radians per second
	breathPitch = math.rad(1.5),
	blendRate = 10, -- how fast the gait amount follows speed (per second)
	airborneVerticalSpeed = 12, -- studs/s up or down: treated as airborne whatever the state says
})

-- Distance LOD (doc 04 section 6.4): { max distance, seconds between updates, animate the tail }.
local LOD_BANDS = table.freeze({
	table.freeze({ maxDistance = 60, interval = 0, tail = true }),
	table.freeze({ maxDistance = 150, interval = 1 / 30, tail = true }),
	table.freeze({ maxDistance = 300, interval = 1 / 10, tail = false }),
})

local SIDE_BONES = table.freeze({
	table.freeze({
		upper = "HindUpper_L",
		lower = "HindLower_L",
		foot = "HindFoot_L",
		arm = "ForeUpper_L",
		offset = 0,
	}),
	table.freeze({
		upper = "HindUpper_R",
		lower = "HindLower_R",
		foot = "HindFoot_R",
		arm = "ForeUpper_R",
		offset = math.pi,
	}),
})
local TAIL_BONES = table.freeze({ "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6" })
local REQUIRED = table.freeze({
	"Hips",
	"Torso",
	"HindUpper_L",
	"HindLower_L",
	"HindFoot_L",
	"HindUpper_R",
	"HindLower_R",
	"HindFoot_R",
	"Tail1",
})
local AIRBORNE_STATES: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Flying] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
}
local TWO_PI = 2 * math.pi

type Side = { upper: Motor6D, lower: Motor6D, foot: Motor6D, arm: Motor6D?, offset: number }

type Rig = {
	model: Model,
	root: BasePart?,
	humanoid: Humanoid?,
	hips: Motor6D?,
	torso: Motor6D?,
	sides: { Side },
	tail: { Motor6D }, -- only the tail joints this rig has, in chain order
	complete: boolean, -- false: a required joint is missing; skipped until something is added
	dirty: boolean, -- rescan joints before the next update
	scale: number,
	gaitPhase: number,
	tailPhase: number,
	time: number,
	amount: number, -- 0 idle .. 1 full gait
	sinceUpdate: number, -- seconds since the last LOD update
	connections: { RBXScriptConnection },
}

local DinoAnimController = {}

local rigs: { [Model]: Rig } = {}

local function readScale(rig: Rig): ()
	local humanoid = rig.humanoid
	local base = rig.model:GetAttribute("BaseHipHeight")
	if humanoid and type(base) == "number" and base > 0 then
		rig.scale = math.max(humanoid.HipHeight / base, 0.05)
	else
		rig.scale = math.max(rig.model:GetScale(), 0.05)
	end
end

local function watchHumanoid(rig: Rig, humanoid: Humanoid): ()
	if rig.humanoid == humanoid then
		return
	end
	rig.humanoid = humanoid
	table.insert(
		rig.connections,
		humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
			readScale(rig)
		end)
	)
	readScale(rig)
end

-- Rebuilds the joint lists from what the model has right now. Marks the rig incomplete if anything required
-- is missing; it is then skipped until a DescendantAdded marks it dirty again.
local function scan(rig: Rig): ()
	rig.dirty = false
	local model = rig.model
	rig.root = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		watchHumanoid(rig, humanoid)
	end
	local joints: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and string.sub(descendant.Name, 1, 2) == "J_" then
			joints[string.sub(descendant.Name, 3)] = descendant
		end
	end
	local complete = rig.root ~= nil and humanoid ~= nil
	for _, name in REQUIRED do
		if joints[name] == nil then
			complete = false
		end
	end
	rig.complete = complete
	if not complete then
		return
	end
	rig.hips = joints.Hips
	rig.torso = joints.Torso
	table.clear(rig.sides)
	for _, bones in SIDE_BONES do
		table.insert(rig.sides, {
			upper = joints[bones.upper] :: Motor6D, -- required: checked above
			lower = joints[bones.lower] :: Motor6D,
			foot = joints[bones.foot] :: Motor6D,
			arm = joints[bones.arm],
			offset = bones.offset,
		})
	end
	table.clear(rig.tail)
	for _, name in TAIL_BONES do
		local joint = joints[name]
		if joint == nil then
			break -- the chain ends at the first missing segment
		end
		table.insert(rig.tail, joint)
	end
end

local function untrack(model: Model): ()
	local rig = rigs[model]
	if rig == nil then
		return
	end
	rigs[model] = nil
	for _, connection in rig.connections do
		connection:Disconnect()
	end
end

local function track(model: Model): ()
	if rigs[model] then
		return
	end
	if model:GetAttribute("Species") == nil then
		-- Not a dino yet (the server sets Species when it builds the rig); look again if it appears.
		model:GetAttributeChangedSignal("Species"):Once(function()
			if model.Parent then
				track(model)
			end
		end)
		return
	end
	local rig: Rig = {
		model = model,
		root = nil,
		humanoid = nil,
		hips = nil,
		torso = nil,
		sides = {},
		tail = {},
		complete = false,
		dirty = true,
		scale = 1,
		gaitPhase = 0,
		tailPhase = math.random() * TWO_PI, -- so two dinos side by side do not sway in lockstep
		time = 0,
		amount = 0,
		sinceUpdate = math.huge, -- update on the first frame it is in range
		connections = {},
	}
	rigs[model] = rig
	table.insert(
		rig.connections,
		model.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("Motor6D") or descendant:IsA("Humanoid") or descendant:IsA("BasePart") then
				rig.dirty = true
			end
		end)
	)
	table.insert(
		rig.connections,
		model.DescendantRemoving:Connect(function(descendant: Instance)
			if descendant:IsA("Motor6D") or descendant:IsA("Humanoid") or descendant == rig.root then
				rig.dirty = true
			end
		end)
	)
	table.insert(
		rig.connections,
		model.Destroying:Connect(function()
			untrack(model)
		end)
	)
end

local function watchPlayer(player: Player): ()
	player.CharacterAdded:Connect(track)
	player.CharacterRemoving:Connect(untrack)
	-- Also catches a character that streams back in as a new instance (track ignores models it already has).
	player:GetPropertyChangedSignal("Character"):Connect(function()
		local character = player.Character
		if character then
			track(character)
		end
	end)
	if player.Character then
		track(player.Character)
	end
end

local function step(rig: Rig, root: BasePart, humanoid: Humanoid, dt: number, animateTail: boolean): ()
	local scale = rig.scale
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local airborne = AIRBORNE_STATES[humanoid:GetState()] == true or math.abs(velocity.Y) > PARAMS.airborneVerticalSpeed
	local grounded = not airborne

	-- Gait amount follows speed (relative to the dino's size), smoothed so starts and stops blend.
	local target = if grounded then math.clamp(speed / (PARAMS.referenceSpeed * math.max(scale, 0.3)), 0, 1) else 0
	rig.amount += (target - rig.amount) * (1 - math.exp(-PARAMS.blendRate * dt))
	rig.time += dt
	if grounded then
		rig.gaitPhase = (rig.gaitPhase + TWO_PI * speed / (PARAMS.strideLength * scale) * dt) % TWO_PI
	end

	local amount = rig.amount
	for _, side in rig.sides do
		local phase = rig.gaitPhase + side.offset
		local swing = math.sin(phase)
		local thigh = swing * PARAMS.thighSwing * amount
		local knee = -math.max(0, math.cos(phase)) * PARAMS.kneeBend * amount -- lift the foot on the forward swing
		side.upper.Transform = CFrame.Angles(thigh, 0, 0)
		side.lower.Transform = CFrame.Angles(knee, 0, 0)
		side.foot.Transform = CFrame.Angles(-(thigh + knee), 0, 0) -- keep the foot level
		local arm = side.arm
		if arm then
			arm.Transform = CFrame.Angles(-swing * PARAMS.armSwing * amount, 0, 0)
		end
	end

	local hips, torso = rig.hips, rig.torso
	if hips then
		hips.Transform = CFrame.new(0, math.abs(math.sin(rig.gaitPhase)) * PARAMS.hipBounce * scale * amount, 0)
	end
	if torso then
		local breath = math.sin(rig.time * PARAMS.breathRate) * PARAMS.breathPitch * (1 - amount)
		torso.Transform = CFrame.Angles(breath, 0, 0)
	end

	if animateTail then
		rig.tailPhase = (rig.tailPhase + TWO_PI * (PARAMS.tailFrequency * (1 + amount)) * dt) % TWO_PI
		local tailAmplitude = PARAMS.tailAmplitude * (1 - 0.4 * amount) -- stiffer tail at speed
		for index, joint in rig.tail do
			joint.Transform = CFrame.Angles(0, math.sin(rig.tailPhase - index * PARAMS.tailLag) * tailAmplitude, 0)
		end
	end
end

local function onPreSimulation(dt: number): ()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for model, rig in rigs do
		if rig.dirty then
			scan(rig)
		end
		if model.Parent == nil then
			untrack(model) -- removed or streamed out without Destroying (removing during traversal is allowed)
			continue
		end
		local root, humanoid = rig.root, rig.humanoid
		if not rig.complete or root == nil or humanoid == nil then
			continue
		end
		if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
			continue
		end
		rig.sinceUpdate += dt
		local distance = (root.Position - eye).Magnitude
		for _, band in LOD_BANDS do
			if distance <= band.maxDistance then
				if rig.sinceUpdate >= band.interval then
					-- Clamp so a dino coming back into range does not jump its phases by a huge dt.
					step(rig, root, humanoid, math.min(rig.sinceUpdate, 0.25), band.tail)
					rig.sinceUpdate = 0
				end
				break
			end
		end
		-- Beyond the last band: frozen in its last pose.
	end
end

function DinoAnimController:Start(): ()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	RunService.PreSimulation:Connect(onPreSimulation)
end

return DinoAnimController
