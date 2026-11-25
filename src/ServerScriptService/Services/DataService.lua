-- DataService (ModuleScript, server only)
--
-- Persistent player data with:
--   * session locking (a record can only be owned by one server at a time; locks expire if a server crashes)
--   * UpdateAsync everywhere (no blind SetAsync overwrites)
--   * retry with backoff on load and save
--   * data versioning + migrations + default reconciliation
--   * autosave, save-on-leave, save-on-shutdown (BindToClose)
--   * NEVER substituting defaults when a load fails: the player is kicked instead.
--     (Studio-only exception: an "ephemeral" profile that is never written, so you can test without API access.)
--
-- Stored record shape in the DataStore:  { Lock = { JobId, Time }, Data = <PlayerData> }

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Utilities.Signal)
local EconomyConfig = require(Shared.Config.EconomyConfig)

local STORE_NAME = "RunAFireworkStand_PlayerData_v1"
local KEY_PREFIX = "Player_"
local SCHEMA_VERSION = 1

local AUTOSAVE_INTERVAL = 60
local LOCK_TIMEOUT = 180 -- seconds; must stay > 2x AUTOSAVE_INTERVAL
local LOAD_ATTEMPTS = if RunService:IsStudio() then 1 else 5
local SAVE_ATTEMPTS = 5

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, data)

-- GetDataStore itself throws in an unpublished place, so guard it. If it fails, every load reports "error":
-- Studio then falls back to a temporary profile and live servers kick (live servers are always published).
local storeOk, storeOrError = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
local store: DataStore? = if storeOk then storeOrError else nil
local storeError = if storeOk then "" else tostring(storeOrError)
if not storeOk then
	warn("[DataService] DataStore unavailable: " .. storeError)
end

type Profile = {
	Player: Player,
	UserId: number,
	Data: any,
	Ephemeral: boolean,
	Saving: boolean,
	Releasing: boolean,
}

local Profiles: { [Player]: Profile } = {}
local Waiters: { [Player]: { thread } } = {}
local ReleasingHandlers: { (Player, any) -> () } = {}

---------------------------------------------------------------------
-- Template, migration, reconcile
---------------------------------------------------------------------

local function buildTemplate()
	return {
		Version = SCHEMA_VERSION,
		Cash = EconomyConfig.StartingCash,
		XP = 0,
		Level = 1,
		BusinessStage = 1,
		BusinessName = "",
		Inventory = {}, -- [fireworkId] = count
		ShelfInventory = {},
		PlacedObjects = {},
		Employees = {},
		EmployeeUpgrades = {},
		Collection = { Discovered = {}, Purchased = {}, Launched = {} },
		Reputation = 0,
		Quests = {},
		Achievements = {},
		Prestige = { Count = 0, Points = 0 },
		Settings = {
			ReducedFlash = false,
			ReducedParticles = false,
			MusicVolume = 0.5,
			SfxVolume = 0.8,
			FireworkVolume = 1,
		},
		Entitlements = {},
		ProcessedReceipts = {}, -- developer product PurchaseIds (idempotency, Phase 7)
		Stats = {
			LifetimeEarnings = 0,
			LifetimeSpent = 0,
			FireworksSold = 0,
			FireworksLaunched = 0,
			CustomersServed = 0,
			Sessions = 0,
		},
		Tutorial = { Completed = false, Step = 0 },
		FirstJoin = 0,
		LastLogout = 0,
	}
end

-- Migrations[n] upgrades data from version n to n + 1. Add a function here whenever SCHEMA_VERSION increases.
local Migrations: { [number]: (any) -> () } = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds any keys missing from `data` (recursively). Never removes or overwrites existing values.
local function reconcile(data: any, template: any)
	for key, templateValue in template do
		if data[key] == nil then
			data[key] = deepCopy(templateValue)
		elseif type(data[key]) == "table" and type(templateValue) == "table" then
			reconcile(data[key], templateValue)
		end
	end
end

local function prepareData(storedData: any): (any, boolean)
	if storedData == nil then
		local fresh = buildTemplate()
		fresh.FirstJoin = os.time()
		return fresh, true
	end
	if type(storedData) ~= "table" or type(storedData.Version) ~= "number" then
		error("stored data is malformed")
	end
	if storedData.Version > SCHEMA_VERSION then
		error("stored data is from a newer version of the game")
	end
	while storedData.Version < SCHEMA_VERSION do
		local migrate = Migrations[storedData.Version]
		if not migrate then
			error("missing migration from version " .. storedData.Version)
		end
		migrate(storedData)
		storedData.Version += 1
	end
	reconcile(storedData, buildTemplate())
	return storedData, false
end

---------------------------------------------------------------------
-- DataStore access
---------------------------------------------------------------------

-- Returns "ok", record | "locked" | "error", message
local function claimRecord(userId: number): (string, any)
	if not store then
		return "error", storeError
	end
	local key = KEY_PREFIX .. userId
	local lastFailure = "error"
	local lastMessage = ""
	for attempt = 1, LOAD_ATTEMPTS do
		local claimed = false
		local claimedRecord: any = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				claimed, claimedRecord = false, nil
				if type(old) == "table" and type(old.Lock) == "table" then
					local lockedByOther = old.Lock.JobId ~= game.JobId
					local fresh = os.time() - (old.Lock.Time or 0) < LOCK_TIMEOUT
					if lockedByOther and fresh then
						return nil -- cancel: another server owns this record
					end
				end
				local record = if type(old) == "table" then old else {}
				record.Lock = { JobId = game.JobId, Time = os.time() }
				claimed, claimedRecord = true, record
				return record
			end)
		end)
		if ok then
			if claimed then
				return "ok", claimedRecord
			end
			lastFailure, lastMessage = "locked", "record locked by another server"
		else
			lastFailure, lastMessage = "error", tostring(err)
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(attempt * 3)
		end
	end
	return lastFailure, lastMessage
