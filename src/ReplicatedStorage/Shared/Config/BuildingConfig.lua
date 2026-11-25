--!strict
-- BuildingConfig (ModuleScript). The ten business stages. Costs are initial balancing targets.
-- `Implemented` marks stages that have a built model/mechanics yet (MVP = stages 1-3).

export type Stage = {
	Level: number,
	Id: string,
	Name: string,
	Cost: number,
	ShelfSlots: number,
	EmployeeSlots: number,
	CustomerCap: number, -- max simultaneous customer NPCs
	Features: { string }, -- new mechanics unlocked at this stage
	Implemented: boolean,
}

local STAGES: { Stage } = {
	{ Level = 1, Id = "roadside_tent", Name = "Roadside Tent", Cost = 0, ShelfSlots = 1, EmployeeSlots = 0, CustomerCap = 2, Features = { "Manual checkout", "Starter launch pad" }, Implemented = true },
	{ Level = 2, Id = "upgraded_stand", Name = "Upgraded Stand", Cost = 500, ShelfSlots = 2, EmployeeSlots = 1, CustomerCap = 3, Features = { "Second shelf", "First employee slot" }, Implemented = false },
	{ Level = 3, Id = "firework_shack", Name = "Firework Shack", Cost = 2500, ShelfSlots = 4, EmployeeSlots = 2, CustomerCap = 4, Features = { "Regional Distributor", "Faster delivery truck", "Rare fireworks" }, Implemented = false },
	{ Level = 4, Id = "small_store", Name = "Small Firework Store", Cost = 10000, ShelfSlots = 6, EmployeeSlots = 3, CustomerCap = 6, Features = { "Premium Imports", "Shelf stockers" }, Implemented = false },
	{ Level = 5, Id = "outlet", Name = "Firework Outlet", Cost = 50000, ShelfSlots = 8, EmployeeSlots = 4, CustomerCap = 8, Features = { "Firework show creator", "Multiple simultaneous orders" }, Implemented = false },
	{ Level = 6, Id = "superstore", Name = "Firework Superstore", Cost = 250000, ShelfSlots = 12, EmployeeSlots = 6, CustomerCap = 10, Features = { "Elite Fireworks", "Self-checkout stations" }, Implemented = false },
	{ Level = 7, Id = "warehouse", Name = "Firework Warehouse", Cost = 1000000, ShelfSlots = 16, EmployeeSlots = 8, CustomerCap = 12, Features = { "Warehouse storage", "Pallet racks" }, Implemented = false },
	{ Level = 8, Id = "distribution_center", Name = "Firework Distribution Center", Cost = 5000000, ShelfSlots = 20, EmployeeSlots = 10, CustomerCap = 14, Features = { "Galactic Supplier", "Automatic unloading" }, Implemented = false },
	{ Level = 9, Id = "megastore", Name = "Firework Megastore", Cost = 25000000, ShelfSlots = 28, EmployeeSlots = 12, CustomerCap = 16, Features = { "Legendary display cases", "Bulk orders" }, Implemented = false },
	{ Level = 10, Id = "empire", Name = "Firework Empire", Cost = 100000000, ShelfSlots = 36, EmployeeSlots = 16, CustomerCap = 20, Features = { "Prestige unlocked" }, Implemented = false },
}

local BuildingConfig = {}

BuildingConfig.Stages = STAGES
BuildingConfig.MaxStage = #STAGES
BuildingConfig.PlotSize = 70 -- studs; must match MapBuilder

function BuildingConfig.Get(level: number): Stage
	return STAGES[math.clamp(math.floor(level), 1, #STAGES)]
end

function BuildingConfig.Next(level: number): Stage?
	return STAGES[level + 1]
end

return BuildingConfig
