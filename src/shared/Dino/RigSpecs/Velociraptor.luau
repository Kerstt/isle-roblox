--!strict
--[[
	Velociraptor art spec (doc 01 "Velociraptor", doc 04 sections 1-2). Pure data: Dino/RigBuilder turns it into a
	rig, Dino/RigValidator checks the result. Used by the server (player character) and clients (previews).

	Look: a lean wedge torso of three stepped bricks (Hips, Torso, D_Chest: tops step 5.0 -> 4.5 -> 4.0), a long
	stiff tail of four tapering blocks (each step shrinks one dimension) ending in a flat fan of two feather plates,
	an oversized bone-white sickle claw standing on each foot, a wedge skull (tall at the back, sloping to the snout)
	over a long jaw, square eyes with a forward vertical bar pupil, one wedge tooth row per jaw side, two square
	feather tiles down the back of the neck and raised rust chevrons across the back.

	Coordinates: model space at adult scale (see RigMap): faces -Z, +X is the right side, feet on Y = 0.
	Every part's size is a multiple of 0.5, and on each axis either its centre or its faces sit on the 0.5 grid.

	Adult numbers: about 12.5 studs nose to fan tip (6.5 of it tail and fan), hips 4 studs up, HipHeight 3,
	33 visual parts (17 bones + 16 decorations; Small budget 35), 3 hitboxes, 16 attachments.

	Zones: Primary Sand body (doc 01), Secondary Belly Cream, Accent Rust trim (chevrons, neck tiles, tail fan),
	Detail Bone (sickle claws and teeth: doc 04 puts claws and teeth in Detail, doc 01 makes the claw bone-white),
	Eye Sun Yellow, Pupil Black.
]]

local RigMap = require(script.Parent.Parent.RigMap)

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function bone(
	name: string,
	parent: string,
	size: Vector3,
	center: Vector3,
	pivot: Vector3,
	zone: RigMap.Zone
): RigMap.BoneSpec
	return { name = name, parent = parent, size = size, center = center, pivot = pivot, zone = zone }
end

-- The same, for a bone whose block is a Wedge (tall at the back, sloping down to the front).
local function wedgeBone(
	name: string,
	parent: string,
	size: Vector3,
	center: Vector3,
	pivot: Vector3,
	zone: RigMap.Zone
): RigMap.BoneSpec
	local result = bone(name, parent, size, center, pivot, zone)
	result.shape = "Wedge"
	return result
end

local function deco(
	name: string,
	boneName: string,
	size: Vector3,
	center: Vector3,
	zone: RigMap.Zone,
	shape: RigMap.Shape?,
	rotation: Vector3?
): RigMap.DecorationSpec
	return {
		name = name,
		bone = boneName,
		size = size,
		center = center,
		zone = zone,
		shape = shape,
		rotation = rotation,
	}
end

