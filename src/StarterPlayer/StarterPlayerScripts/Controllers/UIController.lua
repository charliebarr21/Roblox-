-- UIController (ModuleScript, client). Builds the main HUD in code (no StarterGui assets needed).
-- Layout is designed for 1280x720 and scaled with UIScale, so it fits phones, tablets, desktops and consoles.
--   Top left: cash, business stage, XP bar      Left: menu buttons (placeholders until their phase)
--   Right: restock timer / event / goal         Top centre: toast notifications

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Utilities.Format)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local StateController = require(script.Parent.StateController)

local UIController = {}

local THEME = {
	Panel = Color3.fromRGB(28, 32, 48),
	PanelLight = Color3.fromRGB(44, 50, 74),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(240, 242, 250),
	Muted = Color3.fromRGB(160, 168, 190),
	Cash = Color3.fromRGB(104, 230, 130),
	Gain = Color3.fromRGB(210, 255, 220),
	Loss = Color3.fromRGB(255, 120, 120),
	Xp = Color3.fromRGB(110, 170, 255),
	Accent = Color3.fromRGB(255, 196, 61),
}

local function make(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function outline(parent: Instance, transparency: number)
	make("UIStroke", { Color = THEME.Stroke, Transparency = transparency, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.Font = props.Font or Enum.Font.GothamMedium
	return make("TextLabel", props)
end

local gui: ScreenGui
local toastHolder: Frame
local cashLabel: TextLabel
local stageLabel: TextLabel
local xpFill: Frame
local xpLabel: TextLabel
local cashValue: NumberValue

---------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------

function UIController.Toast(message: string, color: Color3?)
	local toast = make("Frame", {
		Size = UDim2.fromOffset(340, 44),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -60),
		BackgroundColor3 = THEME.Panel,
		Parent = toastHolder,
	})
	round(toast, 12)
	local stroke = make("UIStroke", { Color = color or THEME.Accent, Thickness = 2, Parent = toast })
	text(toast, {
		Size = UDim2.fromScale(1, 1),
		Text = message,
		TextSize = 16,
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
	})
	local slideIn = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 8) })
	slideIn:Play()
	task.delay(2.6, function()
		local slideOut = TweenService:Create(toast, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -60) })
		slideOut:Play()
		slideOut.Completed:Wait()
		stroke:Destroy()
		toast:Destroy()
	end)
end

---------------------------------------------------------------------
-- HUD pieces
---------------------------------------------------------------------

local function buildTopLeft()
	local panel = make("Frame", {
		Name = "StatusPanel",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(290, 100),
		BackgroundColor3 = THEME.Panel,
		Parent = gui,
	})
	round(panel, 14)
	outline(panel, 0.8)

	cashLabel = text(panel, {
		Name = "Cash",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(262, 42),
		Text = "$0",
		TextSize = 36,
		TextColor3 = THEME.Cash,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.FredokaOne,
	})

	stageLabel = text(panel, {
		Name = "Stage",
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.fromOffset(262, 18),
		Text = "",
		TextSize = 14,
		TextColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local barBack = make("Frame", {
		Name = "XPBar",
		Position = UDim2.fromOffset(14, 74),
		Size = UDim2.fromOffset(262, 16),
		BackgroundColor3 = THEME.PanelLight,
		Parent = panel,
	})
	round(barBack, 8)
	xpFill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.Xp,
		Parent = barBack,
	})
	round(xpFill, 8)
	xpLabel = text(barBack, {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		ZIndex = 2,
	})
end

local MENU = {
	{ Icon = "🛒", Name = "Shop", Phase = 2 },
	{ Icon = "📦", Name = "Inventory", Phase = 2 },
	{ Icon = "📖", Name = "Collection", Phase = 3 },
	{ Icon = "👷", Name = "Employees", Phase = 4 },
	{ Icon = "📜", Name = "Quests", Phase = 5 },
}

