-- EconomyService (ModuleScript, server only). The ONLY place cash and XP are changed.
-- Other services call AddCash / TrySpend / AddXP; nothing the client sends can reach these directly.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Utilities.Signal)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local EconomyService = {}
EconomyService.LevelUp = Signal.new() -- (player, newLevel)

-- Per-server totals of where money enters (Sources) and leaves (Sinks); Phase 7 forwards these to analytics.
EconomyService.Ledger = { Sources = {} :: { [string]: number }, Sinks = {} :: { [string]: number } }

local function isValidAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

function EconomyService.GetCash(player: Player): number
	local data = DataService.GetData(player)
	return if data then data.Cash else 0
end

-- `source` is a short label ("Sale", "QuestReward", "Debug"...). Only business income should pass countAsEarnings = true,
-- so lifetime earnings and leaderboards cannot be inflated by gifts.
function EconomyService.AddCash(player: Player, amount: number, source: string, countAsEarnings: boolean?): boolean
	local data = DataService.GetData(player)
	if not data or not isValidAmount(amount) then
		return false
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return false
	end
	data.Cash = math.min(data.Cash + amount, EconomyConfig.MaxCash)
	if countAsEarnings then
		data.Stats.LifetimeEarnings += amount
	end
	EconomyService.Ledger.Sources[source] = (EconomyService.Ledger.Sources[source] or 0) + amount
	StateService.Push(player, { Cash = data.Cash })
	return true
end

-- Atomically checks and deducts. Returns false (and changes nothing) if the player can't afford it.
function EconomyService.TrySpend(player: Player, amount: number, sink: string): boolean
	local data = DataService.GetData(player)
	if not data or not isValidAmount(amount) then
		return false
	end
	amount = math.ceil(amount)
	if amount <= 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	data.Stats.LifetimeSpent += amount
	EconomyService.Ledger.Sinks[sink] = (EconomyService.Ledger.Sinks[sink] or 0) + amount
	StateService.Push(player, { Cash = data.Cash })
	return true
end

function EconomyService.AddXP(player: Player, amount: number, source: string): boolean
	local data = DataService.GetData(player)
	if not data or not isValidAmount(amount) then
		return false
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return false
	end
	data.XP += amount
	local leveled = false
	while data.Level < EconomyConfig.XP.MaxLevel do
		local needed = EconomyConfig.XPToNextLevel(data.Level)
		if data.XP < needed then
			break
		end
		data.XP -= needed
		data.Level += 1
		leveled = true
	end
	if data.Level >= EconomyConfig.XP.MaxLevel then
		data.XP = 0
	end
	StateService.Push(player, { XP = data.XP, Level = data.Level })
	if leveled then
		EconomyService.LevelUp:Fire(player, data.Level)
	end
	return true
end

function EconomyService.GetStage(player: Player): number
	local data = DataService.GetData(player)
	return if data then data.BusinessStage else 1
end

function EconomyService.Init()
	DataService.ProfileLoaded:Connect(function(_player, data)
		data.Stats.Sessions += 1
	end)
end

return EconomyService
