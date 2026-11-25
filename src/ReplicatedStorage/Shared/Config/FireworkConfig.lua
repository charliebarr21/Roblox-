--!strict
-- FireworkConfig (ModuleScript). Single source of truth for every sellable firework.
--
-- ADDING CONTENT WITHOUT EDITING THIS FILE:
--   Put a ModuleScript *inside* this ModuleScript that returns an array of FireworkDef tables
--   (use the same field names as below). They are registered automatically on require.
--
-- Collection status (discovered / purchased / launched) is PLAYER state, stored in PlayerData.Collection.
-- `Effect` is only an id here; Phase 3's FireworkEffects module owns the visuals for each id.

local Types = require(script.Parent.Parent.Types)
local RarityConfig = require(script.Parent.RarityConfig)

local FireworkConfig = {}

-- fw(id, name, description, rarity, wholesale, retail, stockMin, stockMax, supplier, unlockStage, demand, xp)
local function fw(
	id: string,
	name: string,
	desc: string,
	rarity: Types.Rarity,
	cost: number,
	retail: number,
	stockMin: number,
	stockMax: number,
	supplier: string,
	unlock: number,
	demand: number,
	xp: number
): Types.FireworkDef
	return {
		Id = id,
		DisplayName = name,
		Description = desc,
		Rarity = rarity,
		WholesaleCost = cost,
		RetailPrice = retail,
		SupplierStock = { Min = stockMin, Max = stockMax },
		Supplier = supplier,
		UnlockLevel = unlock,
		Demand = demand,
		Model = id,
		Effect = id,
		XPReward = xp,
	}
end

local LW, RD, PI, EF, GS = "LocalWholesale", "RegionalDistributor", "PremiumImports", "EliteFireworks", "GalacticSupplier"

local BASE: { Types.FireworkDef } = {
	-- Common
	fw("tiny_spark", "Tiny Spark", "A cheerful little fizz of silver sparks.", "Common", 5, 9, 40, 80, LW, 1, 1.0, 3),
	fw("candy_crackle", "Candy Crackle", "Pastel pops that crackle like sugar.", "Common", 8, 15, 30, 60, LW, 1, 1.0, 4),
	fw("golden_fountain", "Golden Fountain", "A warm fountain of golden glitter.", "Common", 12, 22, 30, 60, LW, 1, 1.0, 5),
	fw("rainbow_pop", "Rainbow Pop", "Seven colours, one happy bang.", "Common", 20, 36, 25, 50, LW, 2, 0.95, 6),
	-- Uncommon
	fw("thunder_burst", "Thunder Burst", "A booming blue-white burst.", "Uncommon", 40, 72, 15, 35, LW, 2, 0.9, 12),
	fw("starlight_twirl", "Starlight Twirl", "Stars spiral up and twinkle out.", "Uncommon", 55, 100, 12, 30, LW, 2, 0.9, 14),
	fw("neon_dragon", "Neon Dragon", "A glowing dragon coils across the sky.", "Uncommon", 75, 135, 10, 25, LW, 3, 0.85, 16),
	-- Rare
	fw("heartbeat_bloom", "Heartbeat Bloom", "Pulsing pink hearts in the dark.", "Rare", 200, 380, 6, 14, RD, 3, 0.75, 38),
	fw("galaxy_bloom", "Galaxy Bloom", "A spinning galaxy of violet and gold.", "Rare", 150, 285, 6, 16, RD, 3, 0.75, 30),
	fw("solar_storm", "Solar Storm", "Fiery rings roll out like a sun flare.", "Rare", 300, 570, 5, 12, RD, 4, 0.7, 50),
	-- Epic
	fw("phantom_sky", "Phantom Sky", "Ghostly lights drift and fade.", "Epic", 750, 1500, 3, 8, PI, 4, 0.55, 100),
	fw("aurora_cascade", "Aurora Cascade", "Curtains of green and violet fall slowly.", "Epic", 1100, 2200, 2, 7, PI, 5, 0.55, 125),
	fw("midnight_dragon", "Midnight Dragon", "A huge shadow dragon breathes silver fire.", "Epic", 1500, 3000, 2, 6, PI, 5, 0.5, 160),
	-- Legendary
	fw("celestial_crown", "Celestial Crown", "A royal crown of light above the crowd.", "Legendary", 5000, 11000, 1, 4, EF, 6, 0.35, 400),
	fw("golden_waterfall", "Golden Waterfall", "A thundering cascade of liquid gold.", "Legendary", 8000, 17500, 1, 3, EF, 7, 0.3, 550),
	-- Mythical
	fw("supernova", "Supernova", "The sky erupts in a star-sized flash.", "Mythical", 25000, 60000, 1, 2, GS, 8, 0.2, 1500),
	fw("planet_parade", "Planet Parade", "Ringed planets march across the horizon.", "Mythical", 40000, 95000, 1, 2, GS, 9, 0.18, 2000),
	-- Secret
	fw("cosmic_apocalypse", "Cosmic Apocalypse", "Nobody is sure what it does. Everybody watches.", "Secret", 100000, 250000, 1, 1, GS, 10, 0.1, 6000),
}

