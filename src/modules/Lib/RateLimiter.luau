--!strict
--[[
	RateLimiter: one token bucket per key (usually a Player).

		local limiter = RateLimiter.new({ burst = 6, perSecond = 4 })
		if not limiter:allow(player) then
			return -- over the limit: drop the request
		end

	Each key starts full with `burst` tokens and refills at `perSecond` tokens per second, never above `burst`.
	A call costs 1 token (or `cost`). Keys are held weakly, and forget(key) drops one at once.

	`clock` defaults to os.clock; specs inject a fake one. Pure: no require, no `game`, so it runs under Lune.
]]

export type Options = {
	burst: number,
	perSecond: number,
	clock: (() -> number)?,
}

export type RateLimiter = {
	burst: number,
	perSecond: number,
	allow: (self: RateLimiter, key: any, cost: number?) -> boolean,
	tokens: (self: RateLimiter, key: any) -> number,
	forget: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, updatedAt: number }

local function isPositiveFinite(value: any): boolean
	return type(value) == "number" and value > 0 and value ~= math.huge
end

local RateLimiter = {}

local Methods = {}
Methods.__index = Methods

local function refill(self: any, key: any): Bucket
	local now = self._clock()
	local bucket: Bucket? = self._buckets[key]
	if bucket == nil then
		local fresh = { tokens = self.burst, updatedAt = now }
		self._buckets[key] = fresh
		return fresh
	end
	-- max(0, ...): a clock that steps backwards must never drain or overfill the bucket.
	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min(self.burst, bucket.tokens + elapsed * self.perSecond)
	bucket.updatedAt = now
	return bucket
end

function Methods.allow(self: any, key: any, cost: number?): boolean
	local amount = cost or 1
	-- A negative or NaN cost would mint tokens: a programmer error, so it throws.
	local validCost = type(amount) == "number" and amount >= 0 and amount ~= math.huge
	assert(validCost, "RateLimiter: cost must be finite and >= 0")
	local bucket = refill(self, key)
	if bucket.tokens >= amount then
		bucket.tokens -= amount
		return true
	end
	return false
end

function Methods.tokens(self: any, key: any): number
	return refill(self, key).tokens
end

function Methods.forget(self: any, key: any): ()
	self._buckets[key] = nil
end

function RateLimiter.new(options: Options): RateLimiter
	assert(type(options) == "table", "RateLimiter.new expects an options table")
	assert(isPositiveFinite(options.burst), "RateLimiter: burst must be a positive finite number")
	assert(isPositiveFinite(options.perSecond), "RateLimiter: perSecond must be a positive finite number")
	local self = {
		burst = options.burst,
		perSecond = options.perSecond,
		_clock = options.clock or os.clock,
		_buckets = setmetatable({}, { __mode = "k" }),
	}
	return setmetatable(self, Methods) :: any
end

return table.freeze(RateLimiter)
