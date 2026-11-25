--!strict
--[[
	Scheduler: every server loop runs from one Heartbeat connection (doc 05 section 3.1).

		Scheduler.every(0.2, "CarcassDecay", function(dt: number) ... end)
		Scheduler.everyPlayer(1, "Needs", function(player: Player, dt: number) ... end)

	every: runs the job once per `interval` seconds. everyPlayer: runs the job once per `interval` for each player,
	with each player's turn spread across the interval (golden-ratio offsets), so 30 players do not all tick on
	the same frame. A player who leaves is dropped from the job on the next step. `dt` is the real time since that
	job (or that player's turn) last ran. If the server falls behind, missed runs are skipped, never bunched up.

	Each run is wrapped in debug.profilebegin(name) for the MicroProfiler and in xpcall: an erroring job is
	reported and keeps its schedule. Jobs must not yield. Both functions return a handle with :Cancel().

	The module functions use one shared instance that connects to RunService.Heartbeat on first use. Specs build
	their own with Scheduler.new({ clock = ..., getPlayers = ... }) and call :step() by hand; nothing touches
	`game` unless the default instance is used, so the module runs under Lune.
]]

export type Handle = {
	Cancel: (self: Handle) -> (),
}

export type Options = {
	clock: (() -> number)?,
	getPlayers: (() -> { Player })?,
	onError: ((jobName: string, message: string) -> ())?,
}

export type Scheduler = {
	every: (self: Scheduler, interval: number, name: string, job: (dt: number) -> ()) -> Handle,
	everyPlayer: (self: Scheduler, interval: number, name: string, job: (player: Player, dt: number) -> ()) -> Handle,
	step: (self: Scheduler) -> (),
	start: (self: Scheduler) -> (),
	stop: (self: Scheduler) -> (),
}

type PlayerTurn = { nextDue: number, lastRun: number }

type Job = {
	name: string,
	interval: number,
	active: boolean,
	perPlayer: boolean,
	run: (...any) -> (),
	nextDue: number,
	lastRun: number,
	turns: { [any]: PlayerTurn },
	spreadIndex: number,
}

local GOLDEN_RATIO_FRACTION = 0.6180339887

local profileBegin: ((label: string) -> ())? = (debug :: any).profilebegin
local profileEnd: (() -> ())? = (debug :: any).profileend

local function traceback(err: any): string
	return debug.traceback(tostring(err), 2)
end

local function defaultOnError(jobName: string, message: string): ()
	-- Raised in its own thread: logged as an error without stopping the Heartbeat step.
	task.spawn(error, string.format("[Scheduler] job %s failed: %s", jobName, message), 0)
end

local function defaultGetPlayers(): { Player }
	return game:GetService("Players"):GetPlayers()
end

local HandleMethods = {}
HandleMethods.__index = HandleMethods

function HandleMethods.Cancel(self: any): ()
	self._job.active = false
	local jobs = self._scheduler._jobs
	local index = table.find(jobs, self._job)
	if index then
		table.remove(jobs, index)
	end
end

local Methods = {}
Methods.__index = Methods

local function runJob(self: any, job: Job, ...: any): ()
	if profileBegin then
		profileBegin(job.name)
	end
	local ok, err = xpcall(job.run, traceback, ...)
	if profileEnd then
		profileEnd()
	end
	if not ok then
		self._onError(job.name, err)
	end
end

local function addJob(self: any, interval: number, name: string, run: (...any) -> (), perPlayer: boolean): Handle
	assert(type(interval) == "number" and interval > 0 and interval ~= math.huge, "Scheduler: bad interval")
	assert(type(name) == "string", "Scheduler: name must be a string")
	assert(type(run) == "function", "Scheduler: job must be a function")
	local now = self._clock()
	local job: Job = {
		name = name,
		interval = interval,
		active = true,
		perPlayer = perPlayer,
		run = run,
		nextDue = now + interval,
		lastRun = now,
		turns = {},
		spreadIndex = 0,
	}
	table.insert(self._jobs, job)
	return setmetatable({ _job = job, _scheduler = self }, HandleMethods) :: any
end

function Methods.every(self: any, interval: number, name: string, job: (dt: number) -> ()): Handle
	return addJob(self, interval, name, job, false)
end

function Methods.everyPlayer(self: any, interval: number, name: string, job: (player: Player, dt: number) -> ()): Handle
	return addJob(self, interval, name, job, true)
end

local function stepGlobal(self: any, job: Job, now: number): ()
	if now < job.nextDue then
		return
	end
	local dt = now - job.lastRun
	job.lastRun = now
	job.nextDue += job.interval
	if job.nextDue <= now then
		job.nextDue = now + job.interval -- fell behind: skip the missed runs
	end
	runJob(self, job, dt)
end

local function stepPerPlayer(self: any, job: Job, now: number, players: { Player }, present: { [any]: boolean }): ()
	for player in job.turns do
		if not present[player] then
			job.turns[player] = nil
		end
	end
	for _, player in players do
		if not job.active then
			return -- cancelled by an earlier run in this step
		end
		local turn = job.turns[player]
		if turn == nil then
			local phase = math.fmod(job.spreadIndex * GOLDEN_RATIO_FRACTION, 1)
			local offset = phase * job.interval
			job.spreadIndex += 1
			turn = { nextDue = now + offset, lastRun = now + offset - job.interval }
			job.turns[player] = turn
		end
		local current = turn :: PlayerTurn
		if now >= current.nextDue then
			local dt = now - current.lastRun
			current.lastRun = now
			current.nextDue += job.interval
			if current.nextDue <= now then
				current.nextDue = now + job.interval
			end
			runJob(self, job, player, dt)
		end
	end
end

function Methods.step(self: any): ()
	local now = self._clock()
	local players: { Player }? = nil
	local present: { [any]: boolean } = {}
	-- Snapshot: a job may cancel itself or add another job while it runs.
	for _, job in table.clone(self._jobs) do
		if not job.active then
			continue
		end
		if job.perPlayer then
			if players == nil then
				players = self._getPlayers()
				for _, player in players :: { Player } do
					present[player] = true
				end
			end
			stepPerPlayer(self, job, now, players :: { Player }, present)
		else
			stepGlobal(self, job, now)
		end
	end
end

function Methods.start(self: any): ()
	if self._connection then
		return
	end
	local RunService = game:GetService("RunService")
	self._connection = RunService.Heartbeat:Connect(function()
		self:step()
	end)
end

function Methods.stop(self: any): ()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

local function new(options: Options?): Scheduler
	local opts: Options = options or {}
	local self = {
		_clock = opts.clock or os.clock,
		_getPlayers = opts.getPlayers or defaultGetPlayers,
		_onError = opts.onError or defaultOnError,
		_jobs = {},
		_connection = nil :: RBXScriptConnection?,
	}
	return setmetatable(self, Methods) :: any
end

local default: Scheduler? = nil

local function getDefault(): Scheduler
	local existing = default
	if existing then
		return existing
	end
	local scheduler = new()
	scheduler:start()
	default = scheduler
	return scheduler
end

return table.freeze({
	new = new,
	every = function(interval: number, name: string, job: (dt: number) -> ()): Handle
		return getDefault():every(interval, name, job)
	end,
	everyPlayer = function(interval: number, name: string, job: (player: Player, dt: number) -> ()): Handle
		return getDefault():everyPlayer(interval, name, job)
	end,
})
