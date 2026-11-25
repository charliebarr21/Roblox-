# Run a Firework Stand! — Phase 1: Foundation

**Status: written but NOT run in Roblox Studio.** I have no Studio access, so nothing here has been executed or playtested. I checked syntax structure (brackets, strings, block balance) and that the installer reproduces every file exactly, but Luau type-checking and runtime behaviour are untested. Expect a small number of first-run issues; send me the Output window text and I will fix them before Phase 2.

**Review fixes (applied after a code read-through, still not run in Studio):**
- `DataService`: `GetDataStore` is now guarded. In an unpublished place it throws, which used to stop DataService from loading. Every other service requires DataService, so the whole server failed to start. It now falls back to temporary Studio data as intended.
- `ServerMain`: prints an error count instead of "server ready" when a service fails. In Studio it adds `ServerStorage.DebugEconomy` for test step 5, because requiring modules from the command bar gives a separate, empty copy.
- `PlotService`: waits a moment before moving a freshly spawned character, so the engine's spawn placement can't override the move to your plot.

---

## 1. Spec review: dependencies and design problems

**Hard dependencies**
- DataStores need a **published place** and **Studio Access to API Services** enabled to test saving in Studio.
- Game Settings > **Max Players = 6** (one plot per player; a 7th player is kicked with a "server full" message).
- Delete the template **Baseplate** and **SpawnLocation** (they overlap the generated map; the server warns if they exist).
- Later phases need: audio assets (Phase 7), a published place with gamepass/product IDs (Phase 7), and Roblox **TextService** filtering for business names (Phase 4).

**Design problems found (and what I did about them)**
1. **Pacing vs. starting economy.** Tiny Spark nets $4. With $100 start cash, 2–3 simultaneous customers and ~2 items per customer, income is roughly $1/s, so the $500 Upgraded Stand takes ~8+ minutes, not the 3–5 minute target. Levers: lower stage 2 cost (~$250–300), larger starting stock, higher early customer arrival rate, or higher early margins. All are config values. I will build a quick economy simulator in Phase 2 before locking numbers.
2. **"Unlock level" was ambiguous.** I split it: `UnlockLevel` on a firework = **business stage** required; the XP **level** is separate (HUD shows both). Phase 4 decides what XP levels unlock (bonuses, quest tiers).
3. **Supplier rarity luck vs. "progression must not depend on luck".** Plan: per-**player** supplier stock generated from a seeded RNG (`userId + restock window`), so nothing needs storing and players never fight over stock. Staple commons/uncommons are always listed; rarity weights only decide the extra "featured" slots. With ~8 slots per restock, a 0.1% Secret appears roughly once per ~10 hours of play.
4. **Customer NPC load.** Stage 10 allows 20 customers x 6 players = 120 NPCs. Per-NPC `PathfindingService` on the server will not scale. Plan: customers are an abstract server-side state machine moving along **fixed waypoints** on each plot (layouts are known), with a hard cap per plot; visuals are tweened. Decided in Phase 2.
5. **Firework launches** must be visible to everyone nearby but cost the server nothing: server validates ownership and consumes the item, then tells clients within ~400 studs to play the effect (Phase 3). Reduced-flash/particle settings are already in the save template.
6. **Developer-product receipts** need an idempotency record. `ProcessedReceipts` is in the save template; it will be pruned to the most recent ~200 IDs in Phase 7.
7. **Leaderboards and store likes** across servers need OrderedDataStores with throttled writes (Phase 6). Visiting/comparing is in-server only at first.
8. **Late-game scale.** Cosmic Apocalypse nets $150k, so $100M stage 10 means hundreds of top sales: income must come from volume/automation/prestige multipliers, not single sales. Revisit in Phase 8 balancing.
9. **StreamingEnabled** is left **off** for now: the map is built at runtime and needs a streaming pass. Revisit in Phase 7.
10. **Naming clash:** Roblox already has a built-in service called `AnalyticsService`. I will name ours `TelemetryService` in Phase 7.

**Changes to the suggested architecture** (minor)
- Added `Security` (rate limiting, validation, flagging), `StateService` (batched state to HUD), `Builders/` (placeholder map and stand), `SupplierConfig`, `Utilities/RemoteRegistry`, `Utilities/Signal`.
- `Types` is a ModuleScript. The HUD is built **in code** by `UIController` (no StarterGui assets), so installs are one step and layout scales with `UIScale`.
- `EmployeeConfig`, `QuestConfig`, `EventConfig` are not created yet; they arrive with their phases.

---

## 2. What Phase 1 contains

| Area | Script | Type |
|---|---|---|
| Rarity colours + weights | `ReplicatedStorage/Shared/Config/RarityConfig` | ModuleScript |
| 18 fictional fireworks, auto-registers content packs | `.../Config/FireworkConfig` | ModuleScript |
| Cash/XP/pacing numbers | `.../Config/EconomyConfig` | ModuleScript |
| 10 business stages | `.../Config/BuildingConfig` | ModuleScript |
| 5 suppliers + unlock stages | `.../Config/SupplierConfig` | ModuleScript |
| Shared types | `ReplicatedStorage/Shared/Types` | ModuleScript |
| Signal, Format, RemoteRegistry | `ReplicatedStorage/Shared/Utilities/*` | ModuleScripts |
| Rate limit + validation | `ServerScriptService/Security` | ModuleScript |
| Saving: session lock, retries, migration, reconcile, autosave, shutdown save | `ServerScriptService/Services/DataService` | ModuleScript |
| HUD state replication (batched) | `.../Services/StateService` | ModuleScript |
| Cash and XP (server-authoritative) | `.../Services/EconomyService` | ModuleScript |
| Plot assignment, stand build, spawn | `.../Services/PlotService` | ModuleScript |
| Placeholder town and tent | `.../Builders/MapBuilder`, `StandBuilder`, `BuildUtil` | ModuleScripts |
| Boot order | `ServerScriptService/ServerMain` | **Script** |
| Client boot | `StarterPlayer/StarterPlayerScripts/ClientMain` | **LocalScript** |
| HUD + state mirror | `.../Controllers/UIController`, `StateController` | ModuleScripts |

