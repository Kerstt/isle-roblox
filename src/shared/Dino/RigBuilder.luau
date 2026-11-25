--!strict
--[[
	RigBuilder: turns a species art spec (Dino/RigSpecs/<Species>) into a rig Model that follows the rig standard
	(doc 04 section 2, doc 05 section 2.2). Works on the server (player characters) and on clients (previews).

		local RigBuilder = require(ReplicatedStorage.Shared.Dino.RigBuilder)
		local Velociraptor = require(ReplicatedStorage.Shared.Dino.RigSpecs.Velociraptor)
		local model = RigBuilder.build(Velociraptor)            -- adult proportions, scale 1
		RigBuilder.scaleTo(model, 0.5)                          -- growth: ScaleTo plus the Humanoid fix-ups
		model:PivotTo(CFrame.new(spawnPosition))                -- the pivot is the ground point under the root

	What build returns (unparented, unanchored, at the world origin with its feet on Y = 0):
	- Model named after the species, attributes Species, SizeClass, Locomotion, Diet, RigVersion, ProportionStage
	  and BaseHipHeight (HipHeight at scale 1); ModelStreamingMode Atomic (never half a dino). PrimaryPart =
	  HumanoidRootPart, whose PivotOffset puts the model pivot on the ground under the root, so
	  PivotTo(groundCFrame) stands the dino on the ground at any scale.
	- HumanoidRootPart: invisible, the only collider (CanCollide and CanQuery on, CanTouch off, not massless).
	- Humanoid: RigType R15 (so HipHeight is used), HipHeight from the spec, AutomaticScalingEnabled off,
	  BreakJointsOnDeath off, RequiresNeck off, no name or health display. No Animate script and no Animator.
	- Bones flat under the Model, each with Motor6D J_<Bone> inside it (Part0 = parent bone, Part1 = bone,
	  C0/C1 share the pivot so Transform = identity is the rest pose).
	- D_ decorations inside their bone with a WeldConstraint; HB_ hitboxes flat under the Model, invisible,
	  welded to their bone, CollisionGroup "DinoHitbox"; S_/FX_ Attachments on their bones with SocketScale.
	- Every visible part: SmoothPlastic, Zone attribute, CanCollide/CanQuery/CanTouch off, Massless on.
]]

local RigMap = require(script.Parent.RigMap)
local Palette = require(script.Parent.Palette)

export type BuildOptions = {
	-- Growth stage index 1..4 (Hatchling, Juvenile, Sub-adult, Adult). Only picks the build-time head/eye
	-- proportion bonus (doc 04 section 1.4); it never scales the model. Default 4 (base proportions).
	stage: number?,
}

local RigBuilder = {}

RigBuilder.BaseHipHeightAttribute = "BaseHipHeight"

-- RigMap.Shape names match Enum.PartType item names. Looked up when a part is built, never at require time:
-- nothing at this module's top level may touch Enum, game or Instance, so specs can require it under Lune.
local function partTypeOf(shape: RigMap.Shape?): Enum.PartType
	local name = shape or "Block"
	if name == "Block" then
		return Enum.PartType.Block
	elseif name == "Wedge" then
		return Enum.PartType.Wedge
	elseif name == "CornerWedge" then
		return Enum.PartType.CornerWedge
	end
	error(string.format("RigBuilder: unknown shape %q", tostring(name)), 0)
end

-- Humanoid.HipHeight at scale 1: from the root's bottom face down to the ground (Y = 0 in the spec).
function RigBuilder.hipHeight(spec: RigMap.RigSpec): number
	return spec.root.center.Y - spec.root.size.Y / 2
end

