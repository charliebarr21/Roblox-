-- PlotService (ModuleScript, server only)
-- Assigns one plot per player, builds their business on it, moves their character there, frees the plot on leave.
-- Server capacity is the number of plots; set Game Settings > Max Players to 6 so nobody is turned away.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Utilities.Signal)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.Parent.Builders.MapBuilder)
local StandBuilder = require(script.Parent.Parent.Builders.StandBuilder)

local PlotService = {}
PlotService.PlotAssigned = Signal.new() -- (player, plot)

type Plot = {
	Index: number,
	Model: Model,
	Base: BasePart,
	Owner: Player?,
	Anchors: StandBuilder.Anchors?,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function setOwnerSign(plot: Plot, text: string)
	local sign = plot.Model:FindFirstChild("OwnerSign")
	local label = sign and sign:FindFirstChild("Text", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function moveCharacter(player: Player, plot: Plot)
	local character = player.Character
	if not character or not plot.Anchors then
		return
	end
	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", 5)
	end
	-- Let the engine finish placing a freshly spawned character at the SpawnLocation first,
	-- otherwise that placement can overwrite our move.
	task.wait(0.1)
	if character.Parent and player.Character == character and plot.Anchors and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(plot.Anchors.PlayerSpawn + Vector3.new(0, 4, 0))
	end
end

local function assign(player: Player, data: any)
	if byPlayer[player] or not player.Parent then
		return
	end
	local plot: Plot? = nil
	for _, candidate in plots do
		if not candidate.Owner then
			plot = candidate
			break
		end
	end
	if not plot then
		player:Kick("This server is full. Please join another one.")
		return
	end

	plot.Owner = player
	byPlayer[player] = plot
	plot.Model:SetAttribute("OwnerUserId", player.UserId)

	local name = if data.BusinessName ~= "" then data.BusinessName else (player.DisplayName .. "'s Firework Stand")
	plot.Anchors = StandBuilder.Build(plot.Model, plot.Base, data.BusinessStage, name)
	setOwnerSign(plot, name)

	task.spawn(moveCharacter, player, plot)
	PlotService.PlotAssigned:Fire(player, plot)
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.Owner = nil
	plot.Anchors = nil
	plot.Model:SetAttribute("OwnerUserId", nil)
	local stand = plot.Model:FindFirstChild("Stand")
	if stand then
		stand:Destroy()
	end
	setOwnerSign(plot, "FOR SALE")
end

function PlotService.GetPlot(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.GetPlots(): { Plot }
	return plots
end

function PlotService.Init()
	for index, record in MapBuilder.Build() do
		table.insert(plots, { Index = index, Model = record.Model, Base = record.Base, Owner = nil, Anchors = nil })
	end

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			local plot = byPlayer[player]
			if plot then
				task.spawn(moveCharacter, player, plot)
			end
		end)
	end

	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end

	DataService.ProfileLoaded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
end

return PlotService
