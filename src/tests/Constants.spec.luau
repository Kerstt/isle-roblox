--!strict
-- Tags, Attributes and CollisionGroups are pure name tables: every value must equal its key, be unique, and the
-- table frozen.
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	local expect = t.expect

	for _, moduleName in { "Tags", "Attributes", "CollisionGroups" } do
		t.describe(moduleName, function()
			local constants = t.load("Shared/" .. moduleName)
			t.it("maps every key to the same string", function()
				local count = 0
				for key, value in constants do
					count += 1
					expect(value).toBe(key)
				end
				expect(count > 0).toBe(true)
			end)
			t.it("is frozen", function()
				expect(table.isfrozen(constants)).toBe(true)
			end)
		end)
	end
end
