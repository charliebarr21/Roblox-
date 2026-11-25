--!strict
-- RarityConfig (ModuleScript). Colours + supplier appearance weights. Tune weights after playtesting.

local Types = require(script.Parent.Parent.Types)

type RarityInfo = {
	Rank: number,
	Color: Color3,
	Weight: number, -- percent chance for a supplier slot (relative weights; need not sum to 100)
	Animated: boolean?,
}

local RarityConfig = {}

RarityConfig.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret" } :: { Types.Rarity }

RarityConfig.Info = {
	Common = { Rank = 1, Color = Color3.fromRGB(160, 160, 168), Weight = 45 },
	Uncommon = { Rank = 2, Color = Color3.fromRGB(86, 204, 100), Weight = 27 },
	Rare = { Rank = 3, Color = Color3.fromRGB(64, 140, 255), Weight = 16 },
	Epic = { Rank = 4, Color = Color3.fromRGB(165, 82, 235), Weight = 8 },
	Legendary = { Rank = 5, Color = Color3.fromRGB(255, 196, 40), Weight = 3 },
	Mythical = { Rank = 6, Color = Color3.fromRGB(235, 55, 60), Weight = 0.9 },
	Secret = { Rank = 7, Color = Color3.fromRGB(255, 255, 255), Weight = 0.1, Animated = true },
} :: { [string]: RarityInfo }

function RarityConfig.IsValid(rarity: string): boolean
	return RarityConfig.Info[rarity] ~= nil
end

function RarityConfig.GetRank(rarity: string): number
	local info = RarityConfig.Info[rarity]
	return if info then info.Rank else 0
end

-- Pass os.clock() as `t` so the Secret rarity cycles through the rainbow.
function RarityConfig.GetColor(rarity: string, t: number?): Color3
	local info = RarityConfig.Info[rarity]
	if not info then
		return Color3.new(1, 1, 1)
	end
	if info.Animated then
		return Color3.fromHSV(((t or 0) * 0.25) % 1, 0.75, 1)
	end
	return info.Color
end

-- Weighted pick used by the supplier (Phase 2). `rng` is a Random object.
function RarityConfig.Roll(rng: Random, allowed: { [string]: boolean }?): Types.Rarity
	local total = 0
	for _, name in RarityConfig.Order do
		if not allowed or allowed[name] then
			total += RarityConfig.Info[name].Weight
		end
	end
	local pick = rng:NextNumber() * total
	for _, name in RarityConfig.Order do
		if not allowed or allowed[name] then
			pick -= RarityConfig.Info[name].Weight
			if pick <= 0 then
				return name
			end
		end
	end
	return "Common"
end

return RarityConfig
