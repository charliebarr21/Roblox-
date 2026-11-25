-- ServerMain (Script, server only). Boots every service in dependency order.
-- DataService is initialised LAST so every other service has already subscribed to ProfileLoaded.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"StateService",
	"EconomyService",
	"PlotService",
	"DataService",
}

local loaded: { [string]: any } = {}
local failures = 0

for _, name in ORDER do
	local module = Services:WaitForChild(name)
	local ok, service = pcall(require, module)
	if not ok then
		failures += 1
		warn(("[ServerMain] Failed to load %s: %s"):format(name, tostring(service)))
	else
		loaded[name] = service
		if type(service) == "table" and service.Init then
			local initOk, err = pcall(service.Init)
			if not initOk then
				failures += 1
				warn(("[ServerMain] %s.Init failed: %s"):format(name, tostring(err)))
			end
		end
	end
end

-- Studio-only test hook. The command bar keeps its own module cache, so require()-ing a service there gives a
-- fresh copy with no player data. Invoke this instead (Server context):
--   game.ServerStorage.DebugEconomy:Invoke("AddCash", game.Players:GetPlayers()[1], 250)
-- Never created on live servers.
if RunService:IsStudio() and loaded.EconomyService then
	local economy = loaded.EconomyService
	local hook = Instance.new("BindableFunction")
	hook.Name = "DebugEconomy"
	hook.OnInvoke = function(method: string, player: Player, amount: number)
		local fn = economy[method]
		if type(fn) ~= "function" then
			return ("unknown method %s (use AddCash, TrySpend, AddXP, GetCash)"):format(tostring(method))
		end
		return fn(player, amount, "Debug")
	end
	hook.Parent = ServerStorage
end

if failures == 0 then
	print("[ServerMain] Run a Firework Stand - Phase 1 server ready")
else
	warn(("[ServerMain] Phase 1 server started with %d error(s); see warnings above"):format(failures))
end
