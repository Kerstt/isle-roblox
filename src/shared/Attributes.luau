--!strict
--[[
	Attributes: attribute names for live state the server mirrors to clients (doc 05 section 4.2).
	Live state is attributes, not remotes. Every value equals its key (a spec checks this).
]]

local Attributes = table.freeze({
	-- On the character model (everyone reads: nameplates, health bars)
	Species = "Species",
	Stage = "Stage",
	Health = "Health",
	MaxHealth = "MaxHealth",
	Bleeding = "Bleeding",
	Shielded = "Shielded",
	HerdId = "HerdId",
	-- On the Player (the owner's HUD; visible to everyone, harmless)
	Hunger = "Hunger",
	Thirst = "Thirst",
	Stamina = "Stamina",
	Growth = "Growth",
	CombatTagged = "CombatTagged",
})

return Attributes
