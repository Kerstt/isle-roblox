--!strict
--[[
	RigMap: the dino rig standard as data (doc 04 section 2). It is the contract between the species art specs
	(Dino/RigSpecs), the builder (Dino/RigBuilder), the validator (Dino/RigValidator) and gameplay code (animation,
	combat, cosmetics). Gameplay code finds parts by these names only, never by species-specific names.

	Pure: no game, no Instances, so it loads under Lune too.

	Coordinates in a spec are model space at adult scale: +Y up, the dino faces -Z (Roblox LookVector), +X is the
	dino's right side (_R bones), and the origin is the ground point under the root, so feet rest on Y = 0.
]]

export type Zone = "Primary" | "Secondary" | "Accent" | "Detail" | "Eye" | "Pupil" | "Pattern"
export type Shape = "Block" | "Wedge" | "CornerWedge"
export type SizeClass = "Small" | "Medium" | "Large"
export type Locomotion = "Biped" | "Quadruped"
export type Requirement = "required" | "optional"

-- One bone: the main visible block of a segment, flat under the Model and driven by Motor6D J_<name>.
export type BoneSpec = {
	name: string,
	parent: string, -- parent bone, or "HumanoidRootPart"
	size: Vector3,
	center: Vector3,
	pivot: Vector3, -- joint pivot (anatomical pivot point), shared by C0 and C1
	zone: Zone,
	shape: Shape?, -- default "Block"
	rotation: Vector3?, -- degrees (X, Y, Z), multiples of 90 only, applied with CFrame.fromOrientation
}

-- A decoration part: lives inside its bone, welded to it with a WeldConstraint. Name starts with "D_".
export type DecorationSpec = {
	name: string,
	bone: string,
	size: Vector3,
	center: Vector3,
	zone: Zone,
	shape: Shape?,
	rotation: Vector3?,
}

-- An invisible hitbox part, flat under the Model and welded to its bone. Name starts with "HB_".
export type HitboxSpec = {
	name: string,
	bone: string,
	size: Vector3,
	center: Vector3,
}

-- A cosmetic socket ("S_") or effect point ("FX_") Attachment on a bone, at a model-space position.
export type AttachmentSpec = {
	name: string,
	bone: string,
	position: Vector3,
	socketScale: number, -- accessory scale for this socket at adult size (doc 04 section 4.2)
}

export type RigSpec = {
	species: string, -- Model name and the Species attribute
	sizeClass: SizeClass,
	locomotion: Locomotion,
	diet: string, -- "Carnivore" | "Herbivore" | "Omnivore" (Types.Diet)
	root: { size: Vector3, center: Vector3 }, -- HumanoidRootPart: the only collider
	colors: { [string]: string }, -- default skin: Palette swatch name per Zone
	bones: { BoneSpec },
	decorations: { DecorationSpec },
	hitboxes: { HitboxSpec },
	attachments: { AttachmentSpec },
}

export type BoneDef = {
	name: string,
	parent: string, -- "@LastNeck" means the highest NeckN present
	Biped: Requirement,
	Quadruped: Requirement,
}

export type AttachmentDef = {
	name: string,
	bone: string, -- "@LastTail" means the highest TailN present
	Biped: Requirement,
	Quadruped: Requirement,
}

export type Budget = {
	visualParts: number, -- bones + decorations (PLAN.md section 3: Small 35, Medium 45, Large 60)
	minHitboxes: number,
	maxHitboxes: number,
	minAttachments: number,
	maxAttachments: number,
	instances: number, -- every descendant plus the Model itself (doc 04 section 2.7)
}

local function bone(name: string, parent: string, biped: Requirement, quadruped: Requirement): BoneDef
	return table.freeze({ name = name, parent = parent, Biped = biped, Quadruped = quadruped })
end

local function point(name: string, boneName: string, biped: Requirement, quadruped: Requirement): AttachmentDef
	return table.freeze({ name = name, bone = boneName, Biped = biped, Quadruped = quadruped })
end

local R: Requirement = "required"
local O: Requirement = "optional"

local RigMap = {}

RigMap.RigVersion = 1
RigMap.RootName = "HumanoidRootPart"
RigMap.Grid = 0.5 -- authored sizes and offsets at adult scale (doc 04 section 1.1)

RigMap.JointPrefix = "J_"
RigMap.DecorationPrefix = "D_"
RigMap.HitboxPrefix = "HB_"
RigMap.SocketPrefix = "S_"
RigMap.FxPrefix = "FX_"

