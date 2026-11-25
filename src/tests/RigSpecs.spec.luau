--!strict
-- Species art specs (Shared/Dino/RigSpecs) checked as pure data against the rig standard in Shared/Dino/RigMap.
-- Runs in Studio and under Lune. The built-model checks live in RigValidator.spec (Studio only).
local TestKit = require(script.Parent.TestKit)

local SPECIES = { "Velociraptor" }

return function(t: TestKit.Context)
	local expect = t.expect
	local RigMap = t.load("Shared/Dino/RigMap")
	local Palette = t.load("Shared/Dino/Palette")

	t.describe("RigMap", function()
		t.it("lists every bone after its parent", function()
			local seen: { [string]: boolean } = { [RigMap.RootName] = true }
			for _, def in RigMap.Bones do
				if def.parent ~= "@LastNeck" then
					expect(seen[def.parent]).toBe(true)
				end
				seen[def.name] = true
			end
		end)
		t.it("puts Head on the last neck bone and tail sockets on the last tail bone", function()
			expect(RigMap.expectedParent("Head", { Neck1 = true })).toBe("Neck1")
			expect(RigMap.expectedParent("Head", { Neck1 = true, Neck2 = true, Neck3 = true })).toBe("Neck3")
			expect(RigMap.expectedParent("NotABone", {})).toBeNil()
			local tailTip: any = nil
			for _, def in RigMap.Attachments do
				if def.name == "S_TailTip" then
					tailTip = def
				end
			end
			assert(tailTip, "S_TailTip is a standard socket")
			expect(RigMap.expectedAttachmentBone(tailTip, { Tail1 = true, Tail2 = true, Tail3 = true })).toBe("Tail3")
			expect(RigMap.expectedAttachmentBone(tailTip, { Tail3 = true, Tail4 = true, Tail5 = true })).toBe("Tail5")
		end)
		t.it("uses the PLAN.md visual-part caps", function()
			expect(RigMap.Budgets.Small.visualParts).toBe(35)
			expect(RigMap.Budgets.Medium.visualParts).toBe(45)
			expect(RigMap.Budgets.Large.visualParts).toBe(60)
		end)
		t.it("checks the 0.5-stud grid on centres or faces", function()
			expect(RigMap.gridIssue(Vector3.new(0, 4, 0.25), Vector3.new(2, 2, 1.5))).toBeNil()
			expect(RigMap.gridIssue(Vector3.new(0.75, 0, 0), Vector3.new(0.5, 1, 1))).toBeNil()
			expect(RigMap.gridIssue(Vector3.new(0, 0, 0), Vector3.new(1.2, 1, 1))).never.toBeNil()
			expect(RigMap.gridIssue(Vector3.new(0.1, 0, 0), Vector3.new(1, 1, 1))).never.toBeNil()
		end)
		t.it("rotates extents by quarter turns only", function()
			local turned = RigMap.rotatedExtents(Vector3.new(1, 2, 3), Vector3.new(0, 90, 0))
			assert(turned, "a 90 degree turn has extents")
			expect(turned.X).toBe(3)
			expect(turned.Z).toBe(1)
			expect(RigMap.rotatedExtents(Vector3.new(1, 2, 3), Vector3.new(0, 45, 0))).toBeNil()
		end)
		t.it("is frozen", function()
			expect(table.isfrozen(RigMap)).toBe(true)
			expect(table.isfrozen(RigMap.Bones)).toBe(true)
			expect(table.isfrozen(Palette)).toBe(true)
		end)
	end)

	for _, species in SPECIES do
		local spec = t.load("Shared/Dino/RigSpecs/" .. species)
		t.describe("RigSpecs." .. species, function()
			local budget = RigMap.Budgets[spec.sizeClass]
			local boneSpecs: { [string]: any } = {}
			for _, boneSpec in spec.bones do
				boneSpecs[boneSpec.name] = boneSpec
			end

			t.it("names the species and a known size class and locomotion", function()
				expect(spec.species).toBe(species)
				expect(budget ~= nil).toBe(true)
				expect(spec.locomotion == "Biped" or spec.locomotion == "Quadruped").toBe(true)
			end)

			t.it("uses unique names with the standard prefixes", function()
				local seen: { [string]: boolean } = { [RigMap.RootName] = true }
				local function claim(name: string, prefix: string?)
					expect(seen[name]).toBeNil()
					seen[name] = true
					if prefix then
						expect(string.sub(name, 1, #prefix)).toBe(prefix)
					end
				end
				for _, boneSpec in spec.bones do
					expect(RigMap.boneDef(boneSpec.name) ~= nil).toBe(true)
					claim(boneSpec.name)
				end
				for _, decoration in spec.decorations do
					claim(decoration.name, RigMap.DecorationPrefix)
				end
				for _, hitbox in spec.hitboxes do
					claim(hitbox.name, RigMap.HitboxPrefix)
				end
			end)

			t.it("has every required bone, each after its standard parent", function()
				local present: { [string]: boolean } = {}
				for _, boneSpec in spec.bones do
					present[boneSpec.name] = true
				end
				local placed: { [string]: boolean } = { [RigMap.RootName] = true }
				for _, boneSpec in spec.bones do
					expect(boneSpec.parent).toBe(RigMap.expectedParent(boneSpec.name, present))
					expect(placed[boneSpec.parent]).toBe(true)
					placed[boneSpec.name] = true
				end
				for _, def in RigMap.Bones do
					if def[spec.locomotion] == "required" then
						expect(present[def.name]).toBe(true)
					end
				end
			end)

			t.it("stays within the visual-part and attachment budgets", function()
				local visual = #spec.bones + #spec.decorations
				expect(visual <= budget.visualParts).toBe(true)
				expect(#spec.hitboxes >= budget.minHitboxes and #spec.hitboxes <= budget.maxHitboxes).toBe(true)
				local attachments = #spec.attachments
				expect(attachments >= budget.minAttachments and attachments <= budget.maxAttachments).toBe(true)
			end)

			t.it("keeps every visual part on the 0.5-stud grid", function()
				local function check(name: string, center: Vector3, size: Vector3, rotation: Vector3?)
					local extents = RigMap.rotatedExtents(size, rotation)
					if extents == nil then
						error(name .. ": rotation must be a multiple of 90 degrees")
					end
					local issue = RigMap.gridIssue(center, extents)
					if issue then
						error(name .. ": " .. issue)
					end
				end
				for _, boneSpec in spec.bones do
					check(boneSpec.name, boneSpec.center, boneSpec.size, boneSpec.rotation)
				end
				for _, decoration in spec.decorations do
					check(decoration.name, decoration.center, decoration.size, decoration.rotation)
				end
			end)

			t.it("paints every part from a valid zone and a Palette swatch", function()
				local function check(zone: string)
					expect(table.find(RigMap.Zones, zone) ~= nil).toBe(true)
					local swatch = spec.colors[zone]
					expect(swatch ~= nil and Palette[swatch] ~= nil).toBe(true)
				end
				for _, boneSpec in spec.bones do
					check(boneSpec.zone)
				end
				for _, decoration in spec.decorations do
					check(decoration.zone)
					expect(boneSpecs[decoration.bone] ~= nil).toBe(true)
				end
			end)

			t.it("has every required socket and effect point on its standard bone", function()
				local present: { [string]: boolean } = {}
				for _, boneSpec in spec.bones do
					present[boneSpec.name] = true
				end
				local byName: { [string]: any } = {}
				for _, attachment in spec.attachments do
					expect(byName[attachment.name]).toBeNil()
					byName[attachment.name] = attachment
					expect(attachment.socketScale > 0).toBe(true)
				end
				for _, def in RigMap.Attachments do
					local attachment = byName[def.name]
					if attachment then
						expect(attachment.bone).toBe(RigMap.expectedAttachmentBone(def, present))
					else
						expect(def[spec.locomotion]).toBe("optional")
					end
				end
			end)

			t.it("has the required hitboxes on existing bones", function()
				local names: { [string]: boolean } = {}
				for _, hitbox in spec.hitboxes do
					names[hitbox.name] = true
					expect(boneSpecs[hitbox.bone] ~= nil).toBe(true)
				end
				for _, name in RigMap.RequiredHitboxes do
					expect(names[name]).toBe(true)
				end
			end)

			t.it("stands on the ground with the root above the feet", function()
				local lowest = math.huge
				local function track(center: Vector3, size: Vector3, rotation: Vector3?)
					local extents = RigMap.rotatedExtents(size, rotation) or size
					lowest = math.min(lowest, center.Y - extents.Y / 2)
				end
				for _, boneSpec in spec.bones do
					track(boneSpec.center, boneSpec.size, boneSpec.rotation)
				end
				for _, decoration in spec.decorations do
					track(decoration.center, decoration.size, decoration.rotation)
				end
				expect(lowest).toBeNear(0)
				local hipHeight = spec.root.center.Y - spec.root.size.Y / 2
				expect(hipHeight > 0).toBe(true)
				expect(spec.root.center.X).toBe(0)
				expect(spec.root.center.Z).toBe(0)
			end)
		end)
	end
end
