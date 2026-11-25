--!strict
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	local Guard = t.load("Modules/Lib/Guard")
	local Check = t.load("Modules/Lib/Check")
	local expect = t.expect

	local NAN = 0 / 0

	local function fakePlayer(userId: number): any
		return { Name = "Tester" .. userId, UserId = userId }
	end

	-- A stand-in for a RemoteEvent: Guard.on connects to OnServerEvent, and fire() plays a client call.
	local function fakeRemoteEvent(name: string): any
		local handlers = {}
		local remote: any = {
			Name = name,
			ClassName = "RemoteEvent",
			OnServerEvent = {
				Connect = function(_self: any, handler: (...any) -> ())
					table.insert(handlers, handler)
					return {}
				end,
			},
		}
		function remote.IsA(_self: any, className: string): boolean
			return className == "RemoteEvent"
		end
		function remote.fire(player: any, ...: any)
			for _, handler in handlers do
				handler(player, ...)
			end
		end
		return remote
	end

	-- A fresh Guard with a fake clock, plus a log of handler calls, drops, strike-limit reports and errors.
	local function setup(strikeLimit: number?)
		local time = { now = 0 }
		local log = { calls = {}, drops = {}, strikeReports = {}, errors = {} }
		local guard = Guard.new({
			clock = function(): number
				return time.now
			end,
			strikeLimit = strikeLimit or 30,
			strikeWindow = 60,
			hooks = {
				onDrop = function(_player: any, remoteName: string, reason: string)
					table.insert(log.drops, remoteName .. ":" .. reason)
				end,
				onStrikeLimit = function(player: any, strikes: number)
					table.insert(log.strikeReports, { userId = player.UserId, strikes = strikes })
				end,
				onError = function(source: string, message: string)
					table.insert(log.errors, { source = source, message = message })
				end,
			},
		})
		return guard, time, log
	end

	local function attackSpec(gate: ((player: any) -> any)?): any
		return {
			limit = { burst = 6, perSecond = 4 },
			args = { Check.integer(1, 8) },
			gate = gate or function(_player: any)
				return "alive"
			end,
		}
	end

	t.describe("Guard: valid calls", function()
		t.it("calls the handler with the player, the gate result and the arguments", function()
			local guard, _, log = setup()
			local player = fakePlayer(1)
			local wrapped = guard:wrap("Attack", attackSpec(), function(who: any, state: any, attackIndex: number)
				table.insert(log.calls, { who = who, state = state, attackIndex = attackIndex })
				return "handled"
			end)
			expect(wrapped(player, 3)).toBe("handled")
			expect(#log.calls).toBe(1)
			expect(log.calls[1].who).toBe(player)
			expect(log.calls[1].state).toBe("alive")
			expect(log.calls[1].attackIndex).toBe(3)
			expect(guard:getDropCount()).toBe(0)
			expect(guard:getStrikes(player)).toBe(0)
		end)
	end)

	t.describe("Guard: dummy remote", function()
		t.it("rejects bad arguments and floods arriving through OnServerEvent", function()
			local guard, time, log = setup()
			local player = fakePlayer(1)
			local remote = fakeRemoteEvent("Dummy")
			guard:on(remote, attackSpec(), function(_who: any, _state: any, attackIndex: number)
				table.insert(log.calls, attackIndex)
			end)

			remote.fire(player, "1") -- wrong type
			remote.fire(player, NAN) -- NaN
			remote.fire(player, 9) -- out of range
			remote.fire(player) -- too few
			remote.fire(player, 1, 2) -- too many
			expect(#log.calls).toBe(0)
			expect(guard:getDropCount("Dummy")).toBe(5)

			time.now += 10 -- refill the bucket after the bad calls above
			for _ = 1, 50 do
				remote.fire(player, 2)
			end
			expect(#log.calls).toBe(6) -- burst only
			expect(guard:getDropCount("Dummy")).toBe(5 + 44)
		end)
	end)

	t.describe("Guard: rate limit", function()
		t.it("refills over time and limits each player separately", function()
			local guard, time, log = setup()
			local wrapped = guard:wrap("Attack", attackSpec(), function(who: any)
				table.insert(log.calls, who.UserId)
			end)
			local first, second = fakePlayer(1), fakePlayer(2)
			for _ = 1, 10 do
				wrapped(first, 1)
			end
			expect(#log.calls).toBe(6)
			wrapped(second, 1)
			expect(log.calls[7]).toBe(2)
			time.now += 0.5 -- 2 tokens for the first player
			for _ = 1, 10 do
				wrapped(first, 1)
			end
			expect(#log.calls).toBe(9)
		end)
		t.it("counts over-limit calls as RateLimit drops", function()
			local guard, _, log = setup()
			local wrapped = guard:wrap("Attack", attackSpec(), function() end)
			local player = fakePlayer(1)
			for _ = 1, 8 do
				wrapped(player, 1)
			end
			expect(log.drops).toEqual({ "Attack:RateLimit", "Attack:RateLimit" })
		end)
	end)

	t.describe("Guard: argument count", function()
		t.it("requires the exact count for required arguments", function()
			local guard, _, log = setup()
			local spec = attackSpec()
			spec.args = { Check.integer(1, 8), Check.boolean() }
			local wrapped = guard:wrap("Pair", spec, function()
				table.insert(log.calls, true)
			end)
			local player = fakePlayer(1)
			wrapped(player, 1)
			wrapped(player, 1, true, "extra")
			wrapped(player, 1, nil)
			expect(#log.calls).toBe(0)
			expect(log.drops).toEqual({ "Pair:ArgCount", "Pair:ArgCount", "Pair:ArgType" })
			wrapped(player, 1, true)
			expect(#log.calls).toBe(1)
		end)
		t.it("lets trailing optional arguments be left out", function()
			local guard, _, log = setup()
			local spec = attackSpec()
			spec.args = { Check.string(16), Check.optional(Check.string(16)) }
			local wrapped = guard:wrap("Equip", spec, function(_who: any, _state: any, slot: string, item: string?)
				table.insert(log.calls, { slot = slot, item = item })
			end)
			local player = fakePlayer(1)
			wrapped(player, "skin")
			wrapped(player, "skin", "red")
			wrapped(player, "skin", 5)
			expect(#log.calls).toBe(2)
			expect(log.calls[1].item).toBeNil()
			expect(log.calls[2].item).toBe("red")
			expect(log.drops).toEqual({ "Equip:ArgType" })
		end)
		t.it("accepts zero arguments when args is empty, and nothing more", function()
			local guard, _, log = setup()
			local spec = attackSpec()
			spec.args = {}
			local wrapped = guard:wrap("StopFeeding", spec, function()
				table.insert(log.calls, true)
			end)
			wrapped(fakePlayer(1))
			wrapped(fakePlayer(1), "junk")
			expect(#log.calls).toBe(1)
			expect(log.drops).toEqual({ "StopFeeding:ArgCount" })
		end)
	end)

	t.describe("Guard: gate", function()
		t.it("drops the call when the gate returns nil, without a strike", function()
			local guard, _, log = setup()
			local player = fakePlayer(1)
			local spec = attackSpec(function()
				return nil
			end)
			local wrapped = guard:wrap("Attack", spec, function()
				table.insert(log.calls, true)
			end)
			wrapped(player, 1)
			expect(#log.calls).toBe(0)
			expect(log.drops).toEqual({ "Attack:Gate" })
			expect(guard:getStrikes(player)).toBe(0)
		end)
		t.it("passes a false gate result through (only nil drops)", function()
			local guard, _, log = setup()
			local spec = attackSpec(function()
				return false
			end)
			local wrapped = guard:wrap("Attack", spec, function(_who: any, state: any)
				table.insert(log.calls, state)
			end)
			wrapped(fakePlayer(1), 1)
			expect(log.calls).toEqual({ false })
		end)
		t.it("checks arguments before calling the gate", function()
			local guard = setup()
			local gateCalls = 0
			local spec = attackSpec(function()
				gateCalls += 1
				return true
			end)
			local wrapped = guard:wrap("Attack", spec, function() end)
			wrapped(fakePlayer(1), "bad")
			expect(gateCalls).toBe(0)
		end)
	end)

	t.describe("Guard: strikes", function()
		t.it("adds strikes for malformed and flooded calls", function()
			local guard = setup()
			local player = fakePlayer(1)
			local wrapped = guard:wrap("Attack", attackSpec(), function() end)
			wrapped(player, "bad")
			wrapped(player)
			expect(guard:getStrikes(player)).toBe(2)
		end)
		t.it("reports the strike limit once per window, then again in a new window", function()
			local guard, time, log = setup(3)
			local player = fakePlayer(7)
			local wrapped = guard:wrap("Attack", attackSpec(), function() end)
			for _ = 1, 10 do
				wrapped(player, "bad")
			end
			expect(#log.strikeReports).toBe(1)
			expect(log.strikeReports[1].userId).toBe(7)
			expect(log.strikeReports[1].strikes).toBe(4)
			time.now += 61
			expect(guard:getStrikes(player)).toBe(0)
			for _ = 1, 4 do
				wrapped(player, "bad")
			end
			expect(#log.strikeReports).toBe(2)
		end)
		t.it("never throws on garbage input", function()
			local guard = setup()
			local wrapped = guard:wrap("Attack", attackSpec(), function() end)
			local player = fakePlayer(1)
			expect(function()
				wrapped(player, {}, {}, {})
				wrapped(player, nil)
				wrapped(player, NAN)
				wrapped(player, math.huge)
				wrapped(player, function() end)
			end).never.toThrow()
		end)
		t.it("forget clears strikes and rate-limit buckets", function()
			local guard, _, log = setup()
			local player = fakePlayer(1)
			local wrapped = guard:wrap("Attack", attackSpec(), function()
				table.insert(log.calls, true)
			end)
			for _ = 1, 10 do
				wrapped(player, 1)
			end
			expect(guard:getStrikes(player)).toBe(4)
			guard:forget(player)
			expect(guard:getStrikes(player)).toBe(0)
			wrapped(player, 1)
			expect(#log.calls).toBe(7)
		end)
	end)

	t.describe("Guard: specs and remotes", function()
		t.it("throws at registration on a bad spec", function()
			local guard = setup()
			expect(function()
				guard:wrap("NoGate", { limit = { burst = 1, perSecond = 1 }, args = {} }, function() end)
			end).toThrow("gate")
			expect(function()
				guard:wrap("NoArgs", { limit = { burst = 1, perSecond = 1 }, gate = print }, function() end)
			end).toThrow("args")
			expect(function()
				local args = { Check.optional(Check.boolean()), Check.boolean() }
				guard:wrap("Order", { limit = { burst = 1, perSecond = 1 }, args = args, gate = print }, function() end)
			end).toThrow("required argument")
		end)
		t.it("sets OnServerInvoke for a RemoteFunction and returns the handler's results", function()
			local guard = setup()
			local remote: any = {
				Name = "RequestSpawn",
				ClassName = "RemoteFunction",
				IsA = function(_self: any, className: string): boolean
					return className == "RemoteFunction"
				end,
			}
			guard:on(remote, attackSpec(), function(_who: any, _state: any, slot: number)
				return true, "slot " .. slot
			end)
			local ok, reason = remote.OnServerInvoke(fakePlayer(1), 2)
			expect(ok).toBe(true)
			expect(reason).toBe("slot 2")
			expect(remote.OnServerInvoke(fakePlayer(1), 99)).toBeNil()
		end)
		t.it("refuses an object that is not a client-to-server remote", function()
			local guard = setup()
			local notRemote: any = {
				Name = "Part",
				ClassName = "Part",
				IsA = function()
					return false
				end,
			}
			expect(function()
				guard:on(notRemote, attackSpec(), function() end)
			end).toThrow("not a client-to-server remote")
		end)
	end)

	t.describe("Guard: errors in our own code", function()
		t.it("contains a throwing handler: Error drop, no strike, logged once, nothing returned", function()
			local guard, _, log = setup()
			local player = fakePlayer(1)
			local wrapped = guard:wrap("Attack", attackSpec(), function()
				error("handler bug")
			end)
			local results = table.pack(wrapped(player, 1))
			wrapped(player, 1)
			expect(results.n).toBe(0)
			expect(log.drops).toEqual({ "Attack:Error", "Attack:Error" })
			expect(guard:getStrikes(player)).toBe(0)
			expect(#log.errors).toBe(1)
			expect(log.errors[1].source).toBe("Attack")
			expect(string.find(log.errors[1].message, "handler bug", 1, true) ~= nil).toBe(true)
		end)
		t.it("contains a throwing gate", function()
			local guard, _, log = setup()
			local spec = attackSpec(function()
				error("gate bug")
			end)
			local wrapped = guard:wrap("Attack", spec, function()
				table.insert(log.calls, true)
			end)
			expect(function()
				wrapped(fakePlayer(1), 1)
			end).never.toThrow()
			expect(#log.calls).toBe(0)
			expect(log.drops).toEqual({ "Attack:Error" })
			expect(#log.errors).toBe(1)
		end)
		t.it("contains a throwing custom checker", function()
			local guard, _, log = setup()
			local spec = attackSpec()
			spec.args = {
				function(_value: any): boolean
					error("checker bug")
				end,
			}
			local wrapped = guard:wrap("Custom", spec, function()
				table.insert(log.calls, true)
			end)
			wrapped(fakePlayer(1), 1)
			expect(#log.calls).toBe(0)
			expect(log.drops).toEqual({ "Custom:Error" })
		end)
		t.it("treats a checker result other than true as a bad argument", function()
			local guard, _, log = setup()
			local spec = attackSpec()
			spec.args = {
				function(_value: any): any
					return 1
				end,
			}
			local wrapped = guard:wrap("Truthy", spec, function()
				table.insert(log.calls, true)
			end)
			wrapped(fakePlayer(1), 1)
			expect(#log.calls).toBe(0)
			expect(log.drops).toEqual({ "Truthy:ArgType" })
		end)
		t.it("contains throwing onDrop and onStrikeLimit hooks", function()
			local errors = {}
			local guard = Guard.new({
				strikeLimit = 1,
				hooks = {
					onDrop = function()
						error("onDrop bug")
					end,
					onStrikeLimit = function()
						error("onStrikeLimit bug")
					end,
					onError = function(source: string)
						table.insert(errors, source)
					end,
				},
			})
			local wrapped = guard:wrap("Attack", attackSpec(), function() end)
			local player = fakePlayer(1)
			expect(function()
				for _ = 1, 3 do
					wrapped(player, "bad")
				end
			end).never.toThrow()
			expect(guard:getStrikes(player)).toBe(3)
			table.sort(errors)
			expect(errors).toEqual({ "hook:onDrop", "hook:onStrikeLimit" })
		end)
		t.it("answers nil to a RemoteFunction whose handler throws", function()
			local guard, _, log = setup()
			local remote: any = {
				Name = "RequestSpawn",
				ClassName = "RemoteFunction",
				IsA = function(_self: any, className: string): boolean
					return className == "RemoteFunction"
				end,
			}
			guard:on(remote, attackSpec(), function()
				error("spawn bug")
			end)
			local results = table.pack(remote.OnServerInvoke(fakePlayer(1), 1))
			expect(results.n).toBe(0)
			expect(log.drops).toEqual({ "RequestSpawn:Error" })
		end)
	end)

	t.describe("Guard: more argument and registration rules", function()
		t.it("accepts an optional argument passed explicitly as nil", function()
			local guard, _, log = setup()
			local spec = attackSpec()
			spec.args = { Check.string(16), Check.optional(Check.string(16)) }
			local wrapped = guard:wrap("Equip", spec, function(_who: any, _state: any, slot: string, item: string?)
				table.insert(log.calls, { slot = slot, item = item })
			end)
			wrapped(fakePlayer(1), "skin", nil)
			expect(#log.calls).toBe(1)
			expect(log.calls[1].item).toBeNil()
			expect(#log.drops).toBe(0)
		end)
		t.it("rejects spec.args with a hole", function()
			local guard = setup()
			expect(function()
				local args = { Check.boolean(), nil :: any, Check.boolean() }
				guard:wrap("Holes", { limit = { burst = 1, perSecond = 1 }, args = args, gate = print }, function() end)
			end).toThrow("hole")
		end)
		t.it("refuses to guard the same remote twice", function()
			local guard = setup()
			local remote = fakeRemoteEvent("Once")
			guard:on(remote, attackSpec(), function() end)
			expect(function()
				guard:on(remote, attackSpec(), function() end)
			end).toThrow("already guarded")
		end)
	end)
end