RigMap.ZoneAttribute = "Zone"
RigMap.SocketScaleAttribute = "SocketScale"
-- Which build-time head/eye proportion bonus the model was built with (doc 04 section 1.4): 1..4, 4 = none.
RigMap.ProportionStageAttribute = "ProportionStage"
RigMap.HitboxCollisionGroup = "DinoHitbox" -- registered by server code (PhysicsService) before use

RigMap.ModelAttributes = table.freeze({ "Species", "SizeClass", "Locomotion", "Diet", "RigVersion" })

RigMap.Zones = table.freeze({ "Primary", "Secondary", "Accent", "Detail", "Eye", "Pupil", "Pattern" })
-- Zones that never cast shadows (doc 04 section 1.6): small detail parts cost shadow-map time for nothing.
local noShadowZones: { [string]: boolean } = { Detail = true, Eye = true, Pupil = true, Pattern = true }
RigMap.NoShadowZones = table.freeze(noShadowZones)

-- Standard joint hierarchy (doc 04 section 2.2), in build order: every parent comes before its children.
RigMap.Bones = table.freeze({
	bone("Hips", "HumanoidRootPart", R, R),
	bone("Torso", "Hips", R, R),
	bone("Neck1", "Torso", R, R),
	bone("Neck2", "Neck1", O, O),
	bone("Neck3", "Neck2", O, O),
	bone("Neck4", "Neck3", O, O),
	bone("Head", "@LastNeck", R, R),
	bone("Jaw", "Head", R, R),
	bone("ForeUpper_L", "Torso", R, R),
	bone("ForeLower_L", "ForeUpper_L", O, R),
	bone("ForeFoot_L", "ForeLower_L", O, R),
	bone("ForeUpper_R", "Torso", R, R),
	bone("ForeLower_R", "ForeUpper_R", O, R),
	bone("ForeFoot_R", "ForeLower_R", O, R),
	bone("Tail1", "Hips", R, R),
	bone("Tail2", "Tail1", R, R),
	bone("Tail3", "Tail2", R, R),
	bone("Tail4", "Tail3", O, O),
	bone("Tail5", "Tail4", O, O),
	bone("Tail6", "Tail5", O, O),
	bone("HindUpper_L", "Hips", R, R),
	bone("HindLower_L", "HindUpper_L", R, R),
	bone("HindFoot_L", "HindLower_L", R, R),
	bone("HindUpper_R", "Hips", R, R),
	bone("HindLower_R", "HindUpper_R", R, R),
	bone("HindFoot_R", "HindLower_R", R, R),
})

-- Cosmetic sockets and effect points (doc 04 sections 4.2 and 4.3).
RigMap.Attachments = table.freeze({
	point("S_HeadTop", "Head", R, R),
	point("S_Face", "Head", R, R),
	point("S_Eye_L", "Head", R, R),
	point("S_Eye_R", "Head", R, R),
	point("S_Mouth", "Jaw", R, R),
	point("S_Neck", "Neck1", R, R),
	point("S_Back", "Torso", R, R),
	point("S_Saddle", "Torso", R, R),
	point("S_TailTip", "@LastTail", R, R),
	point("S_Chest", "Torso", R, R),
	point("FX_Foot_L", "HindFoot_L", R, R),
	point("FX_Foot_R", "HindFoot_R", R, R),
	point("FX_ForeFoot_L", "ForeFoot_L", O, R),
	point("FX_ForeFoot_R", "ForeFoot_R", O, R),
	point("FX_Trail_A", "Tail3", R, R),
	point("FX_Trail_B", "@LastTail", R, R),
	point("FX_Body", "Torso", R, R),
	point("FX_Mouth", "Jaw", R, R),
})

RigMap.RequiredHitboxes = table.freeze({ "HB_Head", "HB_Body", "HB_Tail" })

-- PLAN.md section 3 sets the visual-part caps; doc 04 section 2.7 the rest.
local budgets: { [string]: Budget } = {
	Small = table.freeze({
		visualParts = 35,
		minHitboxes = 3,
		maxHitboxes = 3,
		minAttachments = 16,
		maxAttachments = 20,
		instances = 140,
	}),
	Medium = table.freeze({
		visualParts = 45,
		minHitboxes = 3,
		maxHitboxes = 4,
		minAttachments = 18,
		maxAttachments = 22,
		instances = 180,
	}),
	Large = table.freeze({
		visualParts = 60,
		minHitboxes = 3,
		maxHitboxes = 4,
		minAttachments = 20,
		maxAttachments = 24,
		instances = 220,
	}),
}
RigMap.Budgets = table.freeze(budgets)

