--!strict
--[[
	RigValidator: checks a built dino rig against the rig standard (doc 04 sections 2 and 7.3) and the PLAN.md
	part budgets. Blocks a species from shipping when it fails (src/tests/RigValidator.spec.luau).

		local result = RigValidator.validate(model)
		if not result.ok then warn(table.concat(result.errors, "\n")) end
		print(result.counts.visualParts)

	Checks: model attributes; HumanoidRootPart is the PrimaryPart and the only collider; one Humanoid (R15,
	HipHeight that puts the feet on the ground, BreakJointsOnDeath and RequiresNeck off) and no scripts; required
	bones for the locomotion, flat under the Model, each with Motor6D J_<Bone> inside it whose Part0 is the
	standard parent and whose C0/C1 line up in the rest pose; D_ decorations inside a bone and welded to it;
	visual-part physics flags, Zone attribute, no transparency or Glass, shadows off on small zones; HB_ hitboxes
	(required set, invisible, query-only, welded, DinoHitbox group); every required S_/FX_ attachment on its bone
	with SocketScale; budgets (visual parts, hitboxes, attachments, instances); the 0.5-stud grid at adult
	proportions. It works at any Model:ScaleTo scale and any pivot position, on a rig in its rest pose.
]]

local RigMap = require(script.Parent.RigMap)

export type Counts = {
	bones: number,
	decorations: number,
	visualParts: number,
	hitboxes: number,
	attachments: number,
	instances: number,
	neonParts: number,
}

export type Result = {
	ok: boolean,
	errors: { string },
	counts: Counts,
}

local RigValidator = {}

local EPSILON = 1e-3
local MAX_NEON_PARTS = 4 -- doc 04 section 1.6

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

-- World-axis extents of a part's box in the given frame (works for any rotation).
local function extentsIn(frame: CFrame, part: BasePart): Vector3
	local cframe = frame:ToObjectSpace(part.CFrame)
	local size = part.Size
	return (cframe.RightVector * size.X):Abs() + (cframe.UpVector * size.Y):Abs() + (cframe.LookVector * size.Z):Abs()
end

local function isAxisAligned(cframe: CFrame): boolean
	for _, axis in { cframe.RightVector, cframe.UpVector, cframe.LookVector } do
		for _, component in { axis.X, axis.Y, axis.Z } do
			local magnitude = math.abs(component)
			if magnitude > EPSILON and magnitude < 1 - EPSILON then
				return false
			end
		end
	end
	return true
end

local function weldedTo(part: BasePart, bonePart: BasePart): boolean
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") and child.Enabled then
			local forward = child.Part0 == bonePart and child.Part1 == part
			local backward = child.Part0 == part and child.Part1 == bonePart
			if forward or backward then
				return true
			end
		end
	end
	return false
end

