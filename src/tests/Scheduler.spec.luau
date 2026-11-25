--!strict
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	local Scheduler = t.load("Modules/Lib/Scheduler")
	local expect = t.expect

	-- A scheduler on a fake clock with a fake player list; specs call step() by hand.
	local function setup()
		local world = { now = 0, players = {} :: { any }, errors = {} :: { string } }
		local scheduler = Scheduler.new({
			clock = function(): number
				return world.now
			end,
			getPlayers = function(): { any }
				return world.players
			end,
			onError = function(jobName: string, _message: string)
				table.insert(world.errors, jobName)
			end,
		})
		local function advance(seconds: number, stepSize: number)
			local target = world.now + seconds
			while world.now < target - 1e-9 do
				world.now += stepSize
				scheduler:step()
			end
		end
		return scheduler, world, advance
	end

	t.describe("Scheduler:every", function()
		t.it("runs once per interval and passes the real elapsed time", function()
			local scheduler, _, advance = setup()
			local dts = {}
			scheduler:every(1, "Tick", function(dt: number)
				table.insert(dts, dt)
			end)
			advance(3.5, 0.0625) -- binary-exact steps, so the run times are exact
			expect(dts).toEqual({ 1, 1, 1 })
		end)
		t.it("skips missed runs after a long stall instead of bunching them", function()
			local scheduler, world = setup()
			local runs = 0
			scheduler:every(1, "Tick", function()
				runs += 1
			end)
			world.now = 10
			scheduler:step()
			scheduler:step()
			expect(runs).toBe(1)
			world.now = 10.5
			scheduler:step()
			expect(runs).toBe(1)
			world.now = 11
			scheduler:step()
			expect(runs).toBe(2)
		end)
		t.it("stops after Cancel", function()
			local scheduler, _, advance = setup()
			local runs = 0
			local handle = scheduler:every(0.5, "Tick", function()
				runs += 1
			end)
			advance(1, 0.125)
			handle:Cancel()
			advance(2, 0.125)
			expect(runs).toBe(2)
		end)
		t.it("reports a failing job and keeps running it and the others", function()
			local scheduler, world, advance = setup()
			local goodRuns = 0
			scheduler:every(1, "Broken", function()
				error("boom")
			end)
			scheduler:every(1, "Good", function()
				goodRuns += 1
			end)
			advance(2, 0.25)
			expect(goodRuns).toBe(2)
			expect(world.errors).toEqual({ "Broken", "Broken" })
		end)
		t.it("rejects a bad interval", function()
			local scheduler = setup()
			expect(function()
				scheduler:every(0, "Zero", function() end)
			end).toThrow("interval")
			expect(function()
				scheduler:every(0 / 0, "NaN", function() end)
			end).toThrow("interval")
		end)
	end)

	t.describe("Scheduler:everyPlayer", function()
		t.it("runs once per interval for each player", function()
			local scheduler, world, advance = setup()
			local a, b = { Name = "A" }, { Name = "B" }
			world.players = { a, b }
			local counts = { [a] = 0, [b] = 0 }
			local dts = {}
			scheduler:everyPlayer(1, "Needs", function(player: any, dt: number)
				counts[player] += 1
				table.insert(dts, dt)
			end)
			advance(5, 0.0625)
			expect(counts[a]).toBe(5)
			expect(counts[b]).toBe(5)
			for _, dt in dts do
				expect(dt).toBeNear(1, 0.07)
			end
			expect(#world.errors).toBe(0)
		end)
		t.it("spreads players across the interval instead of one frame", function()
			local scheduler, world, advance = setup()
			for index = 1, 10 do
				table.insert(world.players, { Name = "P" .. index })
			end
			local firstRunAt = {}
			scheduler:everyPlayer(1, "Needs", function(player: any)
				if firstRunAt[player] == nil then
					firstRunAt[player] = world.now
				end
			end)
			advance(1.125, 0.0625)
			local distinct = {}
			local count = 0
			for _, at in firstRunAt do
				count += 1
				distinct[math.floor(at * 16 + 0.5)] = true
			end
			local frames = 0
			for _ in distinct do
				frames += 1
			end
			expect(count).toBe(10)
			expect(frames >= 5).toBe(true)
		end)
		t.it("drops players who left and picks up players who joined", function()
			local scheduler, world, advance = setup()
			local a, b = { Name = "A" }, { Name = "B" }
			world.players = { a }
			local seen = {}
			scheduler:everyPlayer(0.5, "Needs", function(player: any)
				seen[player] = (seen[player] or 0) + 1
			end)
			advance(1, 0.0625)
			local aRuns = seen[a]
			world.players = { b }
			advance(1, 0.0625)
			expect(seen[a]).toBe(aRuns)
			expect((seen[b] or 0) >= 1).toBe(true)
		end)
	end)

	t.describe("Scheduler edge cases", function()
		t.it("reports a failing everyPlayer job per player and keeps serving the others", function()
			local scheduler, world, advance = setup()
			local good, bad = { Name = "Good" }, { Name = "Bad" }
			world.players = { bad, good }
			local goodRuns = 0
			scheduler:everyPlayer(1, "Needs", function(player: any)
				if player == bad then
					error("bad player data")
				end
				goodRuns += 1
			end)
			advance(3, 0.0625)
			expect(goodRuns).toBe(3)
			expect(#world.errors).toBe(3)
			expect(world.errors[1]).toBe("Needs")
		end)
		t.it("stops an everyPlayer job that cancels itself mid-step", function()
			local scheduler, world, advance = setup()
			world.players = { { Name = "A" }, { Name = "B" }, { Name = "C" } }
			local runs = 0
			local handle
			handle = scheduler:everyPlayer(0.0625, "Once", function()
				runs += 1
				handle:Cancel()
			end)
			advance(1, 0.0625)
			expect(runs).toBe(1)
		end)
		t.it("stops a global job that cancels itself", function()
			local scheduler, _, advance = setup()
			local runs = 0
			local handle
			handle = scheduler:every(0.25, "Once", function()
				runs += 1
				handle:Cancel()
			end)
			advance(2, 0.0625)
			expect(runs).toBe(1)
		end)
		t.it("schedules a job added during a step from that moment, not in the same step", function()
			local scheduler, world, advance = setup()
			local addedAt: number? = nil
			local childRuns = {}
			scheduler:every(1, "Parent", function()
				if addedAt == nil then
					addedAt = world.now
					scheduler:every(0.25, "Child", function()
						table.insert(childRuns, world.now)
					end)
				end
			end)
			advance(1, 0.0625)
			expect(addedAt).toBe(1)
			expect(#childRuns).toBe(0)
			advance(0.5, 0.0625)
			expect(childRuns).toEqual({ 1.25, 1.5 })
		end)
	end)
end
