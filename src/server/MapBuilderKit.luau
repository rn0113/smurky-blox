--[[
	MapBuilderKit
	=============
	Small helper functions the map builders (MapBuilderCrewBase,
	MapBuilderChopShop) use to make parts, lights, windows and signs.
	Keeping them here means every building shares one look.
]]

local Kit = {}

-- Every model the builders make gets this attribute. A rebuild only ever
-- deletes models carrying it, never things you built by hand.
Kit.TAG = "GeneratedBy"
Kit.TAG_VALUE = "MapBuilder"

-- Turn a part 90 degrees so a cylinder stands upright. Roblox cylinders
-- lie along their X axis by default.
Kit.UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

-- One shared palette, so every building feels like part of the same city.
-- Color3.fromRGB takes red, green, blue from 0 to 255.
Kit.Colors = {
	Brick = Color3.fromRGB(104, 66, 54), -- dark London brick
	Stone = Color3.fromRGB(196, 192, 182), -- pale stone trim
	Charcoal = Color3.fromRGB(44, 46, 50), -- dark cladding
	Steel = Color3.fromRGB(64, 67, 72), -- painted metal
	BrushedSteel = Color3.fromRGB(160, 163, 168),
	Bronze = Color3.fromRGB(122, 96, 66), -- window frames
	Glass = Color3.fromRGB(38, 50, 60),
	Paving = Color3.fromRGB(110, 110, 112),
	Asphalt = Color3.fromRGB(46, 47, 50),
	Roof = Color3.fromRGB(60, 62, 66),
	WarmLight = Color3.fromRGB(255, 214, 170),
	CoolLight = Color3.fromRGB(235, 242, 255),
	RoomGlow = Color3.fromRGB(118, 92, 66), -- a lit room seen through glass
	RoomDark = Color3.fromRGB(18, 20, 24), -- an unlit room
	Foliage = Color3.fromRGB(58, 86, 50),
	Wood = Color3.fromRGB(120, 84, 56),
	Rubber = Color3.fromRGB(24, 24, 26),
	ToolRed = Color3.fromRGB(176, 38, 38),
	SafetyYellow = Color3.fromRGB(230, 190, 40),
}

-- Makes an empty Model tagged as builder-made.
function Kit.newModel(name, parent)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute(Kit.TAG, Kit.TAG_VALUE)
	model.Parent = parent
	return model
end

-- Makes a plain Model for grouping parts inside a building (walls, lights...).
function Kit.group(name, parent)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Deletes an old builder-made model with this name, if there is one.
function Kit.removeGenerated(parent, name)
	for _, child in parent:GetChildren() do
		if child.Name == name and child:GetAttribute(Kit.TAG) == Kit.TAG_VALUE then
			child:Destroy()
		end
	end
end

-- Makes one anchored block. Almost everything is built from these.
function Kit.block(parent, name, size, cframe, material, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true -- stays put; doesn't fall or get pushed
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if material == Enum.Material.Neon then
		part.CastShadow = false -- glowing strips shouldn't cast shadows
	end
	part.Parent = parent
	return part
end

-- A cylinder `diameter` wide and `length` long, lying along the cframe's X axis.
-- Use `cframe * Kit.UPRIGHT` to stand it on its end.
function Kit.cylinder(parent, name, diameter, length, cframe, material, color)
	local part = Kit.block(parent, name, Vector3.new(length, diameter, diameter), cframe, material, color)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A ball, e.g. a tree's leaves.
function Kit.ball(parent, name, diameter, cframe, material, color)
	local part = Kit.block(parent, name, Vector3.new(diameter, diameter, diameter), cframe, material, color)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Adds a light (PointLight, SpotLight or SurfaceLight) to a part.
-- `props` is a table of settings, e.g. { Range = 20, Color = ... }.
function Kit.light(part, className, props)
	local light = Instance.new(className)
	for key, value in props do
		light[key] = value
	end
	light.Parent = part
	return light
end

-- Puts glowing text on one face of a part. `options` can set:
--   brightness (default 3), weight (a Enum.FontWeight)
function Kit.sign(part, face, text, color, options)
	options = options or {}

	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0 -- ignore the scene's lighting, so it glows at night
	gui.Brightness = options.brightness or 3

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", options.weight or Enum.FontWeight.Heavy)
	label.Parent = gui

	-- Keep the letters away from the edges of the sign.
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label

	gui.Parent = part
	return gui
end

-- A framed window. `cframe` sits on the wall's surface, facing out of the
-- wall (its LookVector points outside). `lit` shows a warm glowing room
-- behind the glass; otherwise the room is dark.
function Kit.window(parent, cframe, width, height, lit, frameColor)
	local group = Kit.group("Window", parent)

	-- The "room" behind the glass: dim Neon reads as a lit interior.
	if lit then
		Kit.block(group, "Room", Vector3.new(width, height, 0.1), cframe * CFrame.new(0, 0, -0.05), Enum.Material.Neon, Kit.Colors.RoomGlow)
	else
		Kit.block(group, "Room", Vector3.new(width, height, 0.1), cframe * CFrame.new(0, 0, -0.05), Enum.Material.SmoothPlastic, Kit.Colors.RoomDark)
	end

	local glass = Kit.block(group, "Glass", Vector3.new(width, height, 0.1), cframe * CFrame.new(0, 0, -0.15), Enum.Material.Glass, Kit.Colors.Glass)
	glass.Transparency = 0.3
	glass.Reflectance = 0.2
	glass.CastShadow = false

	-- Frame: top, bottom, left, right, plus one bar down the middle.
	local bar = 0.35
	local depth = 0.5
	local z = -depth / 2
	local frame = Enum.Material.Metal
	Kit.block(group, "Frame", Vector3.new(width + bar * 2, bar, depth), cframe * CFrame.new(0, height / 2 + bar / 2, z), frame, frameColor)
	Kit.block(group, "Frame", Vector3.new(width + bar * 2, bar, depth), cframe * CFrame.new(0, -height / 2 - bar / 2, z), frame, frameColor)
	Kit.block(group, "Frame", Vector3.new(bar, height, depth), cframe * CFrame.new(width / 2 + bar / 2, 0, z), frame, frameColor)
	Kit.block(group, "Frame", Vector3.new(bar, height, depth), cframe * CFrame.new(-width / 2 - bar / 2, 0, z), frame, frameColor)
	Kit.block(group, "Mullion", Vector3.new(bar * 0.6, height, depth * 0.8), cframe * CFrame.new(0, 0, z), frame, frameColor)

	return group
end

-- Marks where a shop employee stands. The ShopEmployees script finds every
-- part tagged "ShopEmployee" when the game starts and puts an employee
-- there, facing the same way as the marker. `shopName` is what the
-- employee calls their shop.
function Kit.employeeSpot(parent, cframe, shopName)
	local spot = Kit.block(parent, "EmployeeSpot", Vector3.new(2, 0.2, 2), cframe, Enum.Material.SmoothPlastic, Color3.fromRGB(80, 220, 120))
	spot.Transparency = 0.5 -- a see-through green marker; hidden when the game runs
	spot.CanCollide = false
	spot:SetAttribute("ShopName", shopName)
	spot:AddTag("ShopEmployee")
	return spot
end

return Kit
