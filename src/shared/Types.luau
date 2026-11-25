--!strict
--[[
	Types: exported types shared by server and client. Require it for its types only:

		local Types = require(ReplicatedStorage.Shared.Types)
		local function getLife(player: Player): Types.LifeState? ... end

	T01 holds the MVP minimum, taken from docs 01 and 05. The tickets that build each system own the final fields:
	SpeciesDef/StageDef (T04, T10), AttackDef (T08), LifeState (T04, T06, T13). The game-design numbers themselves
	live in the Species data modules, never here.
]]

export type SizeClass = "Small" | "Medium" | "Large"
export type Diet = "Carnivore" | "Herbivore" | "Omnivore"

-- Stage index: 1 Hatchling, 2 Juvenile, 3 Sub-adult, 4 Adult.
export type StageIndex = number

export type StageDef = {
	name: string,
	growthAt: number, -- growth fraction (0..1) where this stage starts: 0, 0.15, 0.45, 1 (doc 01 section 2)
	scale: number, -- Model:ScaleTo value
	maxHealth: number,
	walkSpeed: number, -- studs/s
	sprintSpeed: number, -- studs/s
	stamina: number, -- stamina pool
	hungerPerMinute: number, -- fraction of the bar per minute
	thirstPerMinute: number, -- fraction of the bar per minute
	mass: number,
	stomach: number, -- Food Points
	hipHeight: number,
}

export type AttackDef = {
	id: string,
	damage: number, -- base damage at Adult, before stage scaling
	cooldown: number, -- seconds
	windup: number, -- seconds between the request and hit resolution
	staminaCost: number,
	range: number, -- studs, used for the broad phase
	offset: CFrame, -- attack box centre relative to the root, at scale 1
	size: Vector3, -- attack box size at scale 1
	bleed: boolean?,
	minStage: StageIndex?,
}

export type SpeciesDef = {
	id: string,
	displayName: string,
	sizeClass: SizeClass,
	diet: Diet,
	rigName: string, -- template Model in ReplicatedStorage.Assets.Rigs
	adultMinutes: number, -- minutes of fed play from hatchling to adult
	stages: { StageDef }, -- exactly 4
	attacks: { AttackDef },
}

-- The server's truth for one living dino (DinoService). Health is a number here, never Humanoid.Health.
export type LifeState = {
	speciesId: string,
	slotIndex: number,
	stage: StageIndex,
	growth: number, -- 0..1 across all stages
	health: number,
	maxHealth: number,
	hunger: number, -- 0..1
	thirst: number, -- 0..1
	stamina: number,
	bleeding: boolean,
	sprinting: boolean,
	resting: boolean,
	bornAt: number, -- os.time()
	lifeSeconds: number, -- alive time only
	lastCombatAt: number, -- os.clock() of the last damage dealt or taken; 0 when never
	shieldedUntil: number, -- os.clock() when the spawn shield ends
}

return table.freeze({})
