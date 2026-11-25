-- RemoteRegistry (ModuleScript). One place to create/fetch remotes. The server creates them on demand;
-- clients wait for them. All remotes live in ReplicatedStorage.Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteRegistry = {}

local function getFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

local function get(name: string, className: string): Instance
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name, 30)
end

function RemoteRegistry.Event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function RemoteRegistry.Function(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return RemoteRegistry
