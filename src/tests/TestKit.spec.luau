--!strict
-- Checks the test framework itself, so a broken matcher cannot make every other spec pass by accident.
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	local expect = t.expect

	local function fails(body: () -> ()): boolean
		local ok = pcall(body)
		return not ok
	end

	t.describe("matchers", function()
		t.it("toBe compares with ==", function()
			expect(fails(function()
				expect(1).toBe(1)
			end)).toBe(false)
			expect(fails(function()
				expect({}).toBe({})
			end)).toBe(true)
		end)
		t.it("toEqual compares tables deeply, both ways", function()
			expect(TestKit.deepEqual({ a = { 1, 2 } }, { a = { 1, 2 } })).toBe(true)
			expect(TestKit.deepEqual({ a = 1 }, { a = 1, b = 2 })).toBe(false)
			expect(TestKit.deepEqual({ a = 1, b = 2 }, { a = 1 })).toBe(false)
			expect(fails(function()
				expect({ 1, 2 }).toEqual({ 1, 3 })
			end)).toBe(true)
		end)
		t.it("toBeNear uses the tolerance", function()
			expect(fails(function()
				expect(0.1 + 0.2).toBeNear(0.3)
			end)).toBe(false)
			expect(fails(function()
				expect(1).toBeNear(1.1, 0.05)
			end)).toBe(true)
			expect(fails(function()
				expect(0 / 0).toBeNear(0)
			end)).toBe(true)
		end)
		t.it("toThrow needs an error, and the fragment when given", function()
			expect(fails(function()
				expect(function()
					error("bad thing")
				end).toThrow("bad")
			end)).toBe(false)
			expect(fails(function()
				expect(function()
					error("bad thing")
				end).toThrow("other")
			end)).toBe(true)
			expect(fails(function()
				expect(function() end).toThrow()
			end)).toBe(true)
		end)
		t.it("never inverts a matcher", function()
			expect(fails(function()
				expect(1).never.toBe(2)
			end)).toBe(false)
			expect(fails(function()
				expect(nil).never.toBeNil()
			end)).toBe(true)
		end)
		t.it("toBeTruthy and toBeFalsy follow Luau truthiness", function()
			expect(fails(function()
				expect(0).toBeTruthy()
			end)).toBe(false)
			expect(fails(function()
				expect(false).toBeFalsy()
			end)).toBe(false)
			expect(fails(function()
				expect(nil).toBeTruthy()
			end)).toBe(true)
		end)
	end)

	t.describe("TestKit.run", function()
		t.it("counts passes, failures, skips and broken specs", function()
			local specs = {
				{
					name = "Sample.spec",
					load = function()
						return function(inner: TestKit.Context)
							inner.it("passes", function() end)
							inner.it("fails", function()
								error("nope")
							end)
							inner.skip("skipped", "reason")
						end
					end,
				},
				{
					name = "NotAFunction.spec",
					load = function()
						return 42
					end,
				},
			}
			local summary = TestKit.run(specs, { runner = "self-test", load = function() end })
			expect(summary.specs).toBe(2)
			expect(summary.passed).toBe(1)
			expect(summary.failed).toBe(2)
			expect(summary.skipped).toBe(1)
			expect(summary.ok).toBe(false)
			expect(string.find(TestKit.format(summary), "FAIL Sample.spec > fails", 1, true) ~= nil).toBe(true)
		end)
		t.it("applies the spec name filter", function()
			local specs = {
				{
					name = "Keep.spec",
					load = function()
						return function(inner: TestKit.Context)
							inner.it("passes", function() end)
						end
					end,
				},
				{
					name = "Other.spec",
					load = function()
						error("must not load")
					end,
				},
			}
			local summary = TestKit.run(specs, { runner = "self-test", load = function() end, filter = "Keep" })
			expect(summary.specs).toBe(1)
			expect(summary.ok).toBe(true)
		end)
	end)
end
