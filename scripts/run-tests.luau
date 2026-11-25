--!strict
--[[
	Runs the specs in src/tests outside Roblox with Lune (pinned in rokit.toml). CI runs this after Selene.

		lune run scripts/run-tests            (from the repo root)
		lune run scripts/run-tests Guard      (only specs whose name contains "Guard")

	It loads modules the way Rojo maps them, so the same files work in Studio and here:
	- src/shared -> "Shared", src/modules -> "Modules", src/tests -> "Tests" (the roots of t.load paths);
	- Foo.luau is a ModuleScript named Foo, a folder with init.luau is a ModuleScript named after the folder,
	  and Foo.spec.luau is named "Foo.spec";
	- inside a module, `script`, `script.Parent.X`, :FindFirstChild / :WaitForChild and require(<that>) work.

	Every @lune/fs call is async (it yields), and Luau cannot yield inside a metamethod such as __index. So the
	three source trees are read ONCE, up front, on the main thread (snapshotTree below). After that, nodes and
	require only do table lookups: nothing reachable from a metamethod or from module code touches @lune/fs.

	Each module gets its own environment with `script`, a Rojo-aware `require`, `task` (from @lune/task) and
	Vector3/CFrame/Instance (from @lune/roblox). There is no `game`, so a module that touches it at require time
	fails here: keep tested modules pure (doc 05 section 8.1). Specs that need real Instances use t.skip under Lune.

	Exit code: 0 when every test passed, 1 when any failed (or nothing ran), 2 on a setup error.
	This file lives outside src/, so Rojo never syncs it and the src-only StyLua/Selene checks skip it.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local ROOTS: { [string]: string } = {
	Shared = "src/shared",
	Modules = "src/modules",
	Tests = "src/tests",
}
local TESTS_DIR = ROOTS.Tests

-- Filesystem snapshot (the only place that calls @lune/fs) ---------------------------------------------------

local sources: { [string]: string } = {} -- "src/shared/Signal.luau" -> file contents
local dirs: { [string]: boolean } = { src = true } -- directory paths; "src" is the parent of the roots
local dirEntries: { [string]: { string } } = {} -- directory path -> sorted entry names

local function snapshotTree(dir: string): ()
	dirs[dir] = true
	local names = fs.readDir(dir)
	table.sort(names)
	dirEntries[dir] = names
	for _, name in names do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			snapshotTree(path)
		elseif string.sub(name, -5) == ".luau" then
			sources[path] = fs.readFile(path)
		end
	end
end

for _, root in ROOTS do
	if not fs.isDir(root) then
		print("run-tests: " .. root .. " not found. Run this from the repository root.")
		process.exit(2)
	end
	snapshotTree(root)
end

-- Instance-like nodes (table lookups only) -------------------------------------------------------------------

-- A node stands in for the Instance Rojo would create at a path. Its key is the path without ".luau"
-- (src/modules/Lib/Guard for Guard.luau, src/modules/Lib for the Lib folder).
local nodeCache: { [string]: any } = {}
local NodeMeta = {}
local getNode: (key: string) -> any

local function baseName(key: string): string
	return string.match(key, "([^/]+)$") or key
end

local function parentKey(key: string): string?
	return string.match(key, "^(.+)/[^/]+$")
end

local nodeMethods = {}

function nodeMethods.FindFirstChild(self: any, name: string): any
	if rawget(self, "_isDir") then
		return getNode(rawget(self, "_key") .. "/" .. name)
	end
	return nil
end

function nodeMethods.WaitForChild(self: any, name: string, _timeout: number?): any
	local child = nodeMethods.FindFirstChild(self, name)
	if child == nil then
		error(string.format("%s has no child %q (WaitForChild would wait forever)", rawget(self, "_key"), name), 2)
	end
	return child
end

function nodeMethods.GetFullName(self: any): string
	return rawget(self, "_key")
end

function nodeMethods.IsA(self: any, className: string): boolean
	if className == "Instance" then
		return true
	elseif className == "ModuleScript" or className == "LuaSourceContainer" then
		return rawget(self, "_file") ~= nil
	elseif className == "Folder" then
		return rawget(self, "_file") == nil
	end
	return false
end

function NodeMeta.__index(self: any, key: string): any
	if key == "Parent" then
		local parent = parentKey(rawget(self, "_key"))
		return if parent then getNode(parent) else nil
	elseif key == "ClassName" then
		return if rawget(self, "_file") then "ModuleScript" else "Folder"
	end
	local method = nodeMethods[key]
	if method then
		return method
	end
	local child = nodeMethods.FindFirstChild(self, key)
	if child == nil then
		error(string.format("%s is not a valid member of %s", key, rawget(self, "_key")), 2)
	end
	return child
end

function NodeMeta.__tostring(self: any): string
	return rawget(self, "Name")
end

getNode = function(key: string): any
	local cached = nodeCache[key]
	if cached then
		return cached
	end
	local file: string? = nil
	local isDir = false
	if sources[key .. ".luau"] then
		file = key .. ".luau"
	elseif dirs[key] then
		isDir = true
		if sources[key .. "/init.luau"] then
			file = key .. "/init.luau"
		end
	else
		return nil
	end
	local node = setmetatable({ Name = baseName(key), _key = key, _file = file, _isDir = isDir }, NodeMeta)
	nodeCache[key] = node
	return node
end

-- Rojo-aware require ---------------------------------------------------------------------------------------

local moduleCache: { [string]: { value: any } } = {}
local loading: { [string]: boolean } = {}
local requireNode: (target: any) -> any

local function makeEnvironment(scriptNode: any): { [string]: any }
	return {
		script = scriptNode,
		require = requireNode,
		task = task,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Instance = roblox.Instance,
	}
end

requireNode = function(target: any): any
	if type(target) ~= "table" or getmetatable(target) ~= NodeMeta then
		error("require expects a module (script.Parent.X or similar), got " .. tostring(target), 2)
	end
	local file = rawget(target, "_file")
	if file == nil then
		error(rawget(target, "_key") .. " is a folder, not a ModuleScript", 2)
	end
	local cached = moduleCache[file]
	if cached then
		return cached.value
	end
	if loading[file] then
		error("recursive require of " .. file, 2)
	end
	loading[file] = true
	local chunk = luau.load(sources[file], {
		debugName = "@" .. file,
		environment = makeEnvironment(target),
	})
	local ok, result = pcall(chunk)
	loading[file] = nil
	if not ok then
		error(result, 0)
	end
	moduleCache[file] = { value = result }
	return result
end

local function load(path: string): any
	local first, rest = string.match(path, "^([^/]+)/(.+)$")
	local root = if first then ROOTS[first] else nil
	if root == nil or rest == nil then
		error(string.format("t.load: unknown root in %q (use Shared/, Modules/ or Tests/)", path), 2)
	end
	local node = getNode(root .. "/" .. rest)
	if node == nil then
		error(string.format("t.load: %q not found", path), 2)
	end
	return requireNode(node)
end

-- Run --------------------------------------------------------------------------------------------------------

local TestKit = requireNode(getNode(TESTS_DIR .. "/TestKit"))

local specs = {}
for _, fileName in dirEntries[TESTS_DIR] do
	local specName = string.match(fileName, "^(.+%.spec)%.luau$")
	if specName then
		table.insert(specs, {
			name = specName,
			load = function(): any
				return requireNode(getNode(TESTS_DIR .. "/" .. specName))
			end,
		})
	end
end

local summary = TestKit.run(specs, { runner = "lune", load = load, filter = process.args[1] })
print(TestKit.format(summary))
process.exit(if summary.ok then 0 else 1)
