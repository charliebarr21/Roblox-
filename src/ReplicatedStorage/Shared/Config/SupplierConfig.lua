--!strict
-- SupplierConfig (ModuleScript). Added to the suggested architecture so supplier unlocks live in one place.
-- Fireworks reference these ids through FireworkConfig.Supplier.

export type Supplier = {
	Id: string,
	Name: string,
	UnlockStage: number, -- BuildingConfig stage required
	Order: number,
}

local LIST: { Supplier } = {
	{ Id = "LocalWholesale", Name = "Local Wholesale", UnlockStage = 1, Order = 1 },
	{ Id = "RegionalDistributor", Name = "Regional Distributor", UnlockStage = 3, Order = 2 },
	{ Id = "PremiumImports", Name = "Premium Imports", UnlockStage = 4, Order = 3 },
	{ Id = "EliteFireworks", Name = "Elite Fireworks", UnlockStage = 6, Order = 4 },
	{ Id = "GalacticSupplier", Name = "Galactic Supplier", UnlockStage = 8, Order = 5 },
}

local byId: { [string]: Supplier } = {}
for _, s in LIST do
	byId[s.Id] = s
end

local SupplierConfig = {}
SupplierConfig.List = LIST

function SupplierConfig.Get(id: string): Supplier?
	return byId[id]
end

function SupplierConfig.IsUnlocked(id: string, businessStage: number): boolean
	local s = byId[id]
	return s ~= nil and businessStage >= s.UnlockStage
end

return SupplierConfig
