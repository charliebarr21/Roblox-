-- BuildUtil (ModuleScript, server only). Helpers for procedurally generated placeholder geometry.
-- Everything built with these is a stand-in: swap for real models later without touching game logic,
-- because gameplay code only looks at the named parts / attributes (Role, ShelfId...).

local BuildUtil = {}

function BuildUtil.Part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Adds readable text on one face of a part. Returns the TextLabel so callers can change the text later.
function BuildUtil.Label(part: BasePart, text: string, face: Enum.NormalId, textColor: Color3?, background: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	if background then
		label.BackgroundColor3 = background
	end
	label.TextColor3 = textColor or Color3.fromRGB(40, 30, 30)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = label

	return label
end

return BuildUtil
