--!strict
--[[
	Velociraptor species data (doc 01 section 2.3 "Velociraptor (MVP prototype)"). Pure data, read by the server
	(truth) and clients (UI, camera, animation). Game design owns the numbers; change them in doc 01 first.

	T02 adds the stage table (scale and walk speed are what the spike uses). T04 adds Species/init.luau (registry
	and Species.validate) next to this file, T08 fills `attacks`, T10 reads growthAt for the stage thresholds.

	Units: walk/sprint in studs/s; hunger/thirst as a fraction of the bar per minute (doc 01 lists % per minute);
	scale is the Model:ScaleTo value, (stage mass multiplier)^(1/3) for the Small class (doc 01 section 2.2).
	hipHeight = the rig's HipHeight at scale 1 (RigBuilder.hipHeight of RigSpecs.Velociraptor) x scale; a spec
	checks it against the rig, and RigBuilder.scaleTo sets the Humanoid from the rig itself.
]]

local Types = require(script.Parent.Parent.Types)

local RIG_HIP_HEIGHT = 3

local function stage(
	name: string,
	growthAt: number,
	scale: number,
	maxHealth: number,
	walkSpeed: number,
	sprintSpeed: number,
	stamina: number,
	hungerPercent: number,
	thirstPercent: number,
	mass: number,
	stomach: number
): Types.StageDef
	return table.freeze({
		name = name,
		growthAt = growthAt,
		scale = scale,
		maxHealth = maxHealth,
		walkSpeed = walkSpeed,
		sprintSpeed = sprintSpeed,
		stamina = stamina,
		hungerPerMinute = hungerPercent / 100,
		thirstPerMinute = thirstPercent / 100,
		mass = mass,
		stomach = stomach,
		hipHeight = RIG_HIP_HEIGHT * scale,
	})
end

local species: Types.SpeciesDef = {
	id = "Velociraptor",
	displayName = "Velociraptor",
	sizeClass = "Small",
	diet = "Carnivore",
	rigName = "Velociraptor", -- Shared/Dino/RigSpecs/Velociraptor (script-built rig, doc 04 section 7.1)
	adultMinutes = 35,
	stages = table.freeze({
		--    name         growthAt scale  HP   walk  sprint stam hunger thirst mass stomach
		stage("Hatchling", 0, 0.37, 60, 11.9, 27.2, 70, 9.1, 11.2, 9, 12),
		stage("Juvenile", 0.15, 0.58, 140, 13.3, 31.3, 85, 8, 9.9, 36, 36),
		stage("Sub-adult", 0.45, 0.79, 260, 14, 35, 100, 7.4, 9.5, 90, 72),
		stage("Adult", 1, 1.0, 400, 14, 34, 100, 7, 9, 180, 120),
	}),
	attacks = table.freeze({}), -- T08: Bite, Sickle Kick, Pin Leap (doc 01)
}

return table.freeze(species)
