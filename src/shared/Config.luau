--!strict
-- Shared, read-only configuration for both server and client.
-- Everything in ReplicatedStorage is readable by every client: never put secrets here.

local RunService = game:GetService("RunService")

local Config = table.freeze({
	-- Short name used as the prefix in log output.
	GameName = "isle",
	-- Extra diagnostic output (for example, how many modules each loader started). On in Studio only.
	Debug = RunService:IsStudio(),
})

export type Config = typeof(Config)

return Config
