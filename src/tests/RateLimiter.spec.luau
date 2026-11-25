--!strict
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	local RateLimiter = t.load("Modules/Lib/RateLimiter")
	local expect = t.expect

	-- A fake clock the specs move by hand.
	local function makeClock(): ({ now: number }, () -> number)
		local state = { now = 100 }
		return state, function(): number
			return state.now
		end
	end

	local function allowMany(limiter: any, key: any, times: number): number
		local allowed = 0
		for _ = 1, times do
			if limiter:allow(key) then
				allowed += 1
			end
		end
		return allowed
	end

	t.describe("RateLimiter burst", function()
		t.it("allows exactly `burst` calls at once, then refuses", function()
			local _, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 6, perSecond = 4, clock = clock })
			expect(allowMany(limiter, "a", 20)).toBe(6)
			expect(limiter:allow("a")).toBe(false)
		end)
		t.it("keeps a separate bucket per key", function()
			local _, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 2, perSecond = 1, clock = clock })
			expect(allowMany(limiter, "a", 5)).toBe(2)
			expect(allowMany(limiter, "b", 5)).toBe(2)
		end)
		t.it("charges `cost` tokens and refuses a call it cannot afford", function()
			local _, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 5, perSecond = 1, clock = clock })
			expect(limiter:allow("a", 3)).toBe(true)
			expect(limiter:allow("a", 3)).toBe(false)
			expect(limiter:tokens("a")).toBeNear(2)
		end)
		t.it("throws on a negative, NaN or infinite cost (it would mint tokens)", function()
			local _, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 5, perSecond = 1, clock = clock })
			for _, cost in { -1, 0 / 0, math.huge } do
				expect(function()
					limiter:allow("a", cost)
				end).toThrow("cost")
			end
			expect(limiter:tokens("a")).toBeNear(5)
		end)
	end)

	t.describe("RateLimiter refill", function()
		t.it("refills at perSecond tokens per second", function()
			local time, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 6, perSecond = 4, clock = clock })
			allowMany(limiter, "a", 6)
			time.now += 0.5 -- 0.5 s * 4/s = 2 tokens
			expect(allowMany(limiter, "a", 10)).toBe(2)
			time.now += 0.25 -- 1 token
			expect(allowMany(limiter, "a", 10)).toBe(1)
		end)
		t.it("never refills above burst", function()
			local time, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 3, perSecond = 10, clock = clock })
			allowMany(limiter, "a", 3)
			time.now += 60
			expect(limiter:tokens("a")).toBeNear(3)
			expect(allowMany(limiter, "a", 10)).toBe(3)
		end)
		t.it("handles slow limits like 1 burst per 5 s (perSecond = 0.2)", function()
			local time, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 1, perSecond = 0.2, clock = clock })
			expect(limiter:allow("a")).toBe(true)
			time.now += 4.9
			expect(limiter:allow("a")).toBe(false)
			time.now += 0.2
			expect(limiter:allow("a")).toBe(true)
		end)
		t.it("ignores a clock that steps backwards", function()
			local time, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 2, perSecond = 1, clock = clock })
			allowMany(limiter, "a", 2)
			time.now -= 50
			expect(limiter:tokens("a")).toBeNear(0)
			expect(limiter:allow("a")).toBe(false)
		end)
	end)

	t.describe("RateLimiter.forget", function()
		t.it("drops a key, so it starts full again", function()
			local _, clock = makeClock()
			local limiter = RateLimiter.new({ burst = 2, perSecond = 1, clock = clock })
			allowMany(limiter, "a", 2)
			limiter:forget("a")
			expect(allowMany(limiter, "a", 5)).toBe(2)
		end)
	end)

	t.describe("RateLimiter.new", function()
		t.it("rejects zero, negative, NaN and infinite settings", function()
			expect(function()
				RateLimiter.new({ burst = 0, perSecond = 1 })
			end).toThrow("burst")
			expect(function()
				RateLimiter.new({ burst = 1, perSecond = -1 })
			end).toThrow("perSecond")
			expect(function()
				RateLimiter.new({ burst = 0 / 0, perSecond = 1 })
			end).toThrow("burst")
			expect(function()
				RateLimiter.new({ burst = 1, perSecond = math.huge })
			end).toThrow("perSecond")
		end)
	end)
end
