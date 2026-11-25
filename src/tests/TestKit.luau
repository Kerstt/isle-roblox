--!strict
--[[
	TestKit: a tiny dependency-free test framework. The same specs run in Studio (Tests/RunAll) and under Lune in CI
	(scripts/run-tests.luau).

	A spec is a ModuleScript named <Name>.spec that returns a function taking the test context `t`:

		local TestKit = require(script.Parent.TestKit)

		return function(t: TestKit.Context)
			local Check = t.load("Modules/Lib/Check")
			t.describe("Check.integer", function()
				t.it("rejects NaN", function()
					t.expect(Check.integer(1, 8)(0 / 0)).toBe(false)
				end)
			end)
		end

	t.load(path) loads a module by logical path: "Shared/..." (ReplicatedStorage.Shared, src/shared),
	"Modules/..." (ServerStorage.Modules, src/modules) or "Tests/..." (ServerStorage.Tests, src/tests).
	t.runner is "studio" or "lune"; t.skip(name, reason) records a skipped test (for Roblox-only checks).

	Matchers: toBe, toEqual (deep), toBeNear, toBeNil, toBeTruthy, toBeFalsy, toThrow, and .never to negate.

	Pure: no require, no `game`.
]]

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeNear: (expected: number, epsilon: number?) -> (),
	toBeNil: () -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toThrow: (fragment: string?) -> (),
	never: Expectation,
}

export type Context = {
	describe: (name: string, body: () -> ()) -> (),
	it: (name: string, body: () -> ()) -> (),
	skip: (name: string, reason: string?) -> (),
	expect: (actual: any) -> Expectation,
	load: (path: string) -> any,
	runner: string,
}

export type SpecEntry = {
	name: string,
	load: () -> any, -- returns the spec function (requires the spec module)
}

export type Result = {
	spec: string,
	test: string,
	status: "passed" | "failed" | "skipped",
	message: string?,
}

export type Summary = {
	runner: string,
	specs: number,
	passed: number,
	failed: number,
	skipped: number,
	results: { Result },
	ok: boolean,
}

export type RunOptions = {
	runner: string,
	load: (path: string) -> any,
	filter: string?, -- only specs whose name contains this text (plain match)
}

local TestKit = {}

local function describeValue(value: any): string
	local kind = typeof(value)
	if kind == "string" then
		return string.format("%q", value)
	elseif kind == "table" then
		local parts = {}
		local count = 0
		for key, item in value do
			count += 1
			if count > 6 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, string.format("%s = %s", tostring(key), tostring(item)))
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any, seen: { [any]: any }): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	if seen[a] == b then
		return true -- already being compared further up (cycle)
	end
	seen[a] = b
	for key, value in a do
		if not deepEqual(value, b[key], seen) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

TestKit.deepEqual = function(a: any, b: any): boolean
	return deepEqual(a, b, {})
end

local function makeExpectation(actual: any, negate: boolean): Expectation
	-- Level 3 points the error at the spec line that called the matcher.
	local function check(pass: boolean, message: string): ()
		if pass == negate then
			error(if negate then "expected NOT: " .. message else "expected: " .. message, 3)
		end
	end

	local expectation = {}

	function expectation.toBe(expected: any): ()
		check(actual == expected, string.format("%s to be %s", describeValue(actual), describeValue(expected)))
	end

	function expectation.toEqual(expected: any): ()
		local message = string.format("%s to deep-equal %s", describeValue(actual), describeValue(expected))
		check(deepEqual(actual, expected, {}), message)
	end

	function expectation.toBeNear(expected: number, epsilon: number?): ()
		local tolerance = epsilon or 1e-6
		local pass = type(actual) == "number" and math.abs(actual - expected) <= tolerance
		local message = "%s to be within %s of %s"
		check(pass, string.format(message, describeValue(actual), tostring(tolerance), tostring(expected)))
	end

	function expectation.toBeNil(): ()
		check(actual == nil, describeValue(actual) .. " to be nil")
	end

	function expectation.toBeTruthy(): ()
		check(not not actual, describeValue(actual) .. " to be truthy")
	end

	function expectation.toBeFalsy(): ()
		check(not actual, describeValue(actual) .. " to be falsy")
	end

	function expectation.toThrow(fragment: string?): ()
		assert(type(actual) == "function", "toThrow expects a function")
		local ok, err = pcall(actual)
		local pass = not ok
		if pass and fragment then
			pass = string.find(tostring(err), fragment, 1, true) ~= nil
		end
		local what = if fragment then string.format("an error containing %q", fragment) else "an error"
		check(pass, string.format("function to throw %s (got %s)", what, if ok then "no error" else tostring(err)))
	end

	if not negate then
		expectation.never = makeExpectation(actual, true)
	end
	return expectation :: any
