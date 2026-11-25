--!strict
-- Net creates real Instances, so this spec only runs in Studio. It builds into an unparented scratch folder,
-- never into ReplicatedStorage, so running it leaves the place unchanged.
local TestKit = require(script.Parent.TestKit)

local REMOTE_CLASSES = { RemoteEvent = true, UnreliableRemoteEvent = true, RemoteFunction = true }

return function(t: TestKit.Context)
	if t.runner ~= "studio" then
		t.skip("Net", "needs Roblox Instances (Studio only)")
		return
	end

	local Net = t.load("Shared/Net")
	local expect = t.expect

	t.describe("Net.Definitions", function()
		t.it("only uses remote classes and is frozen", function()
			local count = 0
			for name, className in Net.Definitions do
				count += 1
				expect(type(name)).toBe("string")
				expect(REMOTE_CLASSES[className]).toBe(true)
			end
			expect(count > 0).toBe(true)
			expect(table.isfrozen(Net.Definitions)).toBe(true)
		end)
	end)

	t.describe("Net.build", function()
		t.it("creates the folder with every remote, and is idempotent", function()
			local scratch = Instance.new("Folder")
			local folder = Net.build(scratch)
			expect(folder.Name).toBe(Net.FolderName)
			expect(folder.Parent).toBe(scratch)
			for name, className in Net.Definitions do
				local remote = folder:FindFirstChild(name)
				expect(remote ~= nil and remote.ClassName == className).toBe(true)
			end
			local attack = folder:FindFirstChild("Attack")
			local again = Net.build(scratch)
			expect(again).toBe(folder)
			expect(folder:FindFirstChild("Attack")).toBe(attack)
			local defined = 0
			for _ in Net.Definitions do
				defined += 1
			end
			expect(#folder:GetChildren()).toBe(defined)
			expect(#scratch:GetChildren()).toBe(1)
			scratch:Destroy()
		end)
		t.it("replaces a child of the wrong class", function()
			local scratch = Instance.new("Folder")
			local folder = Net.build(scratch)
			local original = folder:FindFirstChild("Fx")
			assert(original, "Net.build should have created Fx")
			original:Destroy()
			local wrong = Instance.new("RemoteEvent")
			wrong.Name = "Fx"
			wrong.Parent = folder
			Net.build(scratch)
			local replaced = folder:FindFirstChild("Fx") :: Instance
			expect(replaced.ClassName).toBe("UnreliableRemoteEvent")
			scratch:Destroy()
		end)
		t.it("refuses to overwrite a non-Folder named Remotes", function()
			local scratch = Instance.new("Folder")
			local blocker = Instance.new("Model")
			blocker.Name = Net.FolderName
			blocker.Parent = scratch
			expect(function()
				Net.build(scratch)
			end).toThrow("expected a Folder")
			scratch:Destroy()
		end)
	end)

	t.describe("Net accessors", function()
		t.it("reject unknown names and the wrong class before touching anything", function()
			expect(function()
				Net.serverEvent("NoSuchRemote")
			end).toThrow("unknown remote")
			expect(function()
				Net.serverEvent("RequestSpawn")
			end).toThrow("is a RemoteFunction")
			expect(function()
				Net.clientUnreliable("Attack")
			end).toThrow("is a RemoteEvent")
		end)
	end)
end
