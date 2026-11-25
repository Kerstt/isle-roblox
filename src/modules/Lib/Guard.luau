--!strict
--[[
	Guard: the one wrapper every client-to-server remote goes through, so no handler can skip its checks.

		local Net = require(ReplicatedStorage.Shared.Net)
		local Guard = require(script.Parent.Lib.Guard)

		Guard.on(Net.serverEvent("Attack"), {
			limit = { burst = 6, perSecond = 4 },
			args = { Check.integer(1, 8) },
			gate = DinoService.getLife, -- passed in, so Guard (layer 0) requires no service
		}, function(player: Player, life: Types.LifeState, attackIndex: number)
			CombatService.handleAttack(player, life, attackIndex)
		end)

	Checks, in order. The first failure drops the call:
	1. RateLimit: token bucket per player for this remote (limit.burst, limit.perSecond).
	2. ArgCount: select("#", ...) must equal #args. Only trailing Check.optional args may be left out.
	3. ArgType: each argument must pass its checker (Lib/Check).
	4. Gate: gate(player) must return a non-nil value (state check: live dino, loaded profile). That value is
	   passed to the handler as its second argument.

	A dropped call returns nothing and never throws (log spam is a DoS vector). Every drop is counted per remote.
	RateLimit, ArgCount and ArgType drops also add a strike to the player. Gate drops do not: a request that
	arrives just after death is normal lag, not an exploit. Over `strikeLimit` strikes inside one `strikeWindow`
	calls onStrikeLimit once for that window. The default only warns: AntiCheatService (T09) installs hooks
	with setHooks and decides on kicks (log-only during week-1 playtests, doc 05 Decision 10).

	Errors: checkers, the gate, the handler and the hooks all run under xpcall. An error is reported once per
	remote (or hook) through hooks.onError, with a traceback (default: warn), the call counts as an "Error" drop
	(no strike: it is our bug, not the player's), and nothing is returned, so a RemoteFunction answers nil and
	the error never reaches the client. The gate and the handler must NOT yield: a yielding RemoteFunction handler
	keeps the client's InvokeServer waiting, and a yielding event handler holds its arguments past the checks.

	One registration per remote: Guard.on refuses a remote it already guards. Never set OnServerInvoke or connect
	OnServerEvent anywhere else; for a RemoteFunction that would silently replace Guard's checks.

	Per-player state is held weakly; DataService calls Guard.forget(player) on ProfileReleased (T03).

	Pure: requires only Check and RateLimiter, never touches `game`, so it runs under Lune. Guard.on takes the
	remote instance (from Net) instead of a name for that reason.
]]

local Check = require(script.Parent.Check)
local RateLimiter = require(script.Parent.RateLimiter)

export type DropReason = "RateLimit" | "ArgCount" | "ArgType" | "Gate" | "Error"

export type Spec = {
	limit: { burst: number, perSecond: number },
	args: { Check.Checker },
	gate: (player: Player) -> any,
}

export type Handler = (player: Player, state: any, ...any) -> ...any

export type Hooks = {
	onDrop: ((player: Player, remoteName: string, reason: DropReason) -> ())?,
	onStrikeLimit: ((player: Player, strikes: number) -> ())?,
	-- source is a remote name, or "hook:onDrop" / "hook:onStrikeLimit"; called once per source
	onError: ((source: string, message: string) -> ())?,
}

export type Options = {
	clock: (() -> number)?,
	strikeLimit: number?,
	strikeWindow: number?,
	hooks: Hooks?,
}

export type Guard = {
	wrap: (self: Guard, name: string, spec: Spec, handler: Handler) -> (player: Player, ...any) -> ...any,
	on: (self: Guard, remote: Instance, spec: Spec, handler: Handler) -> RBXScriptConnection?,
	setHooks: (self: Guard, hooks: Hooks) -> (),
	getStrikes: (self: Guard, player: Player) -> number,
	getDropCount: (self: Guard, remoteName: string?) -> number,
	forget: (self: Guard, player: Player) -> (),
}

type StrikeRecord = { count: number, windowStart: number, reported: boolean }

local DEFAULT_STRIKE_LIMIT = 30
local DEFAULT_STRIKE_WINDOW = 60

local function traceback(err: any): string
	return debug.traceback(tostring(err), 2)
end

local function describePlayer(player: any): string
	return string.format("%s (%s)", tostring(player.Name), tostring(player.UserId))
end

local function defaultOnStrikeLimit(player: Player, strikes: number): ()
	local message = "[Guard] %s reached %d strikes (malformed or flooded remote calls)"
	warn(string.format(message, describePlayer(player), strikes))
end

local function defaultOnError(source: string, message: string): ()
	warn(string.format("[Guard] %s errored (later errors from it are not logged): %s", source, message))
end

local function validateSpec(name: string, spec: Spec): ()
	local prefix = "[Guard] " .. name .. ": "
	assert(type(spec) == "table", prefix .. "spec must be a table")
	assert(type(spec.limit) == "table", prefix .. "spec.limit is required")
	assert(type(spec.args) == "table", prefix .. "spec.args is required (use {} for no arguments)")
	assert(type(spec.gate) == "function", prefix .. "spec.gate is required")
	local count = 0
	for index, checker in spec.args do
		local isChecker = type(index) == "number" and type(checker) == "function"
		assert(isChecker, prefix .. "spec.args must be a list of checkers")
		count += 1
	end
	local seenOptional = false
	for index = 1, count do
		local checker = spec.args[index]
		assert(checker ~= nil, prefix .. "spec.args has a hole at index " .. index)
		if Check.isOptional(checker) then
			seenOptional = true
		else
			assert(not seenOptional, prefix .. "a required argument cannot follow an optional one")
		end
	end
end

local Methods = {}
Methods.__index = Methods

local function reportError(self: any, source: string, message: string): ()
	if self._reportedErrors[source] then
		return
	end
	self._reportedErrors[source] = true
	local onError = self._hooks.onError or defaultOnError
	pcall(onError, source, message) -- a broken error hook must not break the remote either
end

local function callHook(self: any, hookName: string, fallback: ((...any) -> ())?, ...: any): ()
	local hook = self._hooks[hookName] or fallback
	if hook == nil then
		return
	end
	local ok, err = xpcall(hook, traceback, ...)
	if not ok then
		reportError(self, "hook:" .. hookName, err)
	end
end

local function addStrike(self: any, player: Player): ()
	local now = self._clock()
	local record: StrikeRecord? = self._strikes[player]
	if record == nil or now - record.windowStart >= self._strikeWindow then
		record = { count = 0, windowStart = now, reported = false }
		self._strikes[player] = record
	end
	local current = record :: StrikeRecord
	current.count += 1
	if current.count > self._strikeLimit and not current.reported then
		current.reported = true
		callHook(self, "onStrikeLimit", defaultOnStrikeLimit, player, current.count)
	end
end

local function drop(self: any, player: Player, name: string, reason: DropReason): ()
	self._dropTotal += 1
	self._dropCounts[name] = (self._dropCounts[name] or 0) + 1
	if reason == "RateLimit" or reason == "ArgCount" or reason == "ArgType" then
		addStrike(self, player)
	end
	callHook(self, "onDrop", nil, player, name, reason)
end

local function fail(self: any, player: Player, name: string, message: string): ()
	reportError(self, name, message)
	drop(self, player, name, "Error")
end

function Methods.wrap(self: any, name: string, spec: Spec, handler: Handler): (player: Player, ...any) -> ...any
	assert(type(name) == "string", "[Guard] wrap: name must be a string")
	validateSpec(name, spec)
	assert(type(handler) == "function", "[Guard] " .. name .. ": handler must be a function")

	local limiter = RateLimiter.new({
		burst = spec.limit.burst,
		perSecond = spec.limit.perSecond,
		clock = self._clock,
	})
	table.insert(self._limiters, limiter)

	local checkers = table.clone(spec.args)
	local maxCount = #checkers
	local requiredCount = maxCount
	while requiredCount > 0 and Check.isOptional(checkers[requiredCount]) do
		requiredCount -= 1
	end
	local gate = spec.gate

	return function(player: Player, ...: any): ...any
		if not limiter:allow(player) then
			return drop(self, player, name, "RateLimit")
		end
		local count = select("#", ...)
		if count < requiredCount or count > maxCount then
			return drop(self, player, name, "ArgCount")
		end
		local packed = table.pack(...)
		for index = 1, maxCount do
			local ok, valid = xpcall(checkers[index], traceback, packed[index])
			if not ok then
				return fail(self, player, name, valid)
			elseif valid ~= true then
				return drop(self, player, name, "ArgType")
			end
		end
		local gateOk, state = xpcall(gate, traceback, player)
		if not gateOk then
			return fail(self, player, name, state)
		elseif state == nil then
			return drop(self, player, name, "Gate")
		end
		local results = table.pack(xpcall(handler, traceback, player, state, ...))
		if not results[1] then
			return fail(self, player, name, results[2])
		end
		return table.unpack(results, 2, results.n)
	end
end

function Methods.on(self: any, remote: Instance, spec: Spec, handler: Handler): RBXScriptConnection?
	local name = remote.Name
	assert(not self._guarded[remote], "[Guard] " .. name .. " is already guarded (one registration per remote)")
	local wrapped = self:wrap(name, spec, handler)
	local anyRemote: any = remote
	if remote:IsA("RemoteFunction") then
		self._guarded[remote] = true
		anyRemote.OnServerInvoke = wrapped
		return nil
	elseif remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		self._guarded[remote] = true
		return anyRemote.OnServerEvent:Connect(wrapped)
	end
	error(string.format("[Guard] %s is a %s, not a client-to-server remote", name, remote.ClassName))
end

function Methods.setHooks(self: any, hooks: Hooks): ()
	assert(type(hooks) == "table", "[Guard] setHooks expects a table")
	self._hooks = hooks
end

function Methods.getStrikes(self: any, player: Player): number
	local record: StrikeRecord? = self._strikes[player]
	if record == nil or self._clock() - record.windowStart >= self._strikeWindow then
		return 0
	end
	return record.count
end

function Methods.getDropCount(self: any, remoteName: string?): number
	if remoteName == nil then
		return self._dropTotal
	end
	return self._dropCounts[remoteName] or 0
end

function Methods.forget(self: any, player: Player): ()
	self._strikes[player] = nil
	for _, limiter in self._limiters do
		limiter:forget(player)
	end
end

local function new(options: Options?): Guard
	local opts: Options = options or {}
	local self = {
		_clock = opts.clock or os.clock,
		_strikeLimit = opts.strikeLimit or DEFAULT_STRIKE_LIMIT,
		_strikeWindow = opts.strikeWindow or DEFAULT_STRIKE_WINDOW,
		_hooks = opts.hooks or {},
		_strikes = setmetatable({}, { __mode = "k" }),
		_guarded = setmetatable({}, { __mode = "k" }),
		_reportedErrors = {},
		_limiters = {},
		_dropCounts = {},
		_dropTotal = 0,
	}
	return setmetatable(self, Methods) :: any
end

-- The server-wide instance every service uses. Specs build their own with Guard.new and a fake clock.
local default = new()

return table.freeze({
	new = new,
	default = default,
	on = function(remote: Instance, spec: Spec, handler: Handler): RBXScriptConnection?
		return default:on(remote, spec, handler)
	end,
	wrap = function(name: string, spec: Spec, handler: Handler): (player: Player, ...any) -> ...any
		return default:wrap(name, spec, handler)
	end,
	setHooks = function(hooks: Hooks): ()
		default:setHooks(hooks)
	end,
	getStrikes = function(player: Player): number
		return default:getStrikes(player)
	end,
	getDropCount = function(remoteName: string?): number
		return default:getDropCount(remoteName)
	end,
	forget = function(player: Player): ()
		default:forget(player)
	end,
})
