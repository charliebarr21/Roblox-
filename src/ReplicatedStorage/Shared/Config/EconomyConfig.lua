--!strict
-- EconomyConfig (ModuleScript). Global economy numbers. Everything here is a tuning knob.

local EconomyConfig = {}

EconomyConfig.StartingCash = 100
EconomyConfig.MaxCash = 1e15 -- hard sanity cap so numbers never overflow display or storage

-- Player XP level curve: XP needed to go from `level` to `level + 1`.
EconomyConfig.XP = {
	Base = 40,
	Exponent = 1.55,
	MaxLevel = 100,
}

function EconomyConfig.XPToNextLevel(level: number): number
	return math.floor(EconomyConfig.XP.Base * (math.max(level, 1) ^ EconomyConfig.XP.Exponent))
end

-- Pacing targets from the design spec (seconds). Used by the Phase 8 balancing tools and analytics checks.
EconomyConfig.PacingTargets = {
	FirstSale = 60,
	FirstLaunch = 120,
	FirstUpgrade = { 180, 300 },
	FirstEmployee = { 600, 900 },
	FirstRareFirework = { 600, 1200 },
	FirstMajorExpansion = { 1200, 2400 },
}

EconomyConfig.OfflineEarningsCapSeconds = 8 * 60 * 60

EconomyConfig.SupplierRestockSeconds = 300

return EconomyConfig