-- Build-time proportion bonuses (doc 04 section 1.4): head and eye size multipliers per stage index.
-- Stages 3 (Sub-adult) and 4 (Adult) use the base build.
local stageProportions: { [number]: { head: number, eye: number } } = {
	[1] = table.freeze({ head = 1.25, eye = 1.4 }),
	[2] = table.freeze({ head = 1.1, eye = 1.1 }),
}
RigMap.StageProportions = table.freeze(stageProportions)

-- Art-preview stage scales (doc 04 section 2.5). Gameplay reads the scale from species data
-- (Types.StageDef.scale, owned by T04/T10), never from here.
local previewStageScales: { [string]: { number } } = {
	Small = table.freeze({ 0.30, 0.50, 0.75, 1.00 }),
	Medium = table.freeze({ 0.20, 0.40, 0.70, 1.00 }),
	Large = table.freeze({ 0.12, 0.30, 0.65, 1.00 }),
}
RigMap.PreviewStageScales = table.freeze(previewStageScales)

local boneDefs: { [string]: BoneDef } = {}
for _, def in RigMap.Bones do
	boneDefs[def.name] = def
end

-- Returns the standard definition of a bone name, or nil when the name is not a standard bone.
function RigMap.boneDef(name: string): BoneDef?
	return boneDefs[name]
end

local function lastOf(prefix: string, maxIndex: number, present: { [string]: boolean }): string?
	for index = maxIndex, 1, -1 do
		local name = prefix .. index
		if present[name] then
			return name
		end
	end
	return nil
end

-- The parent bone a standard bone must have, given the set of bone names present in the rig.
function RigMap.expectedParent(name: string, present: { [string]: boolean }): string?
	local def = boneDefs[name]
	if def == nil then
		return nil
	elseif def.parent == "@LastNeck" then
		return lastOf("Neck", 4, present)
	end
	return def.parent
end

-- The bone an attachment must sit on, given the set of bone names present in the rig.
function RigMap.expectedAttachmentBone(def: AttachmentDef, present: { [string]: boolean }): string?
	if def.bone == "@LastTail" then
		return lastOf("Tail", 6, present)
	end
	return def.bone
end

local function quarterTurns(degrees: number): number?
	local turns = degrees / 90
	if math.abs(turns - math.round(turns)) > 1e-6 then
		return nil
	end
	return math.round(turns) % 4
end

-- World-axis extents of a box after a spec rotation (degrees, applied like CFrame.fromOrientation: Z, then X,
-- then Y). Returns nil when a rotation is not a multiple of 90 degrees.
function RigMap.rotatedExtents(size: Vector3, rotation: Vector3?): Vector3?
	if rotation == nil then
		return size
	end
	local turnsX, turnsY, turnsZ = quarterTurns(rotation.X), quarterTurns(rotation.Y), quarterTurns(rotation.Z)
	if turnsX == nil or turnsY == nil or turnsZ == nil then
		return nil
	end
	local x, y, z = size.X, size.Y, size.Z
	if turnsZ % 2 == 1 then
		x, y = y, x
	end
	if turnsX % 2 == 1 then
		y, z = z, y
	end
	if turnsY % 2 == 1 then
		x, z = z, x
	end
	return Vector3.new(x, y, z)
end

local function isMultiple(value: number, step: number): boolean
	local steps = value / step
	return math.abs(steps - math.round(steps)) < 1e-3
end

local function axisIssue(name: string, middle: number, extent: number): string?
	local grid = RigMap.Grid
	if not isMultiple(extent, grid) then
		return string.format("size %s = %g is not a multiple of %g", name, extent, grid)
	end
	if not isMultiple(middle, grid) and not isMultiple(middle - extent / 2, grid) then
		return string.format("%s centre %g puts neither the centre nor the faces on the %g grid", name, middle, grid)
	end
	return nil
end

-- The 0.5-stud grid rule for one box at adult scale: every extent is a multiple of the grid, and on each axis
-- either the centre or both faces sit on the grid (so a 1.5-wide part can be centred on the midline).
-- Returns nil when the box is on the grid, else a short description of the first problem.
function RigMap.gridIssue(center: Vector3, extents: Vector3): string?
	return axisIssue("X", center.X, extents.X)
		or axisIssue("Y", center.Y, extents.Y)
		or axisIssue("Z", center.Z, extents.Z)
end

-- Head subtree: the bones whose parts get the hatchling/juvenile head bonus.
local headBones: { [string]: boolean } = { Head = true, Jaw = true }
RigMap.HeadBones = table.freeze(headBones)
-- Decorations scaled by the eye bonus: names starting with these prefixes.
RigMap.EyePrefixes = table.freeze({ "D_Eye", "D_Pupil" })

return table.freeze(RigMap)
