--!strict
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	local Targets = t.load("Modules/Lib/Targets")
	local expect = t.expect

	local function makeTarget(kind: string?): any
		local target = { kind = kind or "Dummy", damageTaken = 0 }
		function target.getRoot()
			return nil
		end
		function target.applyDamage(amount: number)
			target.damageTaken += amount
		end
		return target
	end

	t.describe("Targets.register / get / unregister", function()
		t.it("finds a registered target by its model", function()
			local model = { Name = "Raptor" }
			local target = makeTarget("Dino")
			local before = Targets.count()
			Targets.register(model, target)
			expect(Targets.get(model)).toBe(target)
			expect(Targets.count()).toBe(before + 1)
			Targets.get(model).applyDamage(12)
			expect(target.damageTaken).toBe(12)
			Targets.unregister(model)
			expect(Targets.get(model)).toBeNil()
			expect(Targets.count()).toBe(before)
		end)
		t.it("replaces the old entry when a model registers again", function()
			local model = {}
			local first, second = makeTarget(), makeTarget()
			local before = Targets.count()
			Targets.register(model, first)
			Targets.register(model, second)
			expect(Targets.get(model)).toBe(second)
			expect(Targets.count()).toBe(before + 1)
			Targets.unregister(model)
		end)
		t.it("returns an unregister function that only removes its own entry", function()
			local model = {}
			local unregisterFirst = Targets.register(model, makeTarget())
			local second = makeTarget()
			local unregisterSecond = Targets.register(model, second)
			unregisterFirst()
			expect(Targets.get(model)).toBe(second)
			unregisterSecond()
			expect(Targets.get(model)).toBeNil()
		end)
		t.it("rejects a target without applyDamage or getRoot", function()
			expect(function()
				Targets.register({}, { kind = "NPC", getRoot = function() end })
			end).toThrow("applyDamage")
			expect(function()
				Targets.register({}, { kind = "NPC", applyDamage = function() end })
			end).toThrow("getRoot")
		end)
	end)

	t.describe("Targets.findFromPart", function()
		t.it("walks up from a part to the nearest registered ancestor", function()
			local model = { Name = "Raptor" }
			local body = { Name = "Body", Parent = model }
			local jaw = { Name = "Jaw", Parent = body }
			local target = makeTarget()
			Targets.register(model, target)
			local found, foundModel = Targets.findFromPart(jaw)
			expect(found).toBe(target)
			expect(foundModel).toBe(model)
			expect(Targets.findFromPart({ Name = "Rock" })).toBeNil()
			Targets.unregister(model)
		end)
	end)

	t.describe("Targets.list", function()
		t.it("returns a snapshot that survives unregistering while iterating", function()
			local models = { {}, {}, {} }
			for _, model in models do
				Targets.register(model, makeTarget())
			end
			local visited = 0
			for _, entry in Targets.list() do
				if table.find(models, entry.model) then
					visited += 1
					Targets.unregister(entry.model)
				end
			end
			expect(visited).toBe(3)
			for _, model in models do
				expect(Targets.get(model)).toBeNil()
			end
		end)
	end)

	t.describe("Targets with Instances", function()
		if t.runner ~= "studio" then
			t.skip("auto-unregister on Destroy", "needs real Instances (Studio only)")
			return
		end
		t.it("unregisters a model when it is destroyed", function()
			local model = Instance.new("Model")
			Targets.register(model, makeTarget())
			model:Destroy()
			task.wait() -- Destroying may be a deferred event
			expect(Targets.get(model)).toBeNil()
		end)
	end)
end
