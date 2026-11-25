--!strict
--[[
	Net: the single list of remotes, and the only code that creates or finds them.

	Remotes live in ReplicatedStorage.Remotes, a folder created by code NEXT TO Rojo's Shared folder (Rojo deletes
	Studio-made children inside the folders it maps).

	Server: the first Net.serverEvent / serverFunction / serverUnreliable call creates the folder and EVERY remote in
	Definitions at once (idempotent), so no service has to run first and clients always see a complete set.
	Connect client-to-server remotes through ServerStorage.Modules.Lib.Guard, never directly.

	Client: Net.clientEvent / clientFunction / clientUnreliable wait for the remote on first use and warn after
	30 s. Call them in Start or later, never at require time (the Loader requires one module at a time).

	Never use RemoteFunction:InvokeClient. A client-to-server RemoteFunction is only for request/response menus.
	Add a remote here in the same ticket that adds its handler (doc 05 section 4.2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteClass = "RemoteEvent" | "UnreliableRemoteEvent" | "RemoteFunction"

local FOLDER_NAME = "Remotes"
local CLIENT_WARN_SECONDS = 30

local Definitions: { [string]: RemoteClass } = table.freeze({
	-- Client -> server (always connected through Lib/Guard)
	RequestSpawn = "RemoteFunction",
	ReturnToMenu = "RemoteEvent",
	SetSprint = "RemoteEvent",
	SetRest = "RemoteEvent",
	Attack = "RemoteEvent",
	Vocal = "RemoteEvent",
	StopFeeding = "RemoteEvent",
	-- Studio-only debug (the server's Guard gate drops every call outside Studio)
	DebugSetStage = "RemoteEvent",
	-- Server -> client
	ProfileSync = "RemoteEvent",
	LifeEvent = "RemoteEvent",
	AttackResult = "RemoteEvent",
	Notify = "RemoteEvent",
	Fx = "UnreliableRemoteEvent",
} :: { [string]: RemoteClass })

local Net = {}

Net.FolderName = FOLDER_NAME
Net.Definitions = Definitions

local serverFolder: Folder? = nil
local clientFolder: Instance? = nil

local function expectClass(name: string, className: RemoteClass): ()
	local defined = Definitions[name]
	if defined == nil then
		error(string.format("[Net] unknown remote %q (add it to Net.Definitions)", name), 3)
	elseif defined ~= className then
		error(string.format("[Net] remote %q is a %s, not a %s", name, defined, className), 3)
	end
end

--[[
	Creates `parent.Remotes` with every remote in Definitions, reusing what already exists (a child with the right
	name but the wrong class is replaced). A new folder is filled before it is parented, so clients never see a
	partial set. Net's server functions call this with ReplicatedStorage; specs call it with a scratch folder.
]]
function Net.build(parent: Instance): Folder
	local existing = parent:FindFirstChild(FOLDER_NAME)
	local folder: Folder
	local isNew = false
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		if existing then
			error(string.format("[Net] %s is a %s, expected a Folder", existing:GetFullName(), existing.ClassName))
		end
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		isNew = true
	end

	for name, className in Definitions do
		local child = folder:FindFirstChild(name)
		if child and child.ClassName ~= className then
			child:Destroy()
			child = nil
		end
		if child == nil then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end

	if isNew then
		folder.Parent = parent
	end
	return folder
end

local function serverRemote(name: string, className: RemoteClass): Instance
	expectClass(name, className)
	assert(RunService:IsServer(), "[Net] server functions can only be called on the server")
	local folder = serverFolder
	if folder == nil or folder.Parent ~= ReplicatedStorage then
		folder = Net.build(ReplicatedStorage)
		serverFolder = folder
	end
	local remote = (folder :: Folder):FindFirstChild(name)
	assert(remote and remote.ClassName == className, "[Net] remote missing after build: " .. name)
	return remote
end

local function waitWithWarning(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, CLIENT_WARN_SECONDS)
	if child then
		return child
	end
	warn(string.format("[Net] still waiting for %s.%s after %d s", parent:GetFullName(), name, CLIENT_WARN_SECONDS))
	return parent:WaitForChild(name)
end

local function clientRemote(name: string, className: RemoteClass): Instance
	expectClass(name, className)
	assert(RunService:IsClient(), "[Net] client functions can only be called on a client")
	local folder = clientFolder
	if folder == nil then
		folder = waitWithWarning(ReplicatedStorage, FOLDER_NAME)
		clientFolder = folder
	end
	return waitWithWarning(folder :: Instance, name)
end

function Net.serverEvent(name: string): RemoteEvent
	return serverRemote(name, "RemoteEvent") :: RemoteEvent
end

function Net.serverFunction(name: string): RemoteFunction
	return serverRemote(name, "RemoteFunction") :: RemoteFunction
end

function Net.serverUnreliable(name: string): UnreliableRemoteEvent
	return serverRemote(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

function Net.clientEvent(name: string): RemoteEvent
	return clientRemote(name, "RemoteEvent") :: RemoteEvent
end

function Net.clientFunction(name: string): RemoteFunction
	return clientRemote(name, "RemoteFunction") :: RemoteFunction
end

function Net.clientUnreliable(name: string): UnreliableRemoteEvent
	return clientRemote(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

return table.freeze(Net)
