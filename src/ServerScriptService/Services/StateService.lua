-- StateService (ModuleScript, server only). Sends the small slice of player state the HUD needs.
-- Server is authoritative; clients only ever receive state, never submit it.
-- Changes are batched: many Push calls in one frame become a single remote.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RemoteRegistry = require(Shared.Utilities.RemoteRegistry)
local Security = require(script.Parent.Parent.Security)
local DataService = require(script.Parent.DataService)

local StateService = {}

local StateChanged: RemoteEvent
local GetState: RemoteFunction

local ready: { [Player]: boolean } = {}
local pending: { [Player]: { [string]: any } } = {}

local function snapshot(data)
	return {
		Cash = data.Cash,
		XP = data.XP,
		Level = data.Level,
		BusinessStage = data.BusinessStage,
		BusinessName = data.BusinessName,
	}
end

-- changes: { Cash = 123, XP = 4, ... }. Ignored until the client has fetched its first snapshot
-- (the snapshot already contains everything that happened before).
function StateService.Push(player: Player, changes: { [string]: any })
	if not ready[player] then
		return
	end
	local batch = pending[player]
	if not batch then
		batch = {}
		pending[player] = batch
		task.defer(function()
			pending[player] = nil
			if player.Parent then
				StateChanged:FireClient(player, batch)
			end
		end)
	end
	for key, value in changes do
		batch[key] = value
	end
end

function StateService.Init()
	StateChanged = RemoteRegistry.Event("StateChanged")
	GetState = RemoteRegistry.Function("GetState")

	GetState.OnServerInvoke = function(player: Player)
		if not Security.RateLimit(player, "GetState", 6, 10) then
			return nil
		end
		local data = DataService.WaitForData(player)
		if not data then
			return nil
		end
		ready[player] = true
		return snapshot(data)
	end

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		pending[player] = nil
	end)
end

return StateService
