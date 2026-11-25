--!strict
-- RigBuilder and RigValidator build and inspect real Instances, so this spec only runs in Studio. Every rig is
-- built unparented and destroyed afterwards, so running it leaves the place unchanged.
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	if t.runner ~= "studio" then
		t.skip("RigBuilder/RigValidator", "needs Roblox Instances (Studio only)")
		return
	end

	local RigMap = t.load("Shared/Dino/RigMap")
	local RigBuilder = t.load("Shared/Dino/RigBuilder")
	local RigValidator = t.load("Shared/Dino/RigValidator")
	local Velociraptor = t.load("Shared/Dino/RigSpecs/Velociraptor")
	local expect = t.expect

	local function errorsOf(model: Model): string
		return table.concat(RigValidator.validate(model).errors, " | ")
	end

	-- Builds a raptor, applies `mutate`, and expects a validator error containing `fragment`.
	local function expectError(fragment: string, mutate: (Model) -> ())
		local model = RigBuilder.build(Velociraptor)
		mutate(model)
		local errors = errorsOf(model)
		model:Destroy()
		if not string.find(errors, fragment, 1, true) then
			error(string.format("expected an error containing %q, got: %s", fragment, errors), 2)
		end
	end

	local function lowestVisualY(model: Model): number
		local pivot = model:GetPivot()
		local lowest = math.huge
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant:GetAttribute(RigMap.ZoneAttribute) ~= nil then
				local relative = pivot:ToObjectSpace(descendant.CFrame)
				local size = descendant.Size
				local extentY = math.abs(relative.RightVector.Y * size.X)
					+ math.abs(relative.UpVector.Y * size.Y)
					+ math.abs(relative.LookVector.Y * size.Z)
				lowest = math.min(lowest, relative.Position.Y - extentY / 2)
			end
		end
		return lowest
	end

	t.describe("RigBuilder.build (Velociraptor)", function()
		t.it("passes the validator with the expected counts", function()
			local model = RigBuilder.build(Velociraptor)
			local result = RigValidator.validate(model)
			expect(table.concat(result.errors, " | ")).toBe("")
			expect(result.ok).toBe(true)
			expect(result.counts.bones).toBe(#Velociraptor.bones)
			expect(result.counts.decorations).toBe(#Velociraptor.decorations)
			expect(result.counts.visualParts <= RigMap.Budgets.Small.visualParts).toBe(true)
			expect(result.counts.hitboxes).toBe(3)
			expect(result.counts.attachments).toBe(#Velociraptor.attachments)
			expect(result.counts.instances <= RigMap.Budgets.Small.instances).toBe(true)
			model:Destroy()
		end)

		t.it("makes HumanoidRootPart the PrimaryPart and the only collider", function()
			local model = RigBuilder.build(Velociraptor)
			local root = model:FindFirstChild(RigMap.RootName)
			expect(model.PrimaryPart).toBe(root)
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					expect(descendant.CanCollide).toBe(descendant == root)
					expect(descendant.Anchored).toBe(false)
				end
			end
			model:Destroy()
		end)

		t.it("sets up the Humanoid for a custom rig, with no scripts", function()
			local model = RigBuilder.build(Velociraptor)
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			expect(humanoid.RigType).toBe(Enum.HumanoidRigType.R15)
			expect(humanoid.HipHeight).toBeNear(RigBuilder.hipHeight(Velociraptor))
			expect(humanoid.HipHeight).toBeNear(3)
			expect(humanoid.BreakJointsOnDeath).toBe(false)
			expect(humanoid.RequiresNeck).toBe(false)
			expect(humanoid.AutomaticScalingEnabled).toBe(false)
			expect(model:GetAttribute(RigBuilder.BaseHipHeightAttribute)).toBe(humanoid.HipHeight)
			expect(model:FindFirstChildWhichIsA("LuaSourceContainer", true)).toBeNil()
			model:Destroy()
		end)

		t.it("puts the pivot on the ground under the root", function()
			local model = RigBuilder.build(Velociraptor)
			expect((model:GetPivot().Position - Vector3.zero).Magnitude).toBeNear(0)
			expect(lowestVisualY(model)).toBeNear(0)
			model:PivotTo(CFrame.new(5, 20, -3))
			expect(lowestVisualY(model)).toBeNear(0)
			expect(model:GetPivot().Position.Y).toBeNear(20)
			model:Destroy()
		end)

		t.it("joins every bone with J_<Bone> inside it, meeting at one pivot", function()
			local model = RigBuilder.build(Velociraptor)
			for _, boneSpec in Velociraptor.bones do
				local bone = model:FindFirstChild(boneSpec.name) :: BasePart
				local motor = bone:FindFirstChild(RigMap.JointPrefix .. boneSpec.name) :: Motor6D
				expect(motor ~= nil and motor:IsA("Motor6D")).toBe(true)
				expect(motor.Part1).toBe(bone)
				expect((motor.Part0 :: BasePart).Name).toBe(boneSpec.parent)
				local fromParent = (motor.Part0 :: BasePart).CFrame * motor.C0
				expect((fromParent.Position - boneSpec.pivot).Magnitude).toBeNear(0, 1e-4)
			end
			model:Destroy()
		end)

		t.it("welds decorations and hitboxes, and zones every visible part", function()
			local model = RigBuilder.build(Velociraptor)
			for _, decoration in Velociraptor.decorations do
				local bone = model:FindFirstChild(decoration.bone) :: BasePart
				local part = bone:FindFirstChild(decoration.name) :: BasePart
				local weld = part:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
				expect(weld.Part0).toBe(bone)
				expect(part:GetAttribute(RigMap.ZoneAttribute)).toBe(decoration.zone)
				expect(part.Massless).toBe(true)
			end
			for _, hitbox in Velociraptor.hitboxes do
				local part = model:FindFirstChild(hitbox.name) :: BasePart
				expect(part.Transparency).toBe(1)
				expect(part.CanQuery).toBe(true)
				expect(part.CollisionGroup).toBe(RigMap.HitboxCollisionGroup)
				expect(part:GetAttribute(RigMap.ZoneAttribute)).toBeNil()
			end
			model:Destroy()
		end)

		t.it("builds a hatchling with a bigger head and the same contract", function()
			local adult = RigBuilder.build(Velociraptor)
			local hatchling = RigBuilder.build(Velociraptor, { stage = 1 })
			expect(errorsOf(hatchling)).toBe("")
			expect(hatchling:GetAttribute(RigMap.ProportionStageAttribute)).toBe(1)
			local adultHead = (adult:FindFirstChild("Head") :: BasePart).Size
			local hatchHead = (hatchling:FindFirstChild("Head") :: BasePart).Size
			expect(hatchHead.Y / adultHead.Y).toBeNear(1.25, 1e-4)
			local adultEye = ((adult:FindFirstChild("Head") :: BasePart):FindFirstChild("D_Eye_R") :: BasePart).Size
			local hatchEye = ((hatchling:FindFirstChild("Head") :: BasePart):FindFirstChild("D_Eye_R") :: BasePart).Size
			expect(hatchEye.Y / adultEye.Y).toBeNear(1.4, 1e-4)
			expect(#hatchling:GetDescendants()).toBe(#adult:GetDescendants())
			adult:Destroy()
			hatchling:Destroy()
		end)

		t.it("rejects a spec whose bone comes before its parent", function()
			local broken = table.clone(Velociraptor)
			broken.bones = table.clone(Velociraptor.bones)
			broken.bones[1], broken.bones[2] = broken.bones[2], broken.bones[1]
			expect(function()
				RigBuilder.build(broken)
			end).toThrow("comes before its parent")
		end)
	end)

	t.describe("RigBuilder.scaleTo", function()
		t.it("scales the rig about the ground and keeps it valid at every preview stage", function()
			for stage, scale in RigMap.PreviewStageScales.Small do
				local model = RigBuilder.build(Velociraptor, { stage = stage })
				model:PivotTo(CFrame.new(0, 10, 0))
				RigBuilder.scaleTo(model, scale)
				expect(model:GetScale()).toBeNear(scale)
				expect(errorsOf(model)).toBe("")
				local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
				expect(humanoid.HipHeight).toBeNear(3 * scale, 1e-4)
				expect(lowestVisualY(model)).toBeNear(0, 1e-3)
				expect(model:GetPivot().Position.Y).toBeNear(10, 1e-3)
				model:Destroy()
			end
		end)

		t.it("scales Motor6D offsets and returns to the adult rig exactly", function()
			local model = RigBuilder.build(Velociraptor)
			local head = model:FindFirstChild("Head") :: BasePart
			local motor = head:FindFirstChild("J_Head") :: Motor6D
			local adultC0 = motor.C0.Position
			RigBuilder.scaleTo(model, 0.5)
			expect((motor.C0.Position - adultC0 * 0.5).Magnitude).toBeNear(0, 1e-4)
			RigBuilder.scaleTo(model, 1)
			expect((motor.C0.Position - adultC0).Magnitude).toBeNear(0, 1e-4)
			expect((model:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight).toBe(3)
			expect(errorsOf(model)).toBe("")
			model:Destroy()
		end)
	end)

	t.describe("RigValidator.validate", function()
		t.it("rejects a non-Model", function()
			local part = Instance.new("Part")
			local result = RigValidator.validate(part)
			expect(result.ok).toBe(false)
			part:Destroy()
		end)
		t.it("flags a second collider", function()
			expectError("CanCollide", function(model)
				(model:FindFirstChild("Torso") :: BasePart).CanCollide = true
			end)
		end)
		t.it("flags a missing joint", function()
			expectError("J_Head", function(model)
				((model:FindFirstChild("Head") :: BasePart):FindFirstChild("J_Head") :: Instance):Destroy()
			end)
		end)
		t.it("flags a joint with the wrong parent bone", function()
			expectError("expected Neck1", function(model)
				local head = model:FindFirstChild("Head") :: BasePart
				local joint = head:FindFirstChild("J_Head") :: Motor6D
				joint.Part0 = model:FindFirstChild("Torso") :: BasePart
			end)
		end)
		t.it("flags a missing required bone", function()
			expectError("required bone Tail3", function(model)
				(model:FindFirstChild("Tail3") :: Instance):Destroy()
			end)
		end)
		t.it("flags a missing socket", function()
			expectError("S_Mouth", function(model)
				((model:FindFirstChild("Jaw") :: BasePart):FindFirstChild("S_Mouth") :: Instance):Destroy()
			end)
		end)
		t.it("flags a decoration without the D_ prefix", function()
			expectError("D_ decorations", function(model)
				((model:FindFirstChild("Head") :: BasePart):FindFirstChild("D_Eye_L") :: Instance).Name = "Eye"
			end)
		end)
		t.it("flags a part with no paint zone", function()
			expectError("Zone attribute", function(model)
				(model:FindFirstChild("Hips") :: BasePart):SetAttribute(RigMap.ZoneAttribute, nil)
			end)
		end)
		t.it("flags the visual-part budget", function()
			expectError("visual parts, budget 35", function(model)
				local torso = model:FindFirstChild("Torso") :: BasePart
				local chest = torso:FindFirstChild("D_Chest") :: BasePart
				for index = 1, 3 do
					local extra = chest:Clone()
					extra.Name = "D_Extra" .. index
					local extraWeld = extra:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
					extraWeld.Part1 = extra
					extra.Parent = torso
				end
			end)
		end)
		t.it("flags a part off the 0.5-stud grid", function()
			expectError("grid", function(model)
				local chest = (model:FindFirstChild("Torso") :: BasePart):FindFirstChild("D_Chest") :: BasePart
				chest.Size += Vector3.new(0.2, 0, 0)
			end)
		end)
		t.it("flags a HipHeight that does not put the feet on the ground", function()
			expectError("HipHeight", function(model)
				(model:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight = 4
			end)
		end)
		t.it("flags a visible hitbox", function()
			expectError("invisible", function(model)
				(model:FindFirstChild("HB_Body") :: BasePart).Transparency = 0
			end)
		end)
		t.it("flags scripts inside the rig", function()
			expectError("scripts", function(model)
				Instance.new("Script").Parent = model
			end)
		end)
	end)
end
