--!strict
-- Client bootstrap. Keep this file thin: client logic lives in ModuleScripts in the Controllers folder next to it.
-- A controller takes part in startup by exposing Init and/or Start (see ReplicatedStorage.Shared.Loader).
-- Clients only send requests to the server and present what the server confirms.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loader"))

Loader.run(script.Parent:WaitForChild("Controllers"), "Client")