end

-- Writes `data` if we still own the lock. Returns success, lostLock.
local function writeRecord(userId: number, data: any, releasing: boolean): (boolean, boolean)
	local key = KEY_PREFIX .. userId
	local snapshot = deepCopy(data) -- copy now; the live table keeps changing while we yield
	local lostLock = false
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				lostLock = false
				if type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId ~= game.JobId then
					lostLock = true
					return nil -- another server took over; do not overwrite its data
				end
				local record = if type(old) == "table" then old else {}
				record.Data = snapshot
				if releasing then
					record.Lock = nil
				else
					record.Lock = { JobId = game.JobId, Time = os.time() }
				end
				return record
			end)
		end)
		if ok then
			return not lostLock, lostLock
		end
		warn(("[DataService] Save attempt %d failed for %d: %s"):format(attempt, userId, tostring(err)))
		task.wait(attempt * 2)
	end
	return false, false
end

-- Releases our lock without touching stored data (used when the player left mid-load or data was unusable).
local function releaseLockOnly(userId: number)
	pcall(function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(old)
			if type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId == game.JobId then
				old.Lock = nil
				return old
			end
			return nil
		end)
	end)
end

---------------------------------------------------------------------
-- Waiters
---------------------------------------------------------------------

local function wake(player: Player, data: any)
	local list = Waiters[player]
	if not list then
		return
	end
	Waiters[player] = nil
	for _, thread in list do
		task.spawn(thread, data)
	end
end

---------------------------------------------------------------------
-- Profile lifecycle
---------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local userId = player.UserId
	local status, record = claimRecord(userId)

	if not player:IsDescendantOf(Players) then
		if status == "ok" then
			releaseLockOnly(userId)
		end
		wake(player, nil)
		return
	end

	local data: any = nil
	local ephemeral = false

	if status == "ok" then
		local prepared, result = pcall(prepareData, record.Data)
		if prepared then
			data = result
		else
			warn(("[DataService] Could not prepare data for %d: %s"):format(userId, tostring(result)))
			releaseLockOnly(userId)
			status = "error"
		end
	end

	if data == nil then
		if RunService:IsStudio() then
			warn("[DataService] Studio fallback: using TEMPORARY data (not saved). Enable API Services + publish the place to test saving.")
			data = buildTemplate()
			data.FirstJoin = os.time()
			ephemeral = true
		else
			player:Kick("We couldn't load your save safely, so we stopped you from joining to protect your progress. Please rejoin in a minute.")
			wake(player, nil)
			return
		end
	end

	local profile: Profile = {
		Player = player,
		UserId = userId,
		Data = data,
		Ephemeral = ephemeral,
		Saving = false,
		Releasing = false,
	}
	Profiles[player] = profile
	wake(player, data)
	DataService.ProfileLoaded:Fire(player, data)
end

local function saveProfile(profile: Profile, releasing: boolean): boolean
	if profile.Ephemeral then
		return true
	end
	while profile.Saving do
		task.wait()
	end
	profile.Saving = true
	local ok, lostLock = writeRecord(profile.UserId, profile.Data, releasing)
	profile.Saving = false
	if lostLock and not releasing and profile.Player.Parent then
		profile.Player:Kick("Your session was opened on another server. Please rejoin.")
	end
	return ok
end

local function releaseProfile(player: Player)
	local profile = Profiles[player]
	if not profile then
		wake(player, nil)
		return
	end
	if profile.Releasing then
		-- another path (PlayerRemoving / BindToClose) is already saving; wait for it to finish
		while Profiles[player] == profile do
			task.wait()
		end
		return
	end
	profile.Releasing = true
	for _, handler in ReleasingHandlers do
		local ok, err = pcall(handler, player, profile.Data)
		if not ok then
			warn("[DataService] Releasing handler error: " .. tostring(err))
		end
	end
	profile.Data.LastLogout = os.time()
	saveProfile(profile, true)
	Profiles[player] = nil
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------

function DataService.GetData(player: Player): any
	local profile = Profiles[player]
	return if profile and not profile.Releasing then profile.Data else nil
end

-- Yields until the player's data is loaded. Returns nil if they left or were kicked.
function DataService.WaitForData(player: Player): any
	local existing = DataService.GetData(player)
	if existing then
		return existing
	end
	if not player:IsDescendantOf(Players) then
		return nil
	end
	local list = Waiters[player]
	if not list then
		list = {}
		Waiters[player] = list
	end
	table.insert(list, coroutine.running())
	return coroutine.yield()
end

function DataService.IsEphemeral(player: Player): boolean
	local profile = Profiles[player]
	return profile ~= nil and profile.Ephemeral
end

-- Register a callback that runs synchronously right before the final save (set timestamps, flush counters).
function DataService.OnReleasing(handler: (Player, any) -> ())
	table.insert(ReleasingHandlers, handler)
end

-- Immediate save, e.g. after a Robux purchase. Autosave handles everything else.
function DataService.Save(player: Player): boolean
	local profile = Profiles[player]
	if not profile or profile.Releasing then
		return false
	end
	return saveProfile(profile, false)
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		releaseProfile(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, profile in Profiles do
				if not profile.Releasing and not profile.Saving then
					task.spawn(saveProfile, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in Profiles do
			pending += 1
			task.spawn(function()
				releaseProfile(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

return DataService