Data safety rules implemented: a failed or locked load **kicks** the player instead of loading defaults; saves use `UpdateAsync` and refuse to overwrite if another server took the lock; data from a newer schema version is never loaded. (Studio-only: if the DataStore is unreachable you get a clearly warned, never-saved temporary profile so you can still test.)

---

## 3. Install (pick one)

**A. One-paste installer (easiest)**
1. In Studio, open an empty Baseplate place, delete **Baseplate** and **SpawnLocation**.
2. Open **View > Command Bar**, paste the entire contents of `Install_Phase1.lua`, press Enter. It creates every folder and script in the right place (re-running updates them).
3. Check the Output window for `[Installer] Installed or updated 21 scripts`.

**B. Rojo:** unzip, run `rojo serve` in the folder (uses `default.project.json`), connect from Studio.

**C. Manual:** recreate the tree below and paste each file from `src/`. Class is **Script** for `*.server.lua`, **LocalScript** for `*.client.lua`, otherwise **ModuleScript**.

```
ReplicatedStorage
  Shared
    Types
    Config: RarityConfig, FireworkConfig, EconomyConfig, BuildingConfig, SupplierConfig
    Utilities: Signal, Format, RemoteRegistry
  Remotes (Folder, filled at runtime)
  Assets (Folder)
ServerScriptService
  ServerMain (Script)
  Security
  Services: DataService, StateService, EconomyService, PlotService
  Builders: BuildUtil, MapBuilder, StandBuilder
ServerStorage: BuildingModels, FireworkModels, CustomerModels, EmployeeModels, DeliveryModels (Folders)
StarterPlayer > StarterPlayerScripts
  ClientMain (LocalScript)
  Controllers: StateController, UIController
```

**Studio settings:** Game Settings > Security > *Enable Studio Access to API Services*; Game Settings > Players > *Max Players 6*. Publish the place to test saving.

---

## 4. Test plan and expected results

1. **Boot.** Press Play. Output shows `[ServerMain] Run a Firework Stand - Phase 1 server ready`, no red errors. If the place is unpublished or API access is off, you will instead see `[DataService] DataStore unavailable` and the "TEMPORARY data" warning; that is expected, everything else still works but nothing saves. If any service fails to load, the last line is `[ServerMain] Phase 1 server started with N error(s)` instead.
2. **World.** Hub with red "WHOLESALE" building, six grass plots in a ring, roads, leaderboard/arena/event placeholders, trees.
3. **Your plot.** You spawn facing a small red-and-white tent with a counter, one wooden shelf, an "ORDER" computer, a yellow DELIVERIES pad, a LAUNCH AREA pad, and a roadside sign reading "<YourName>'s Firework Stand". Unused plots say FOR SALE.
4. **HUD.** Top left: **$100**, "Business Lv 1 · Roadside Tent", XP bar "Lv 1 · 0 / 40 XP". A welcome toast appears. Left buttons show "opens in Phase N" toasts. Right panel shows placeholders.
5. **Server-authoritative money.** In the command bar, switch to the **Server** context (Test tab) and run the lines below. (Don't `require` the services from the command bar: it keeps its own module cache, so you'd get an empty copy and every call returns `false`. `DebugEconomy` exists only in Studio.)
```lua
local D, p = game.ServerStorage.DebugEconomy, game.Players:GetPlayers()[1]
print(D:Invoke("AddCash", p, 250))      -- true, HUD counts up to $350 with a green flash
print(D:Invoke("TrySpend", p, 1000000)) -- false, cash unchanged
print(D:Invoke("TrySpend", p, 50))      -- true, red flash, $300
print(D:Invoke("AddXP", p, 100))        -- true, "Level up!" toast, bar shows Lv 2 · 60 / 117 XP
```
6. **Config.** `print(#require(game.ReplicatedStorage.Shared.Config.FireworkConfig).GetAll())` prints `18`, with no `[FireworkConfig] Skipped` warnings.
7. **Saving (published place, API on).** Add cash as above, stop the test, play again: cash/XP persist. Stop and replay several times quickly: no "locked" kick.
8. **Multiplayer.** Test > Clients and Servers, 3–6 players: each gets a different plot and a correct sign; when someone leaves their plot returns to FOR SALE.
9. **Mobile.** Use the Studio device emulator (a phone profile): HUD scales, nothing overlaps the top bar.

## 5. Phase 2 preview
Supplier UI (per-player seeded stock, 5-minute restock), server-validated purchases, delivery truck and boxes, shelf stocking, abstract customer state machine on fixed waypoints, manual checkout, profit tracking, and an economy simulator to tune the pacing issue above. I will not start it until Phase 1 runs clean on your side.
