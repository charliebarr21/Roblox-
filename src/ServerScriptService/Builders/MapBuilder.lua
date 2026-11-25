-- MapBuilder (ModuleScript, server only)
-- Builds a placeholder low-poly town at runtime if Workspace.PlayerPlots does not exist yet:
-- ground, central wholesale supplier, six plots on a ring, roads, leaderboard plaza, public arena, event area, trees.
--
-- To use your own hand-built map instead: create Workspace.PlayerPlots containing models named Plot_1..Plot_6.
-- Each model needs a Part called "Base" (front of the plot = the Base's -Z side) and optionally a Part
-- called "OwnerSign" with a SurfaceGui > TextLabel. MapBuilder will then skip generation.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local BuildUtil = require(script.Parent.BuildUtil)

local MapBuilder = {}

local PLOT_COUNT = 6
local RING_RADIUS = 150
local PLOT_SIZE = 70
local SURFACE_Y = 0.4 -- top of plots and plazas

export type PlotRecord = { Model: Model, Base: BasePart }

local GRASS = Color3.fromRGB(110, 190, 80)
local PLOT_GRASS = Color3.fromRGB(135, 205, 95)
local ROAD = Color3.fromRGB(70, 72, 80)
local CONCRETE = Color3.fromRGB(190, 190, 195)

local function newFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function collect(folder: Instance): { PlotRecord }
	local list = {}
	for _, model in folder:GetChildren() do
		local base = model:FindFirstChild("Base")
		if model:IsA("Model") and base and base:IsA("BasePart") then
			table.insert(list, { Model = model, Base = base })
		end
	end
	table.sort(list, function(a, b)
		return a.Model.Name < b.Model.Name
	end)
	return list
end

local function buildTree(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(5, 8)
	BuildUtil.Part(parent, "Trunk", Vector3.new(1.5, height, 1.5), CFrame.new(position + Vector3.new(0, height / 2, 0)), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
	local leaves = BuildUtil.Part(parent, "Leaves", Vector3.new(9, 9, 9), CFrame.new(position + Vector3.new(0, height + 3, 0)), Color3.fromRGB(70, 160, 70), Enum.Material.Grass)
	leaves.Shape = Enum.PartType.Ball
	leaves.CanCollide = false
end

local function buildSignBoard(parent: Instance, name: string, text: string, position: Vector3, facing: Vector3, size: Vector3?, color: Color3?)
	local boardSize = size or Vector3.new(24, 8, 1)
	local board = BuildUtil.Part(parent, name, boardSize, CFrame.lookAt(position, position + facing), color or Color3.fromRGB(255, 244, 214))
	-- the board's Front face looks along its -Z; lookAt points -Z at `facing`, so label the Front
	BuildUtil.Label(board, text, Enum.NormalId.Front, Color3.fromRGB(150, 40, 40))
	return board
end

local function generate(): Folder
	local map = Workspace:FindFirstChild("Map")
	if map then
		map:Destroy()
	end
	local mapFolder = newFolder("Map", Workspace)
	local plotsFolder = newFolder("PlayerPlots", Workspace)
	local roads = newFolder("Roads", mapFolder)
	local decor = newFolder("Decor", mapFolder)
	newFolder("NPCSpawnPoints", Workspace)

	local hub = Vector3.new(0, SURFACE_Y / 2, 0)

	-- Ground
	BuildUtil.Part(mapFolder, "Ground", Vector3.new(760, 2, 760), CFrame.new(0, -1, 0), GRASS, Enum.Material.Grass)

	-- Central plaza + wholesale supplier
	local plaza = BuildUtil.Part(mapFolder, "HubPlaza", Vector3.new(SURFACE_Y, 110, 110), CFrame.new(hub) * CFrame.Angles(0, 0, math.rad(90)), CONCRETE, Enum.Material.Concrete)
	plaza.Shape = Enum.PartType.Cylinder

	local supplier = Instance.new("Model")
	supplier.Name = "WholesaleSupplier"
	supplier.Parent = mapFolder
	local body = BuildUtil.Part(supplier, "Body", Vector3.new(28, 12, 22), CFrame.new(0, SURFACE_Y + 6, 0), Color3.fromRGB(215, 70, 60))
	BuildUtil.Part(supplier, "Roof", Vector3.new(30, 1.5, 24), CFrame.new(0, SURFACE_Y + 12.75, 0), Color3.fromRGB(90, 55, 45))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		BuildUtil.Label(body, "WHOLESALE", face, Color3.new(1, 1, 1))
	end

	-- Spawn pad inside the hub (players are moved to their plot once their data loads)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(-30, 0.9, -30)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 196, 61)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = mapFolder

	-- Leaderboard plaza (Phase 6 attaches the boards)
	BuildUtil.Part(mapFolder, "LeaderboardPlaza", Vector3.new(16, 0.3, 34), CFrame.new(40, SURFACE_Y + 0.15, 0), Color3.fromRGB(255, 220, 120))
	buildSignBoard(mapFolder, "LeaderboardBoard", "LEADERBOARDS", Vector3.new(47, SURFACE_Y + 6, 0), Vector3.new(-1, 0, 0), Vector3.new(30, 9, 1), Color3.fromRGB(255, 244, 214))

	-- Public arena and event area
	BuildUtil.Part(mapFolder, "PublicFireworkArena", Vector3.new(130, 0.4, 130), CFrame.new(300, 0.2, 0), Color3.fromRGB(80, 84, 100), Enum.Material.Slate)
	buildSignBoard(mapFolder, "ArenaSign", "PUBLIC FIREWORK ARENA", Vector3.new(240, 15, 0), Vector3.new(-1, 0, 0), Vector3.new(40, 8, 1))
	BuildUtil.Part(mapFolder, "EventArea", Vector3.new(100, 0.4, 100), CFrame.new(-300, 0.2, 0), Color3.fromRGB(110, 150, 230), Enum.Material.SmoothPlastic)
	buildSignBoard(mapFolder, "EventSign", "EVENT AREA", Vector3.new(-250, 15, 0), Vector3.new(1, 0, 0), Vector3.new(30, 8, 1))

	-- Roads from the hub to the arena and event area
	BuildUtil.Part(roads, "RoadEast", Vector3.new(185, 0.2, 14), CFrame.new(147.5, 0.1, 0), ROAD, Enum.Material.Asphalt)
	BuildUtil.Part(roads, "RoadWest", Vector3.new(185, 0.2, 14), CFrame.new(-147.5, 0.1, 0), ROAD, Enum.Material.Asphalt)

	-- Plots on a ring. Plot k sits at 30 + 60k degrees so roads never run along the X axis.
	for i = 1, PLOT_COUNT do
		local angle = math.rad(30 + (i - 1) * 60)
		local position = Vector3.new(math.cos(angle) * RING_RADIUS, SURFACE_Y / 2, math.sin(angle) * RING_RADIUS)
		local look = CFrame.lookAt(position, hub) -- plot -Z (its "front") faces the hub

		local model = Instance.new("Model")
		model.Name = "Plot_" .. i
		model:SetAttribute("PlotIndex", i)
		model.Parent = plotsFolder

		local base = BuildUtil.Part(model, "Base", Vector3.new(PLOT_SIZE, SURFACE_Y, PLOT_SIZE), look, PLOT_GRASS, Enum.Material.Grass)
		model.PrimaryPart = base

		-- Owner sign on the front-left corner, readable from the road
		local signPost = BuildUtil.Part(model, "OwnerSignPost", Vector3.new(0.8, 6, 0.8), look * CFrame.new(-27, 3 + SURFACE_Y / 2, -32), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
		signPost.CanCollide = true
		local sign = BuildUtil.Part(model, "OwnerSign", Vector3.new(14, 4, 0.6), look * CFrame.new(-27, 7.5, -32), Color3.fromRGB(255, 244, 214))
		BuildUtil.Label(sign, "FOR SALE", Enum.NormalId.Front, Color3.fromRGB(150, 40, 40))

		-- Road from the hub to the front of the plot
		local roadLength = RING_RADIUS - PLOT_SIZE / 2 - 50
		local mid = hub:Lerp(position, (50 + roadLength / 2) / RING_RADIUS)
		BuildUtil.Part(roads, "PlotRoad_" .. i, Vector3.new(14, 0.2, roadLength), CFrame.lookAt(Vector3.new(mid.X, 0.1, mid.Z), Vector3.new(0, 0.1, 0)), ROAD, Enum.Material.Asphalt)
	end

	-- Trees (deterministic so every server looks the same)
	local rng = Random.new(7)
	local placed = 0
	while placed < 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(205, 260)
		if math.abs(math.sin(angle)) > 0.3 then
			buildTree(decor, Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), rng)
			placed += 1
		end
	end

	return plotsFolder
end

function MapBuilder.Build(): { PlotRecord }
	for _, name in { "Baseplate", "SpawnLocation" } do
		if Workspace:FindFirstChild(name) then
			warn(("[MapBuilder] Workspace.%s exists and will overlap the generated map. Delete it."):format(name))
		end
	end

	Lighting.ClockTime = 14.5 -- day/night cycle arrives in Phase 7

	local existing = Workspace:FindFirstChild("PlayerPlots")
	local folder = if existing then existing else generate()
	local plots = collect(folder)
	if #plots == 0 then
		warn("[MapBuilder] Workspace.PlayerPlots has no valid Plot models (need a Model with a Part named 'Base').")
	end
	return plots
end

return MapBuilder