local registry: { [string]: Types.FireworkDef } = {}
local ordered: { Types.FireworkDef } = {}

local function validate(def: any): string?
	if type(def) ~= "table" then
		return "entry is not a table"
	end
	if type(def.Id) ~= "string" or def.Id == "" then
		return "missing Id"
	end
	if registry[def.Id] then
		return "duplicate Id " .. def.Id
	end
	if type(def.DisplayName) ~= "string" then
		return "missing DisplayName"
	end
	if type(def.Rarity) ~= "string" or not RarityConfig.IsValid(def.Rarity) then
		return "invalid Rarity"
	end
	if type(def.WholesaleCost) ~= "number" or def.WholesaleCost <= 0 then
		return "invalid WholesaleCost"
	end
	if type(def.RetailPrice) ~= "number" or def.RetailPrice <= def.WholesaleCost then
		return "RetailPrice must be greater than WholesaleCost"
	end
	if type(def.SupplierStock) ~= "table" or type(def.SupplierStock.Min) ~= "number" or type(def.SupplierStock.Max) ~= "number" then
		return "invalid SupplierStock"
	end
	return nil
end

local function register(def: any, source: string)
	local problem = validate(def)
	if problem then
		warn(("[FireworkConfig] Skipped entry from %s: %s"):format(source, problem))
		return
	end
	registry[def.Id] = def
	table.insert(ordered, def)
end

for _, def in BASE do
	register(def, "FireworkConfig")
end

-- Auto-register content packs placed as child ModuleScripts.
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, pack = pcall(require, child)
		if ok and type(pack) == "table" then
			for _, def in pack do
				register(def, child.Name)
			end
		else
			warn("[FireworkConfig] Could not load content pack " .. child.Name)
		end
	end
end

table.sort(ordered, function(a, b)
	local ra, rb = RarityConfig.GetRank(a.Rarity), RarityConfig.GetRank(b.Rarity)
	if ra ~= rb then
		return ra < rb
	end
	return a.WholesaleCost < b.WholesaleCost
end)

function FireworkConfig.Get(id: string): Types.FireworkDef?
	return registry[id]
end

function FireworkConfig.GetAll(): { Types.FireworkDef }
	return ordered
end

function FireworkConfig.Count(): number
	return #ordered
end

function FireworkConfig.GetByRarity(rarity: Types.Rarity): { Types.FireworkDef }
	local list = {}
	for _, def in ordered do
		if def.Rarity == rarity then
			table.insert(list, def)
		end
	end
	return list
end

function FireworkConfig.GetBySupplier(supplierId: string): { Types.FireworkDef }
	local list = {}
	for _, def in ordered do
		if def.Supplier == supplierId then
			table.insert(list, def)
		end
	end
	return list
end

return FireworkConfig
