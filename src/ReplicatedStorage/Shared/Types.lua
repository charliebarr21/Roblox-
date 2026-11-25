--!strict
-- Shared type definitions (ModuleScript). Types only; nothing to require at runtime.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythical" | "Secret"

export type FireworkDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Rarity: Rarity,
	WholesaleCost: number,
	RetailPrice: number, -- recommended retail price
	SupplierStock: { Min: number, Max: number }, -- quantity range per restock
	Supplier: string, -- SupplierConfig id
	UnlockLevel: number, -- business stage required (BuildingConfig)
	Demand: number, -- base customer demand multiplier (1 = average)
	Model: string, -- name of the inventory model in ServerStorage.FireworkModels
	Effect: string, -- id looked up by the Phase 3 FireworkEffects module
	XPReward: number,
}

export type PlayerStats = {
	LifetimeEarnings: number,
	LifetimeSpent: number,
	FireworksSold: number,
	FireworksLaunched: number,
	CustomersServed: number,
	Sessions: number,
}

export type PlayerData = {
	Version: number,
	Cash: number,
	XP: number,
	Level: number,
	BusinessStage: number,
	BusinessName: string,
	Inventory: { [string]: number },
	ShelfInventory: { [string]: any },
	PlacedObjects: { any },
	Employees: { [string]: any },
	EmployeeUpgrades: { [string]: number },
	Collection: {
		Discovered: { [string]: boolean },
		Purchased: { [string]: boolean },
		Launched: { [string]: boolean },
	},
	Reputation: number,
	Quests: { [string]: any },
	Achievements: { [string]: boolean },
	Prestige: { Count: number, Points: number },
	Settings: { [string]: any },
	Entitlements: { [string]: boolean },
	ProcessedReceipts: { [string]: boolean },
	Stats: PlayerStats,
	Tutorial: { Completed: boolean, Step: number },
	FirstJoin: number,
	LastLogout: number,
}

return {}
