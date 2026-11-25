--!strict
--[[
	CameraController (T02 spike; T05 grows it into doc 05's CameraController): keeps the default follow camera
	(PlayerModule, so mouse, touch and gamepad camera controls all still work) but fits it to the dino's size.

	The default camera aims a fixed 2 studs above the HumanoidRootPart (R15 rig with AutomaticScalingEnabled off)
	and starts at the StarterPlayer zoom. That suits a 5-stud avatar, not a 12.5-stud-long raptor at 0.37 to 1.0
	scale. On spawn and on every rescale this:
	- moves the focus to FOCUS_HEIGHT x scale above the root, via Humanoid.CameraOffset (local only);
	- sets the zoom to ADULT_ZOOM x scale (pins min = max for one frame, then reopens the range to
	  MIN_ZOOM_FACTOR..MAX_ZOOM_FACTOR x that zoom, so the player can still scroll or pinch).

	Scale comes from the rig contract: Humanoid.HipHeight = BaseHipHeight x scale (RigBuilder.scaleTo), and the
	HipHeight change is what triggers the refit, so it runs after the replicated rescale has arrived.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ADULT_ZOOM = 20 -- studs from focus to camera at scale 1 (the adult raptor is about 12.5 studs long)
local FOCUS_HEIGHT = 1.5 -- studs above the root centre at scale 1 (about the top of the back)
local DEFAULT_FOCUS_HEIGHT = 2 -- what PlayerModule adds above the root for this rig type
local MIN_ZOOM_FACTOR = 0.4
local MAX_ZOOM_FACTOR = 2.5
local ABSOLUTE_MIN_ZOOM = 0.5

local CameraController = {}

local player = Players.LocalPlayer
local characterConnections: { RBXScriptConnection } = {}
local fitToken = 0 -- bumped by every fit, so an older fit's delayed zoom-reopen cannot overwrite a newer one

local function scaleOf(character: Model, humanoid: Humanoid): number
	local base = character:GetAttribute("BaseHipHeight")
	if type(base) == "number" and base > 0 then
		return humanoid.HipHeight / base
	end
	return character:GetScale()
end

local function fit(character: Model, humanoid: Humanoid): ()
	local scale = scaleOf(character, humanoid)
	humanoid.CameraOffset = Vector3.new(0, FOCUS_HEIGHT * scale - DEFAULT_FOCUS_HEIGHT, 0)

	local zoom = ADULT_ZOOM * scale
	fitToken += 1
	local token = fitToken
	player.CameraMaxZoomDistance = math.max(zoom, player.CameraMinZoomDistance)
	player.CameraMinZoomDistance = zoom
	player.CameraMaxZoomDistance = zoom
	task.delay(0.1, function()
		if token == fitToken and player.Character == character then
			player.CameraMinZoomDistance = math.max(ABSOLUTE_MIN_ZOOM, zoom * MIN_ZOOM_FACTOR)
			player.CameraMaxZoomDistance = zoom * MAX_ZOOM_FACTOR
		end
	end)
end

local function onCharacterAdded(character: Model): ()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	if character:GetAttribute("Species") == nil then
		return -- not a dino (should not happen: the server never loads avatars)
	end
	local found = character:WaitForChild("Humanoid", 10)
	if found == nil or not found:IsA("Humanoid") or player.Character ~= character then
		return
	end
	local humanoid = found :: Humanoid -- IsA does not narrow for the type checker
	RunService.RenderStepped:Wait() -- let PlayerModule pick up the new camera subject first
	if player.Character ~= character then
		return -- respawned while waiting: the newer onCharacterAdded owns the camera now
	end
	fit(character, humanoid)
	table.insert(
		characterConnections,
		humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
			fit(character, humanoid)
		end)
	)
end

function CameraController:Start(): ()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return CameraController
