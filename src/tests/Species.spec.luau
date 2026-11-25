--!strict
-- Species data (Shared/Species), the pure stage lookup (Shared/Logic/Growth) and the collision group names.
-- The data checks run in Studio and under Lune; the rig-at-every-stage check builds Instances (Studio only).
local TestKit = require(script.Parent.TestKit)

return function(t: TestKit.Context)
	local expect = t.expect
	local Growth = t.load("Shared/Logic/Growth")
	local Velociraptor = t.load("Shared/Species/Velociraptor")
	local RigMap = t.load("Shared/Dino/RigMap")
	local RigBuilder = t.load("Shared/Dino/RigBuilder")
	local RaptorRig = t.load("Shared/Dino/RigSpecs/Velociraptor")
	local CollisionGroups = t.load("Shared/CollisionGroups")

	t.describe("Growth.isStage", function()
		t.it("accepts the four stage indexes", function()
			for stage = 1, 4 do
				expect(Growth.isStage(stage)).toBe(true)
			end
			expect(Growth.StageCount).toBe(4)
			expect(#Growth.StageNames).toBe(4)
		end)
		t.it("rejects out-of-range, fractional, NaN, infinite and non-number values", function()
			for _, value in { 0, 5, -1, 1.5, 0 / 0, math.huge, -math.huge, "1", true, {} } do
				expect(Growth.isStage(value)).toBe(false)
			end
			expect(Growth.isStage(nil)).toBe(false)
		end)
	end)

	t.describe("Growth.stageAt", function()
		t.it("returns the entry for a valid stage", function()
			local stages = { "a", "b", "c", "d" }
			expect(Growth.stageAt(stages, 1)).toBe("a")
			expect(Growth.stageAt(stages, 4)).toBe("d")
		end)
		t.it("returns nil for an invalid stage or a missing entry", function()
			local stages = { "a", "b" }
			expect(Growth.stageAt(stages, 0)).toBeNil()
			expect(Growth.stageAt(stages, 2.5)).toBeNil()
			expect(Growth.stageAt(stages, 0 / 0)).toBeNil()
			expect(Growth.stageAt(stages, 3)).toBeNil()
		end)
	end)

	t.describe("Species.Velociraptor", function()
		local stages = Velociraptor.stages
		t.it("has four stages named like Growth.StageNames", function()
			expect(#stages).toBe(4)
			for index, stage in stages do
				expect(stage.name).toBe(Growth.StageNames[index])
			end
		end)
		t.it("uses doc 01's Small-class scales and walk speeds", function()
			local scales = { 0.37, 0.58, 0.79, 1.0 }
			local walk = { 11.9, 13.3, 14, 14 }
			local sprint = { 27.2, 31.3, 35, 34 }
			for index = 1, 4 do
				expect(Growth.stageAt(stages, index).scale).toBeNear(scales[index])
				expect(Growth.stageAt(stages, index).walkSpeed).toBeNear(walk[index])
				expect(Growth.stageAt(stages, index).sprintSpeed).toBeNear(sprint[index])
			end
		end)
		t.it("grows monotonically: growthAt, scale, health and mass rise; adult is scale 1 at growth 1", function()
			for index = 2, 4 do
				local previous, current = stages[index - 1], stages[index]
				expect(current.growthAt > previous.growthAt).toBe(true)
				expect(current.scale > previous.scale).toBe(true)
				expect(current.maxHealth > previous.maxHealth).toBe(true)
				expect(current.mass > previous.mass).toBe(true)
			end
			expect(stages[1].growthAt).toBe(0)
			expect(stages[4].growthAt).toBe(1)
			expect(stages[4].scale).toBe(1)
		end)
		t.it("stores drains as fractions per minute", function()
			expect(stages[1].hungerPerMinute).toBeNear(0.091)
			expect(stages[4].thirstPerMinute).toBeNear(0.09)
		end)
		t.it("matches its rig: name, size class, diet and HipHeight x scale", function()
			expect(Velociraptor.rigName).toBe(RaptorRig.species)
			expect(Velociraptor.sizeClass).toBe(RaptorRig.sizeClass)
			expect(Velociraptor.diet).toBe(RaptorRig.diet)
			local rigHipHeight = RigBuilder.hipHeight(RaptorRig)
			for _, stage in stages do
				expect(stage.hipHeight).toBeNear(rigHipHeight * stage.scale)
			end
		end)
		t.it("is frozen", function()
			expect(table.isfrozen(Velociraptor)).toBe(true)
			expect(table.isfrozen(stages)).toBe(true)
		end)
	end)

	t.describe("CollisionGroups", function()
		t.it("uses the rig standard's hitbox group name", function()
			expect(CollisionGroups.DinoHitbox).toBe(RigMap.HitboxCollisionGroup)
		end)
	end)

	if t.runner ~= "studio" then
		t.skip("Velociraptor rig at every species stage", "needs Roblox Instances (Studio only)")
		return
	end

	t.describe("Velociraptor rig at every species stage", function()
		t.it("stands on the ground with the root at HipHeight after ScaleTo", function()
			local model = RigBuilder.build(RaptorRig)
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			local root = model.PrimaryPart :: BasePart
			local ground = CFrame.new(10, 3, -20)
			for _, stage in Velociraptor.stages do
				RigBuilder.scaleTo(model, stage.scale)
				model:PivotTo(ground)
				local lowest = math.huge
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") and part:GetAttribute(RigMap.ZoneAttribute) ~= nil then
						local cf, size = part.CFrame, part.Size
						local extentY = math.abs(cf.RightVector.Y * size.X)
							+ math.abs(cf.UpVector.Y * size.Y)
							+ math.abs(cf.LookVector.Y * size.Z)
						lowest = math.min(lowest, cf.Position.Y - extentY / 2)
					end
				end
				expect(lowest).toBeNear(ground.Y, 1e-3) -- feet exactly on the ground
				expect(humanoid.HipHeight).toBeNear(stage.hipHeight, 1e-4)
				local rootBottom = root.Position.Y - root.Size.Y / 2
				expect(rootBottom - ground.Y).toBeNear(stage.hipHeight, 1e-3) -- Humanoid holds the root here
			end
			model:Destroy()
		end)
		t.it("rejects scales that are not finite and positive, and builds atomic for streaming", function()
			local model = RigBuilder.build(RaptorRig)
			for _, scale in { 0, -1, math.huge, 0 / 0 } do
				expect(function()
					RigBuilder.scaleTo(model, scale)
				end).toThrow("finite number > 0")
			end
			expect(model.ModelStreamingMode).toBe(Enum.ModelStreamingMode.Atomic)
			model:Destroy()
		end)
	end)
end