-- Wedge orientations (Roblox's default wedge is tall at the back (+Z) and slopes down to the front).
local CLAW = v(0, 180, 0) -- tall face at the front: a claw leaning forward, tip up
local FANG = v(180, 0, 0) -- upside down: flat top, tall face at the front, tip down at the front

local spec: RigMap.RigSpec = {
	species = "Velociraptor",
	sizeClass = "Small",
	locomotion = "Biped",
	diet = "Carnivore",

	-- The only collider: covers hips and torso. Bottom at Y = 3, so Humanoid.HipHeight = 3.
	root = { size = v(2, 2, 3), center = v(0, 4, 0) },

	colors = {
		Primary = "Sand",
		Secondary = "BellyCream",
		Accent = "Rust",
		Detail = "Bone",
		Eye = "SunYellow",
		Pupil = "PupilBlack",
		Pattern = "Rust",
	},

	-- Parents first. Pivots are the anatomical joints (top centre of leg segments, base of neck, back of head).
	bones = {
		bone("Hips", "HumanoidRootPart", v(2, 2, 1.5), v(0, 4, 0.25), v(0, 4, 0), "Primary"),
		bone("Torso", "Hips", v(2, 1.5, 1), v(0, 3.75, -1), v(0, 4, -0.5), "Primary"),
		bone("Neck1", "Torso", v(1, 2, 1), v(0, 4.5, -2.5), v(0, 4, -2), "Primary"),
		wedgeBone("Head", "Neck1", v(1.5, 2, 2.5), v(0, 5.5, -3.75), v(0, 5, -2.5), "Primary"),
		bone("Jaw", "Head", v(1.5, 0.5, 2.5), v(0, 4.25, -3.75), v(0, 4.5, -3), "Secondary"),
		bone("ForeUpper_L", "Torso", v(0.5, 1, 0.5), v(-1, 3, -2), v(-1, 3.5, -2), "Primary"),
		bone("ForeUpper_R", "Torso", v(0.5, 1, 0.5), v(1, 3, -2), v(1, 3.5, -2), "Primary"),
		bone("Tail1", "Hips", v(1.5, 1.5, 1.5), v(0, 4, 1.75), v(0, 4, 1), "Primary"),
		bone("Tail2", "Tail1", v(1.5, 1, 1.5), v(0, 4, 3.25), v(0, 4, 2.5), "Primary"),
		bone("Tail3", "Tail2", v(1, 1, 1), v(0, 4, 4.5), v(0, 4, 4), "Primary"),
		bone("Tail4", "Tail3", v(1, 0.5, 1), v(0, 4, 5.5), v(0, 4, 5), "Primary"),
		bone("HindUpper_L", "Hips", v(1, 2, 1.5), v(-1, 3, 0.25), v(-1, 4, 0.25), "Primary"),
		bone("HindLower_L", "HindUpper_L", v(1, 1.5, 1), v(-1, 1.25, 1), v(-1, 2, 1), "Primary"),
		bone("HindFoot_L", "HindLower_L", v(1.5, 0.5, 2.5), v(-1, 0.25, 0.25), v(-1, 0.5, 1), "Primary"),
		bone("HindUpper_R", "Hips", v(1, 2, 1.5), v(1, 3, 0.25), v(1, 4, 0.25), "Primary"),
		bone("HindLower_R", "HindUpper_R", v(1, 1.5, 1), v(1, 1.25, 1), v(1, 2, 1), "Primary"),
		bone("HindFoot_R", "HindLower_R", v(1.5, 0.5, 2.5), v(1, 0.25, 0.25), v(1, 0.5, 1), "Primary"),
	},

	decorations = {
		-- Torso: third stepped brick, belly plate, rust chevrons that stand 0.5 proud of the back
		deco("D_Chest", "Torso", v(1.5, 1, 1), v(0, 3.5, -2), "Primary"),
		deco("D_Belly", "Torso", v(1.5, 0.5, 3), v(0, 2.75, -1), "Secondary"),
		deco("D_Chevron_1", "Hips", v(2.5, 1, 0.5), v(0, 5, 0.25), "Accent"),
		deco("D_Chevron_2", "Torso", v(2.5, 1, 0.5), v(0, 4.5, -1), "Accent"),
		-- Neck: square feather tiles down the back (they flare when sprinting: animation, later)
		deco("D_Feather_1", "Neck1", v(0.5, 0.5, 0.5), v(0, 4.5, -2), "Accent"),
		deco("D_Feather_2", "Neck1", v(0.5, 0.5, 0.5), v(0, 5.5, -2), "Accent"),
		-- Head (the Head bone itself is the wedge skull): one fang row per side, square eyes with a forward bar pupil
		deco("D_Teeth_L", "Head", v(0.5, 0.5, 1), v(-0.75, 4.25, -4), "Detail", "Wedge", FANG),
		deco("D_Teeth_R", "Head", v(0.5, 0.5, 1), v(0.75, 4.25, -4), "Detail", "Wedge", FANG),
		deco("D_Eye_L", "Head", v(0.5, 1, 0.5), v(-0.75, 5, -3), "Eye"),
		deco("D_Eye_R", "Head", v(0.5, 1, 0.5), v(0.75, 5, -3), "Eye"),
		deco("D_Pupil_L", "Head", v(0.5, 1, 0.5), v(-0.75, 5, -3.5), "Pupil"),
		deco("D_Pupil_R", "Head", v(0.5, 1, 0.5), v(0.75, 5, -3.5), "Pupil"),
		-- Feet: the oversized sickle claw on the inner toe, raised, leaning forward
		deco("D_Sickle_L", "HindFoot_L", v(0.5, 1.5, 1), v(-0.5, 1.25, -0.5), "Detail", "Wedge", CLAW),
		deco("D_Sickle_R", "HindFoot_R", v(0.5, 1.5, 1), v(0.5, 1.25, -0.5), "Detail", "Wedge", CLAW),
		-- Tail tip: flat fan of feather plates, widening outward (1 -> 1.5 -> 2.5 studs)
		deco("D_Fan_1", "Tail4", v(1.5, 0.5, 1), v(0, 4, 6.5), "Accent"),
		deco("D_Fan_2", "Tail4", v(2.5, 0.5, 0.5), v(0, 4, 7.25), "Accent"),
	},

	-- Rest-pose boxes, a little generous to cover the animated range (doc 04 section 2.6).
	hitboxes = {
		{ name = "HB_Head", bone = "Head", size = v(2, 3, 3), center = v(0, 5.25, -3.75) },
		{ name = "HB_Body", bone = "Torso", size = v(2.5, 3, 4), center = v(0, 3.75, -0.75) },
		{ name = "HB_Tail", bone = "Tail1", size = v(2, 2, 4.5), center = v(0, 4, 3) },
	},

	attachments = {
		{ name = "S_HeadTop", bone = "Head", position = v(0, 6.5, -2.5), socketScale = 0.75 },
		{ name = "S_Face", bone = "Head", position = v(0, 5, -4.25), socketScale = 0.75 },
		{ name = "S_Eye_L", bone = "Head", position = v(-1, 5, -3.25), socketScale = 0.5 },
		{ name = "S_Eye_R", bone = "Head", position = v(1, 5, -3.25), socketScale = 0.5 },
		{ name = "S_Mouth", bone = "Jaw", position = v(0, 4.25, -5), socketScale = 0.5 },
		{ name = "S_Neck", bone = "Neck1", position = v(0, 4.5, -2.5), socketScale = 0.5 },
		{ name = "S_Back", bone = "Torso", position = v(0, 5, -1), socketScale = 1 },
		{ name = "S_Saddle", bone = "Torso", position = v(0, 5, 0), socketScale = 1 },
		{ name = "S_TailTip", bone = "Tail4", position = v(0, 4, 6), socketScale = 0.5 },
		{ name = "S_Chest", bone = "Torso", position = v(0, 3.5, -2.5), socketScale = 0.75 },
		{ name = "FX_Foot_L", bone = "HindFoot_L", position = v(-1, 0, 0.25), socketScale = 0.75 },
		{ name = "FX_Foot_R", bone = "HindFoot_R", position = v(1, 0, 0.25), socketScale = 0.75 },
		{ name = "FX_Trail_A", bone = "Tail3", position = v(0, 4, 4.5), socketScale = 0.5 },
		{ name = "FX_Trail_B", bone = "Tail4", position = v(0, 4, 7.5), socketScale = 0.5 },
		{ name = "FX_Body", bone = "Torso", position = v(0, 3.75, -0.5), socketScale = 1 },
		{ name = "FX_Mouth", bone = "Jaw", position = v(0, 4, -5), socketScale = 0.5 },
	},
}

return spec
