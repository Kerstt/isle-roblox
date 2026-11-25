--!strict
--[[
	RunAll: runs every *.spec module in ServerStorage.Tests inside Roblox Studio and returns the summary.

	From the command bar, or the Roblox_Studio MCP execute_luau (Edit or Server data model):

		local summary = require(game.ServerStorage.Tests.RunAll:Clone())()
		print(summary.passed, summary.failed, summary.skipped)

	require caches modules for the whole Studio session, so by default RunAll works on fresh clones of
	ServerStorage.Tests, ReplicatedStorage.Shared and ServerStorage.Modules: code Rojo synced since the last run is
	what gets tested. Cloning RunAll itself (as above) does the same for this file. Pass { fresh = false } to test
	the live modules instead, or { filter = "Guard" } to run only specs whose name contains that text.

	The clones are never parented, so a run leaves the place unchanged.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TestKitTypes = require(ServerStorage:WaitForChild("Tests"):WaitForChild("TestKit"))

export type Options = {
	fresh: boolean?,
	filter: string?,
	quiet: boolean?, -- true: return the summary without printing the report
}

local function maybeClone(instance: Instance, fresh: boolean): Instance
	return if fresh then instance:Clone() else instance
end

local function runAll(options: Options?): TestKitTypes.Summary
	local opts: Options = options or {}
	local fresh = opts.fresh ~= false

	local tests = maybeClone(ServerStorage:WaitForChild("Tests"), fresh)
	local roots: { [string]: Instance } = {
		Shared = maybeClone(ReplicatedStorage:WaitForChild("Shared"), fresh),
		Modules = maybeClone(ServerStorage:WaitForChild("Modules"), fresh),
		Tests = tests,
	}

	local function loadModule(path: string): any
		local segments = string.split(path, "/")
		local node: Instance? = roots[segments[1]]
		if node == nil then
			error(string.format("t.load: unknown root in %q (use Shared/, Modules/ or Tests/)", path), 2)
		end
		for index = 2, #segments do
			node = (node :: Instance):FindFirstChild(segments[index])
			if node == nil then
				error(string.format("t.load: %q not found", path), 2)
			end
		end
		local found = node :: Instance
		if not found:IsA("ModuleScript") then
			error(string.format("t.load: %q is a %s, not a ModuleScript", path, found.ClassName), 2)
		end
		return require(found)
	end

	local specModules: { ModuleScript } = {}
	for _, child in tests:GetChildren() do
		if child:IsA("ModuleScript") and string.sub(child.Name, -5) == ".spec" then
			table.insert(specModules, child)
		end
	end
	table.sort(specModules, function(a: ModuleScript, b: ModuleScript): boolean
		return a.Name < b.Name
	end)

	local specs: { TestKitTypes.SpecEntry } = {}
	for _, moduleScript in specModules do
		table.insert(specs, {
			name = moduleScript.Name,
			load = function(): any
				return require(moduleScript)
			end,
		})
	end

	local TestKit = require(tests:WaitForChild("TestKit")) :: typeof(TestKitTypes)
	local summary = TestKit.run(specs, { runner = "studio", load = loadModule, filter = opts.filter })
	if not opts.quiet then
		local report = TestKit.format(summary)
		if summary.ok then
			print(report)
		else
			warn(report)
		end
	end
	return summary
end

return runAll
