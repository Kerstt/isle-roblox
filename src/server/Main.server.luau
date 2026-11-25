--!strict
-- Server bootstrap. Keep this file thin: server logic lives in ModuleScripts under ServerStorage.Modules.
-- A module there takes part in startup by exposing Init and/or Start (see ReplicatedStorage.Shared.Loader).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.run(ServerStorage.Modules, "Server")