function RigValidator.validate(model: Instance): Result
	local errors: { string } = {}
	local counts: Counts = {
		bones = 0,
		decorations = 0,
		visualParts = 0,
		hitboxes = 0,
		attachments = 0,
		instances = 0,
		neonParts = 0,
	}
	local function fail(format: string, ...: any): ()
		table.insert(errors, string.format(format, ...))
	end
	local function finish(): Result
		return { ok = #errors == 0, errors = errors, counts = counts }
	end

	if not model:IsA("Model") then
		fail("%s is a %s, expected a Model", model.Name, model.ClassName)
		return finish()
	end
	local rig = model :: Model
	counts.instances = #rig:GetDescendants() + 1

	-- Model attributes ---------------------------------------------------------------------------------------
	for _, name in RigMap.ModelAttributes do
		if rig:GetAttribute(name) == nil then
			fail("model attribute %s is missing", name)
		end
	end
	local sizeClass = rig:GetAttribute("SizeClass")
	local budget = if type(sizeClass) == "string" then RigMap.Budgets[sizeClass] else nil
	if budget == nil then
		fail("SizeClass %s is not Small, Medium or Large", tostring(sizeClass))
	end
	local locomotion = rig:GetAttribute("Locomotion")
	if locomotion ~= "Biped" and locomotion ~= "Quadruped" then
		fail("Locomotion %s is not Biped or Quadruped", tostring(locomotion))
		locomotion = "Biped"
	end
	if rig:GetAttribute("RigVersion") ~= RigMap.RigVersion then
		fail("RigVersion is %s, expected %d", tostring(rig:GetAttribute("RigVersion")), RigMap.RigVersion)
	end

	-- Root -----------------------------------------------------------------------------------------------------
	local rootInstance = rig:FindFirstChild(RigMap.RootName)
	if rootInstance == nil or not rootInstance:IsA("BasePart") then
		fail("%s is missing (it must be a BasePart directly under the Model)", RigMap.RootName)
		return finish()
	end
	local root = rootInstance :: BasePart
	if rig.PrimaryPart ~= root then
		fail("PrimaryPart must be %s", RigMap.RootName)
	end
	if root.Transparency ~= 1 then
		fail("%s.Transparency must be 1", RigMap.RootName)
	end
	if not root.CanCollide or not root.CanQuery or root.CanTouch or root.Massless then
		fail("%s flags must be CanCollide, CanQuery, not CanTouch, not Massless", RigMap.RootName)
	end

	local scale = rig:GetScale()
	local pivot = rig:GetPivot()

	-- Scripts and Humanoid ---------------------------------------------------------------------------------------
	local humanoids = 0
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			fail("%s: rigs must not contain scripts (no default Animate)", descendant:GetFullName())
		elseif descendant:IsA("Humanoid") then
			humanoids += 1
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoids ~= 1 or humanoid == nil then
		fail("expected exactly one Humanoid directly under the Model, found %d", humanoids)
	else
		if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			fail("Humanoid.RigType must be R15 so HipHeight is used")
		end
		if humanoid.BreakJointsOnDeath or humanoid.RequiresNeck then
			fail("Humanoid.BreakJointsOnDeath and RequiresNeck must be false")
		end
		if humanoid.AutomaticScalingEnabled then
			fail("Humanoid.AutomaticScalingEnabled must be false")
		end
	end

	-- Bones ------------------------------------------------------------------------------------------------------
	local bones: { [string]: BasePart } = {}
	local present: { [string]: boolean } = {}
	local hitboxes: { BasePart } = {}
	for _, child in rig:GetChildren() do
		if not child:IsA("BasePart") or child == root then
			continue
		end
		local part = child :: BasePart -- the IsA check above does not narrow `child` for the type checker
		if startsWith(part.Name, RigMap.HitboxPrefix) then
			table.insert(hitboxes, part)
		elseif RigMap.boneDef(part.Name) then
			if bones[part.Name] then
				fail("bone %s appears twice", part.Name)
			end
			bones[part.Name] = part
			present[part.Name] = true
		else
			fail("unexpected part %s under the Model (only bones, HB_ hitboxes and %s)", part.Name, RigMap.RootName)
		end
	end

	for _, def in RigMap.Bones do
		local requirement = if locomotion == "Quadruped" then def.Quadruped else def.Biped
		if requirement == "required" and not present[def.name] then
			fail("required bone %s is missing", def.name)
		end
	end

	local motorCount = 0
	for name, bonePart in bones do
		counts.bones += 1
		local expectedName = RigMap.expectedParent(name, present)
		local expectedParent: BasePart? = nil
		if expectedName == RigMap.RootName then
			expectedParent = root
		elseif expectedName then
			expectedParent = bones[expectedName]
		end
		local joint = bonePart:FindFirstChild(RigMap.JointPrefix .. name)
		if joint == nil or not joint:IsA("Motor6D") then
			fail("%s: Motor6D %s%s is missing inside the bone", name, RigMap.JointPrefix, name)
			continue
		end
		local motor = joint :: Motor6D
		if motor.Part1 ~= bonePart then
			fail("%s: %s.Part1 must be the bone itself", name, motor.Name)
		end
		if expectedParent == nil then
			fail("%s: its standard parent %s is missing", name, tostring(expectedName))
		elseif motor.Part0 ~= expectedParent then
			local actual = if motor.Part0 then motor.Part0.Name else "nil"
			fail("%s: %s.Part0 is %s, expected %s", name, motor.Name, actual, expectedParent.Name)
		elseif motor.Part0 and motor.Part1 then
			local fromParent = motor.Part0.CFrame * motor.C0
			local fromChild = motor.Part1.CFrame * motor.C1
			if (fromParent.Position - fromChild.Position).Magnitude > EPSILON * math.max(scale, 1) then
				fail("%s: %s C0 and C1 do not meet at one pivot in the rest pose", name, motor.Name)
			end
		end
	end
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motorCount += 1
		end
	end
	if motorCount ~= counts.bones then
		fail("found %d Motor6D joints for %d bones (one J_<Bone> per bone, no others)", motorCount, counts.bones)
	end

	-- Visual parts (bones + decorations) ---------------------------------------------------------------------
	local grounded = math.huge
	local checkGrid = (rig:GetAttribute(RigMap.ProportionStageAttribute) or 4) == 4
	local function checkVisual(part: BasePart): ()
		counts.visualParts += 1
		local name = part:GetFullName()
		if part.CanCollide or part.CanQuery or part.CanTouch or not part.Massless then
			fail("%s: visual parts must be CanCollide/CanQuery/CanTouch false and Massless", name)
		end
		if part.Anchored then
			fail("%s: visual parts must not be anchored", name)
		end
		local zone = part:GetAttribute(RigMap.ZoneAttribute)
		if type(zone) ~= "string" or table.find(RigMap.Zones, zone) == nil then
			fail("%s: Zone attribute %s is not a paint zone", name, tostring(zone))
		elseif RigMap.NoShadowZones[zone] and part.CastShadow then
			fail("%s: %s parts must not cast shadows", name, zone)
		end
		if part.Material == Enum.Material.Glass then
			fail("%s: Glass is not allowed on dinos", name)
		elseif part.Material == Enum.Material.Neon then
			counts.neonParts += 1
		end
		if part.Transparency ~= 0 and zone ~= "Pattern" then
			fail("%s: visual parts must be opaque (Transparency 0)", name)
		end
		local relative = pivot:ToObjectSpace(part.CFrame)
		local extents = extentsIn(pivot, part)
		grounded = math.min(grounded, relative.Position.Y - extents.Y / 2)
		if checkGrid then
			if not isAxisAligned(relative) then
				fail("%s: rotation must be a multiple of 90 degrees", name)
			else
				local issue = RigMap.gridIssue(relative.Position / scale, extents / scale)
				if issue then
					fail("%s: off the %g-stud grid: %s", name, RigMap.Grid, issue)
				end
			end
		end
	end

	for boneName, bonePart in bones do
		checkVisual(bonePart)
		for _, child in bonePart:GetChildren() do
			if child:IsA("BasePart") then
				if not startsWith(child.Name, RigMap.DecorationPrefix) then
					fail("%s.%s: parts inside a bone must be D_ decorations", boneName, child.Name)
				end
				if not weldedTo(child, bonePart) then
					fail("%s.%s: decoration must be welded to its bone with a WeldConstraint", boneName, child.Name)
				end
				for _, nested in child:GetChildren() do
					if nested:IsA("BasePart") then
						fail("%s: decorations cannot contain parts", nested:GetFullName())
					end
				end
				counts.decorations += 1
				checkVisual(child)
			end
		end
	end
	if counts.neonParts > MAX_NEON_PARTS then
		fail("%d Neon parts, at most %d", counts.neonParts, MAX_NEON_PARTS)
	end

	-- Standing on the ground: the pivot is the ground point, the feet touch it, HipHeight lifts the root to fit.
	if grounded ~= math.huge and not near(grounded, 0, 0.01 * scale + EPSILON) then
		fail("the lowest visual part is %.3f studs from the model pivot; feet must rest on the pivot (Y = 0)", grounded)
	end
	if humanoid then
		local rootBottom = pivot:ToObjectSpace(root.CFrame).Position.Y - extentsIn(pivot, root).Y / 2
		if not near(humanoid.HipHeight, rootBottom, 0.01 * scale + EPSILON) then
			local message = "Humanoid.HipHeight is %.3f but the root's bottom is %.3f above the feet"
			fail(message, humanoid.HipHeight, rootBottom)
		end
	end

	-- Hitboxes -----------------------------------------------------------------------------------------------
	local hitboxNames: { [string]: boolean } = {}
	for _, hitbox in hitboxes do
		counts.hitboxes += 1
		hitboxNames[hitbox.Name] = true
		local name = hitbox.Name
		if hitbox.Transparency ~= 1 then
			fail("%s: hitboxes must be invisible (Transparency 1)", name)
		end
		if hitbox.CanCollide or not hitbox.CanQuery or hitbox.CanTouch or not hitbox.Massless then
			fail("%s: hitbox flags must be CanQuery only, Massless", name)
		end
		if hitbox.CollisionGroup ~= RigMap.HitboxCollisionGroup then
			fail("%s: CollisionGroup is %s, expected %s", name, hitbox.CollisionGroup, RigMap.HitboxCollisionGroup)
		end
		local welded = false
		for _, bonePart in bones do
			if weldedTo(hitbox, bonePart) then
				welded = true
				break
			end
		end
		if not welded then
			fail("%s: hitbox must be welded to a bone with a WeldConstraint", name)
		end
	end
	for _, name in RigMap.RequiredHitboxes do
		if not hitboxNames[name] then
			fail("required hitbox %s is missing", name)
		end
	end

	-- Sockets and effect points ------------------------------------------------------------------------------
	local attachments: { [string]: Attachment } = {}
	for _, descendant in rig:GetDescendants() do
		if not descendant:IsA("Attachment") then
			continue
		end
		counts.attachments += 1
		local name = descendant.Name
		if not startsWith(name, RigMap.SocketPrefix) and not startsWith(name, RigMap.FxPrefix) then
			fail("%s: attachment names start with S_ or FX_", descendant:GetFullName())
		end
		if attachments[name] then
			fail("attachment %s appears twice", name)
		end
		attachments[name] = descendant
		local socketScale = descendant:GetAttribute(RigMap.SocketScaleAttribute)
		if type(socketScale) ~= "number" or socketScale <= 0 then
			fail("%s: SocketScale attribute must be a number > 0", name)
		end
	end
	local known: { [string]: boolean } = {}
	for _, def in RigMap.Attachments do
		known[def.name] = true
		local requirement = if locomotion == "Quadruped" then def.Quadruped else def.Biped
		local attachment = attachments[def.name]
		local boneName = RigMap.expectedAttachmentBone(def, present)
		if attachment == nil then
			if requirement == "required" then
				fail("required attachment %s is missing", def.name)
			end
		elseif boneName == nil or attachment.Parent ~= bones[boneName] then
			local parentName = if attachment.Parent then attachment.Parent.Name else "nil"
			fail("%s is on %s, expected on %s", def.name, parentName, tostring(boneName))
		end
	end
	for name in attachments do
		if not known[name] then
			fail("attachment %s is not a standard socket or effect point", name)
		end
	end

	-- Budgets --------------------------------------------------------------------------------------------------
	if budget then
		if counts.visualParts > budget.visualParts then
			fail("%d visual parts, budget %d for %s", counts.visualParts, budget.visualParts, tostring(sizeClass))
		end
		if counts.hitboxes < budget.minHitboxes or counts.hitboxes > budget.maxHitboxes then
			fail("%d hitboxes, budget %d-%d", counts.hitboxes, budget.minHitboxes, budget.maxHitboxes)
		end
		if counts.attachments < budget.minAttachments or counts.attachments > budget.maxAttachments then
			fail("%d attachments, budget %d-%d", counts.attachments, budget.minAttachments, budget.maxAttachments)
		end
		if counts.instances > budget.instances then
			fail("%d instances, budget %d", counts.instances, budget.instances)
		end
	end

	return finish()
end

return table.freeze(RigValidator)
