--!strict
--[[
	Loader: shared two-phase lifecycle used by the server and client bootstraps.

	Loader.run(container, label) requires every ModuleScript that is a DIRECT child of `container`
	(sorted by name, so the order is stable). Nested folders and their contents are skipped: a module
	that needs helpers can keep them as its own children and require them itself. Modules that return
	a table with an Init and/or Start function take part in the lifecycle; any other module is
	required and otherwise left alone.

	Modules are required one at a time, so a module that yields at require time (for example a
	top-level WaitForChild) blocks every module after it. Do that waiting in Init or Start instead.

	1. Init: called on each module in turn. Set up state and connect to other modules here.
	   Keep it short and avoid yielding, because the next module waits for it.
	2. Start: called after every Init has finished, each in its own thread, so a Start that yields
	   or loops does not block the others.

	Every require, Init and Start call runs under xpcall with a stack trace. A failure is raised as
	a real error in its own thread (so it reaches the output and error reports) and the rest keep
	loading. A module whose Init fails is not started.
]]

local Config = require(script.Parent:WaitForChild("Config"))

type LoadedModule = { name: string, module: any }

local Loader = {}

local function traceback(err: any): string
	return debug.traceback(tostring(err), 2)
end

local function report(label: string, phase: string, name: string, err: any)
	local message = string.format("[%s/%s] %s failed for %s: %s", Config.GameName, label, phase, name, tostring(err))
	-- Raise in a separate thread: it is logged as an error without stopping the loader.
	task.spawn(error, message, 0)
end

local function hasLifecycle(value: any): boolean
	return type(value) == "table" and (type(value.Init) == "function" or type(value.Start) == "function")
end

local function sortedModules(container: Instance): { ModuleScript }
	local modules: { ModuleScript } = {}
	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a: ModuleScript, b: ModuleScript): boolean
		return a.Name < b.Name
	end)
	return modules
end

function Loader.run(container: Instance, label: string): ()
	local loaded: { LoadedModule } = {}
	for _, moduleScript in sortedModules(container) do
		local ok, result = xpcall(require, traceback, moduleScript)
		if not ok then
			report(label, "require", moduleScript:GetFullName(), result)
		elseif hasLifecycle(result) then
			table.insert(loaded, { name = moduleScript.Name, module = result })
		end
	end

	local initialized: { LoadedModule } = {}
	for _, entry in loaded do
		local init = entry.module.Init
		if type(init) == "function" then
			local ok, err = xpcall(init, traceback, entry.module)
			if not ok then
				report(label, "Init", entry.name, err)
				continue
			end
		end
		table.insert(initialized, entry)
	end

	for _, entry in initialized do
		local start = entry.module.Start
		if type(start) == "function" then
			task.spawn(function()
				local ok, err = xpcall(start, traceback, entry.module)
				if not ok then
					report(label, "Start", entry.name, err)
				end
			end)
		end
	end

	if Config.Debug then
		print(string.format("[%s/%s] started %d of %d module(s)", Config.GameName, label, #initialized, #loaded))
	end
end

return Loader
