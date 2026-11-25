--!strict
--[[
	DebugStageController (T02 spike, Studio only): keys 1-4 (top row or keypad) ask the server to switch the live
	dino to Hatchling / Juvenile / Sub-adult / Adult through the DebugSetStage remote.

	Presses are coalesced: the first goes out at once, and presses that come faster than the server's rate limit
	(Guard: burst 4, 2 per second) only update the pending stage, which is sent once the interval has passed.
	So spamming keys always ends on the last key pressed, and the server never has to drop a call.

	Does nothing outside Studio, and the server's Guard gate drops the remote outside Studio as well. The client
	only asks: DinoService decides and rescales. T05's InputController replaces the raw UserInputService hook,
	and T10's GrowthService makes stage changes real; this controller can then be deleted or moved to admin tools.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SEND_INTERVAL = 0.5 -- seconds between sends: the server refills 2 tokens per second

local KEY_STAGES: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
}

local DebugStageController = {}

local remote: RemoteEvent? = nil
local pendingStage: number? = nil
local lastSentAt = -math.huge
local flushScheduled = false

local function flush(): ()
	flushScheduled = false
	local stage = pendingStage
	if stage == nil or remote == nil then
		return
	end
	pendingStage = nil
	lastSentAt = os.clock()
	remote:FireServer(stage)
end

local function request(stage: number): ()
	pendingStage = stage -- a newer press replaces one that is still waiting
	if flushScheduled then
		return
	end
	local waitFor = lastSentAt + SEND_INTERVAL - os.clock()
	if waitFor <= 0 then
		flush()
	else
		flushScheduled = true
		task.delay(waitFor, flush)
	end
end

function DebugStageController:Start(): ()
	if not RunService:IsStudio() then
		return
	end
	local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")) :: any
	remote = Net.clientEvent("DebugSetStage")
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return -- typing in chat or a TextBox
		end
		local stage = KEY_STAGES[input.KeyCode]
		if stage then
			request(stage)
		end
	end)
end

return DebugStageController