local function buildLeftMenu()
	local holder = make("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.fromOffset(66, #MENU * 62),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })

	for index, entry in MENU do
		local button = make("TextButton", {
			Name = entry.Name,
			LayoutOrder = index,
			Size = UDim2.fromOffset(66, 56),
			BackgroundColor3 = THEME.Panel,
			AutoButtonColor = true,
			Text = entry.Icon .. "\n" .. entry.Name,
			TextSize = 12,
			TextColor3 = THEME.Text,
			Font = Enum.Font.GothamBold,
			Parent = holder,
		})
		round(button, 12)
		outline(button, 0.85)
		button.Activated:Connect(function()
			UIController.Toast(entry.Name .. " opens in Phase " .. entry.Phase, THEME.Muted)
		end)
	end
end

local function buildRightPanel()
	local panel = make("Frame", {
		Name = "InfoPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(250, 150),
		BackgroundColor3 = THEME.Panel,
		Parent = gui,
	})
	round(panel, 14)
	outline(panel, 0.8)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 10), Parent = panel })
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })

	local function row(order: number, title: string, body: string, height: number)
		local container = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, Parent = panel })
		text(container, { Size = UDim2.new(1, 0, 0, 14), Text = title, TextSize = 11, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold })
		text(container, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 1, -14), Text = body, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	end

	row(1, "SUPPLIER RESTOCK", "--:--  (Phase 2)", 34)
	row(2, "ACTIVE EVENT", "None  (Phase 5)", 34)
	row(3, "CURRENT GOAL", "Foundation complete. Ordering inventory arrives in Phase 2.", 52)
end

---------------------------------------------------------------------
-- State -> HUD
---------------------------------------------------------------------

local function refreshStage()
	local state = StateController.State
	local stage = BuildingConfig.Get(state.BusinessStage or 1)
	stageLabel.Text = ("Business Lv %d  ·  %s"):format(stage.Level, stage.Name)
end

local function refreshXP()
	local state = StateController.State
	local level = state.Level or 1
	local needed = EconomyConfig.XPToNextLevel(level)
	local xp = state.XP or 0
	local fraction = if level >= EconomyConfig.XP.MaxLevel then 1 else math.clamp(xp / needed, 0, 1)
	TweenService:Create(xpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) }):Play()
	xpLabel.Text = if level >= EconomyConfig.XP.MaxLevel then ("Lv %d  MAX"):format(level) else ("Lv %d  ·  %s / %s XP"):format(level, Format.Commas(xp), Format.Commas(needed))
end

local function setCash(newCash: number, animate: boolean)
	local previous = cashValue.Value
	if not animate then
		cashValue.Value = newCash
		return
	end
	TweenService:Create(cashValue, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = newCash }):Play()
	cashLabel.TextColor3 = if newCash >= previous then THEME.Gain else THEME.Loss
	TweenService:Create(cashLabel, TweenInfo.new(0.6), { TextColor3 = THEME.Cash }):Play()
end

local previousLevel: number? = nil

local function onStateChanged(key: string, value: any)
	if key == "Cash" then
		setCash(value, StateController.Loaded)
	elseif key == "XP" then
		refreshXP()
	elseif key == "Level" then
		refreshXP()
		if previousLevel and value > previousLevel then
			UIController.Toast("Level up! You reached level " .. value, THEME.Accent)
		end
		previousLevel = value
	elseif key == "BusinessStage" then
		refreshStage()
	end
end

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------

function UIController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	gui = make("ScreenGui", {
		Name = "MainHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local uiScale = make("UIScale", { Parent = gui })
	local function updateScale()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.25)
	end
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	toastHolder = make("Frame", { Name = "Toasts", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = gui })

	cashValue = Instance.new("NumberValue")
	cashValue.Changed:Connect(function(value)
		cashLabel.Text = Format.Money(value)
	end)

	buildTopLeft()
	buildLeftMenu()
	buildRightPanel()

	StateController.Changed:Connect(onStateChanged)
	StateController.LoadedSignal:Connect(function()
		local state = StateController.State
		previousLevel = state.Level
		setCash(state.Cash or 0, false)
		refreshStage()
		refreshXP()
		UIController.Toast("Welcome to your new firework business!", THEME.Accent)
	end)
	if StateController.Loaded then
		local state = StateController.State
		previousLevel = state.Level
		setCash(state.Cash or 0, false)
		refreshStage()
		refreshXP()
	else
		cashLabel.Text = "$0"
	end
end

return UIController