local function rotationOf(rotation: Vector3?): CFrame
	if rotation == nil then
		return CFrame.identity
	end
	return CFrame.fromOrientation(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

local function isEyePart(name: string): boolean
	for _, prefix in RigMap.EyePrefixes do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function newPart(name: string, size: Vector3, cframe: CFrame, shape: RigMap.Shape?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = partTypeOf(shape)
	part.Size = size
	part.CFrame = cframe
	part.Anchored = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function makeVisual(part: Part, zone: RigMap.Zone): ()
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.Transparency = 0
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local size = part.Size
	part.CastShadow = not RigMap.NoShadowZones[zone] and math.max(size.X, size.Y, size.Z) >= 1
	part:SetAttribute(RigMap.ZoneAttribute, zone)
end

local function weld(bonePart: BasePart, part: BasePart): ()
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = bonePart
	constraint.Part1 = part
	constraint.Parent = part
end

-- Checks the parts of a spec the builder relies on; the rig standard itself is RigValidator's job.
local function checkSpec(spec: RigMap.RigSpec): ()
	local seen: { [string]: boolean } = { [RigMap.RootName] = true }
	local function claim(name: string, what: string): ()
		if seen[name] then
			error(string.format("RigBuilder.build: %s: duplicate name %q", spec.species, name), 4)
		end
		seen[name] = true
		if what ~= "" and string.sub(name, 1, #what) ~= what then
			error(string.format("RigBuilder.build: %s: %q must start with %q", spec.species, name, what), 4)
		end
	end
	local bones: { [string]: boolean } = {}
	for _, boneSpec in spec.bones do
		claim(boneSpec.name, "")
		if boneSpec.parent ~= RigMap.RootName and not bones[boneSpec.parent] then
			local message = "RigBuilder.build: %s: bone %q comes before its parent %q"
			error(string.format(message, spec.species, boneSpec.name, boneSpec.parent), 3)
		end
		bones[boneSpec.name] = true
	end
	for _, decoration in spec.decorations do
		claim(decoration.name, RigMap.DecorationPrefix)
	end
	for _, hitbox in spec.hitboxes do
		claim(hitbox.name, RigMap.HitboxPrefix)
	end
	local function checkBone(owner: string, boneName: string): ()
		if not bones[boneName] then
			error(string.format("RigBuilder.build: %s: %q is on unknown bone %q", spec.species, owner, boneName), 4)
		end
	end
	for _, decoration in spec.decorations do
		checkBone(decoration.name, decoration.bone)
	end
	for _, hitbox in spec.hitboxes do
		checkBone(hitbox.name, hitbox.bone)
	end
	for _, attachment in spec.attachments do
		checkBone(attachment.name, attachment.bone)
	end
end

-- Paints every zoned part from a { [Zone]: swatch name } table (the default skin, or a zone-recolor skin).
-- Pattern parts with no swatch stay hidden. Unknown swatch names are an error.
function RigBuilder.applyColors(model: Model, colors: { [string]: string }): ()
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		local zone = descendant:GetAttribute(RigMap.ZoneAttribute)
		if type(zone) ~= "string" then
			continue
		end
		local swatch = colors[zone]
		if swatch == nil then
			if zone == "Pattern" then
				descendant.Transparency = 1
				continue
			end
			error(string.format("RigBuilder.applyColors: no colour for zone %q on %s", zone, descendant.Name), 2)
		end
		local hex: string? = (Palette :: any)[swatch]
		if hex == nil then
			error(string.format("RigBuilder.applyColors: %q is not a Palette swatch", swatch), 2)
		end
		descendant.Color = Color3.fromHex(hex)
	end
end

function RigBuilder.build(spec: RigMap.RigSpec, options: BuildOptions?): Model
	checkSpec(spec)
	local stage = if options and options.stage then options.stage else 4
	if not (stage == 1 or stage == 2 or stage == 3 or stage == 4) then
		error("RigBuilder.build: stage must be 1, 2, 3 or 4", 2)
	end

	-- Head/eye proportion bonus: the head subtree is scaled about the head joint, so it stays on the neck.
	local proportion = RigMap.StageProportions[stage]
	local headScale = if proportion then proportion.head else 1
	local eyeScale = if proportion then proportion.eye else 1
	local headPivot = Vector3.zero
	for _, boneSpec in spec.bones do
		if boneSpec.name == "Head" then
			headPivot = boneSpec.pivot
		end
	end
	local function place(boneName: string, position: Vector3): Vector3
		if headScale ~= 1 and RigMap.HeadBones[boneName] then
			return headPivot + (position - headPivot) * headScale
		end
		return position
	end
	local function sized(boneName: string, size: Vector3, eye: boolean): Vector3
		if RigMap.HeadBones[boneName] then
			return size * (if eye then eyeScale else headScale)
		end
		return size
	end

	local model = Instance.new("Model")
	model.Name = spec.species
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- never half a dino (doc 05 section 7.1)
	model:SetAttribute("Species", spec.species)
	model:SetAttribute("SizeClass", spec.sizeClass)
	model:SetAttribute("Locomotion", spec.locomotion)
	model:SetAttribute("Diet", spec.diet)
	model:SetAttribute("RigVersion", RigMap.RigVersion)
	model:SetAttribute(RigMap.ProportionStageAttribute, stage)
	model:SetAttribute(RigBuilder.BaseHipHeightAttribute, RigBuilder.hipHeight(spec))

	local root = newPart(RigMap.RootName, spec.root.size, CFrame.new(spec.root.center), "Block")
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = false
	root.Massless = false
	root.CastShadow = false
	root.PivotOffset = CFrame.new(-spec.root.center) -- model pivot = ground point under the root
	root.Parent = model
	model.PrimaryPart = root

	local parts: { [string]: BasePart } = { [RigMap.RootName] = root }
	for _, boneSpec in spec.bones do
		local parentPart = parts[boneSpec.parent]
		local cframe = CFrame.new(place(boneSpec.name, boneSpec.center)) * rotationOf(boneSpec.rotation)
		local part = newPart(boneSpec.name, sized(boneSpec.name, boneSpec.size, false), cframe, boneSpec.shape)
		makeVisual(part, boneSpec.zone)
		part.Parent = model
		parts[boneSpec.name] = part

		local pivot = CFrame.new(place(boneSpec.name, boneSpec.pivot))
		local motor = Instance.new("Motor6D")
		motor.Name = RigMap.JointPrefix .. boneSpec.name
		motor.Part0 = parentPart
		motor.Part1 = part
		motor.C0 = parentPart.CFrame:ToObjectSpace(pivot)
		motor.C1 = part.CFrame:ToObjectSpace(pivot)
		motor.Parent = part
	end

	for _, decoration in spec.decorations do
		local bonePart = parts[decoration.bone]
		local eye = isEyePart(decoration.name)
		local cframe = CFrame.new(place(decoration.bone, decoration.center)) * rotationOf(decoration.rotation)
		local part = newPart(decoration.name, sized(decoration.bone, decoration.size, eye), cframe, decoration.shape)
		makeVisual(part, decoration.zone)
		weld(bonePart, part)
		part.Parent = bonePart
	end

	for _, hitbox in spec.hitboxes do
		local bonePart = parts[hitbox.bone]
		local cframe = CFrame.new(place(hitbox.bone, hitbox.center))
		local part = newPart(hitbox.name, sized(hitbox.bone, hitbox.size, false), cframe, "Block")
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = true
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.CollisionGroup = RigMap.HitboxCollisionGroup
		weld(bonePart, part)
		part.Parent = model
	end

	for _, attachmentSpec in spec.attachments do
		local bonePart = parts[attachmentSpec.bone]
		local attachment = Instance.new("Attachment")
		attachment.Name = attachmentSpec.name
		local position = place(attachmentSpec.bone, attachmentSpec.position)
		attachment.CFrame = bonePart.CFrame:ToObjectSpace(CFrame.new(position))
		local bonus = if RigMap.HeadBones[attachmentSpec.bone] then headScale else 1
		attachment:SetAttribute(RigMap.SocketScaleAttribute, attachmentSpec.socketScale * bonus)
		attachment.Parent = bonePart
	end

	RigBuilder.applyColors(model, spec.colors)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 is the rig type that honours HipHeight on a custom rig
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = RigBuilder.hipHeight(spec)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	return model
end

-- Growth: Model:ScaleTo about the ground pivot. Verified in Studio (T02): ScaleTo scales part sizes and positions,
-- Motor6D C0/C1, WeldConstraint offsets, attachments, PivotOffset and Humanoid.HipHeight, so the feet stay on the
-- ground and the joints stay connected. This then re-sets HipHeight to BaseHipHeight * scale exactly, so repeated
-- rescales never drift. Not scaled: the SocketScale attributes (accessory code multiplies by model:GetScale()),
-- and gameplay values (walk speed, camera distance, stride length) that the caller sets from species data.
function RigBuilder.scaleTo(model: Model, scale: number): ()
	if not (type(scale) == "number" and scale > 0 and scale < math.huge) then -- also rejects NaN
		error("RigBuilder.scaleTo: scale must be a finite number > 0", 2)
	end
	model:ScaleTo(scale)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local baseHipHeight = model:GetAttribute(RigBuilder.BaseHipHeightAttribute)
	if humanoid and type(baseHipHeight) == "number" then
		humanoid.HipHeight = baseHipHeight * scale
	end
end

return table.freeze(RigBuilder)
