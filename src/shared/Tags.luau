--!strict
--[[
	Tags: CollectionService tag names, so server and client code never drift apart.
	Every value equals its key (a spec checks this). Add a tag here before using it anywhere.
]]

local Tags = table.freeze({
	-- World markers (doc 03: gameplay markers are tagged server-side parts)
	Nursery = "Nursery",
	SpawnPoint = "SpawnPoint",
	WaterSource = "WaterSource",
	PlantSource = "PlantSource",
	PreyZone = "PreyZone",
	-- Runtime models
	Carcass = "Carcass",
})

return Tags
