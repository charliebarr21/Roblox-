-- StandBuilder (ModuleScript, server only)
-- Builds the placeholder business for a given stage inside a plot, and returns "anchors": the named parts and
-- CFrames later phases attach gameplay to (checkout, shelves, delivery area, launch area, supplier computer...).
--
-- Only stage 1 (Roadside Tent) exists in Phase 1. Higher stages fall back to it until Phase 4.
-- Plot-local axes: -Z is the front (road side), +Z is the back, +X is to the right when facing the back.

local BuildUtil = require(script.Parent.BuildUtil)

local StandBuilder = {}

export type Anchors = {
	Origin: CFrame, -- centre of the plot surface
	Checkout: BasePart,
	Shelves: { Model },
	SupplierComputer: BasePart,
	DeliveryArea: BasePart,
	LaunchArea: BasePart,
	PlayerSpawn: CFrame,
	CustomerSpawn: CFrame, -- where customers appear (front edge of the plot)
	QueueStart: CFrame, -- front of the checkout counter
	Sign: TextLabel,
}

local WOOD = Color3.fromRGB(160, 110, 70)
local DARK_WOOD = Color3.fromRGB(110, 75, 50)
local CLOTH = Color3.fromRGB(225, 70, 65)

local function buildTent(stand: Model, at: (number, number, number) -> CFrame, businessName: string): Anchors
	local origin = at(0, 0, 0)

	-- Floor boards under the tent
	BuildUtil.Part(stand, "TentFloor", Vector3.new(18, 0.3, 14), at(0, 0.15, 4), Color3.fromRGB(200, 165, 120), Enum.Material.WoodPlanks)

	-- Four poles
	for _, x in { -8, 8 } do
		for _, z in { -3, 11 } do
			BuildUtil.Part(stand, "Pole", Vector3.new(0.6, 7.6, 0.6), at(x, 3.8, z), DARK_WOOD, Enum.Material.Wood)
		end
	end

	-- Gable roof: ridge along X at z = 4. Front panel slopes toward -Z, back panel toward +Z.
	local slope = math.rad(20)
	local front = BuildUtil.Part(stand, "RoofFront", Vector3.new(19, 0.4, 7.5), at(0, 8.7, 0.5) * CFrame.Angles(-slope, 0, 0), CLOTH, Enum.Material.Fabric)
	local back = BuildUtil.Part(stand, "RoofBack", Vector3.new(19, 0.4, 7.5), at(0, 8.7, 7.5) * CFrame.Angles(slope, 0, 0), Color3.fromRGB(245, 240, 230), Enum.Material.Fabric)
	front.CanCollide = false
	back.CanCollide = false

	-- Checkout counter at the front edge of the tent
	local checkout = BuildUtil.Part(stand, "Checkout", Vector3.new(8, 3, 2.5), at(0, 1.5, -1), WOOD, Enum.Material.Wood)
	checkout:SetAttribute("Role", "Checkout")
	local register = BuildUtil.Part(stand, "Register", Vector3.new(2.2, 1.2, 1.6), at(2, 3.6, -1), Color3.fromRGB(40, 42, 50))
	register.CanCollide = false
	BuildUtil.Label(register, "$", Enum.NormalId.Back, Color3.fromRGB(120, 255, 150))

	-- One basic wooden shelf on the back wall
	local shelf = Instance.new("Model")
	shelf.Name = "Shelf_1"
	shelf:SetAttribute("ShelfId", 1)
	shelf:SetAttribute("ShelfType", "BasicWooden")
	shelf.Parent = stand
	local backPanel = BuildUtil.Part(shelf, "BackPanel", Vector3.new(8, 4.6, 0.4), at(0, 2.6, 10.6), DARK_WOOD, Enum.Material.Wood)
	for index, y in { 0.9, 2.2, 3.5 } do
		local board = BuildUtil.Part(shelf, "Board_" .. index, Vector3.new(8, 0.3, 1.8), at(0, y, 9.8), WOOD, Enum.Material.Wood)
		board:SetAttribute("Role", "ShelfBoard")
	end
	shelf.PrimaryPart = backPanel

	-- Order computer (Phase 2 attaches the supplier UI here)
	local desk = BuildUtil.Part(stand, "SupplierComputer", Vector3.new(3, 3, 2), at(-6.5, 1.5, 7), Color3.fromRGB(70, 74, 90))
	desk:SetAttribute("Role", "SupplierComputer")
	BuildUtil.Label(desk, "ORDER", Enum.NormalId.Front, Color3.fromRGB(120, 220, 255), Color3.fromRGB(25, 30, 45))

	-- Delivery area (left of the tent, near the road)
	local delivery = BuildUtil.Part(stand, "DeliveryArea", Vector3.new(14, 0.2, 10), at(-22, 0.1, -12), Color3.fromRGB(255, 205, 60))
	delivery:SetAttribute("Role", "DeliveryArea")
	BuildUtil.Label(delivery, "DELIVERIES", Enum.NormalId.Top, Color3.fromRGB(110, 70, 20))

	-- Small outdoor launch area behind the tent
	local launch = BuildUtil.Part(stand, "LaunchArea", Vector3.new(26, 0.2, 18), at(0, 0.1, 24), Color3.fromRGB(70, 74, 90), Enum.Material.Slate)
	launch:SetAttribute("Role", "LaunchArea")
	BuildUtil.Label(launch, "LAUNCH AREA", Enum.NormalId.Top, Color3.fromRGB(255, 230, 120))

	-- Roadside sign with the business name
	BuildUtil.Part(stand, "SignPost", Vector3.new(0.8, 6, 0.8), at(14, 3, -14), DARK_WOOD, Enum.Material.Wood)
	local sign = BuildUtil.Part(stand, "BusinessSign", Vector3.new(11, 3.6, 0.6), at(14, 7.4, -14), Color3.fromRGB(255, 244, 214))
	local signLabel = BuildUtil.Label(sign, businessName, Enum.NormalId.Front, Color3.fromRGB(150, 40, 40))

	return {
		Origin = origin,
		Checkout = checkout,
		Shelves = { shelf },
		SupplierComputer = desk,
		DeliveryArea = delivery,
		LaunchArea = launch,
		PlayerSpawn = at(0, 0, -14) * CFrame.Angles(0, math.pi, 0), -- facing the tent
		CustomerSpawn = at(26, 0, -33),
		QueueStart = at(0, 0, -6) * CFrame.Angles(0, math.pi, 0),
		Sign = signLabel,
	}
end

function StandBuilder.Build(plotModel: Model, base: BasePart, stage: number, businessName: string): Anchors
	local existing = plotModel:FindFirstChild("Stand")
	if existing then
		existing:Destroy()
	end
	if stage > 1 then
		warn("[StandBuilder] Stage " .. stage .. " models arrive in Phase 4; building the Roadside Tent instead.")
	end

	local stand = Instance.new("Model")
	stand.Name = "Stand"

	local origin = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local anchors = buildTent(stand, at, businessName)
	stand.Parent = plotModel
	return anchors
end

return StandBuilder