end

function TestKit.expect(actual: any): Expectation
	return makeExpectation(actual, false)
end

local function runSpec(entry: SpecEntry, options: RunOptions, results: { Result }): ()
	local stack: { string } = {}
	local inTest = false

	local function record(test: string, status: "passed" | "failed" | "skipped", message: string?): ()
		table.insert(results, { spec = entry.name, test = test, status = status, message = message })
	end

	local function fullName(name: string): string
		if #stack == 0 then
			return name
		end
		return table.concat(stack, " > ") .. " > " .. name
	end

	local context: Context = {
		runner = options.runner,
		load = options.load,
		expect = TestKit.expect,
		describe = function(name: string, body: () -> ())
			table.insert(stack, name)
			local ok, err = pcall(body)
			if not ok then
				record(fullName("(describe body)"), "failed", tostring(err))
			end
			table.remove(stack)
		end,
		it = function(name: string, body: () -> ())
			assert(not inTest, "t.it cannot be nested inside another t.it")
			inTest = true
			local ok, err = pcall(body)
			inTest = false
			record(fullName(name), if ok then "passed" else "failed", if ok then nil else tostring(err))
		end,
		skip = function(name: string, reason: string?)
			record(fullName(name), "skipped", reason)
		end,
	}

	local loaded, specFunction = pcall(entry.load)
	if not loaded then
		record("(load spec)", "failed", tostring(specFunction))
		return
	end
	if type(specFunction) ~= "function" then
		record("(load spec)", "failed", "a spec module must return a function, got " .. typeof(specFunction))
		return
	end
	local ok, err = pcall(specFunction, context)
	if not ok then
		record("(spec body)", "failed", tostring(err))
	end
end

function TestKit.run(specs: { SpecEntry }, options: RunOptions): Summary
	local results: { Result } = {}
	local specCount = 0
	for _, entry in specs do
		if options.filter and not string.find(entry.name, options.filter, 1, true) then
			continue
		end
		specCount += 1
		runSpec(entry, options, results)
	end

	local summary: Summary = {
		runner = options.runner,
		specs = specCount,
		passed = 0,
		failed = 0,
		skipped = 0,
		results = results,
		ok = false,
	}
	for _, result in results do
		if result.status == "passed" then
			summary.passed += 1
		elseif result.status == "failed" then
			summary.failed += 1
		else
			summary.skipped += 1
		end
	end
	summary.ok = summary.failed == 0 and summary.passed > 0
	return summary
end

function TestKit.format(summary: Summary): string
	local lines = {}
	for _, result in summary.results do
		if result.status == "failed" then
			table.insert(lines, string.format("FAIL %s > %s", result.spec, result.test))
			table.insert(lines, "     " .. tostring(result.message))
		elseif result.status == "skipped" then
			local reason = if result.message then " (" .. result.message .. ")" else ""
			table.insert(lines, string.format("SKIP %s > %s%s", result.spec, result.test, reason))
		end
	end
	local verdict = if summary.ok then "PASS" else "FAIL"
	local totals = string.format(
		"%s [%s]: %d passed, %d failed, %d skipped in %d spec(s)",
		verdict,
		summary.runner,
		summary.passed,
		summary.failed,
		summary.skipped,
		summary.specs
	)
	table.insert(lines, totals)
	return table.concat(lines, "\n")
end

return table.freeze(TestKit)
