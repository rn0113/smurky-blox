--[[
	MapBuilderChopShop
	==================
	Builds a chop shop: a two-bay garage with a dark clad front, a glowing
	sign, one roller door shut and one open. Inside there's a polished
	floor, strip lights, a car lift holding a half-stripped car, tool
	chests, a workbench, tyre stacks and oil drums.

	Don't run this file directly. Use MapBuilder (see the README).

	`origin` is a CFrame on the ground at the middle of the garage's front
	wall, facing out of the doors (-Z). The forecourt is in front of it.
]]

local Kit = require(script.Parent.MapBuilderKit)

local C = Kit.Colors
local M = Enum.Material

local WIDTH = 40
local DEPTH = 32
local HEIGHT = 16
local DOOR_WIDTH = 12
local DOOR_HEIGHT = 11
local DOOR_X = 9 -- each door's centre is this far from the middle

local ChopShop = {}

-- A simple sports car made of blocks. `cf` is on the ground under the
-- car's middle; the car's nose points to -Z. Leave out a wheel by
-- passing its name in `missing`, e.g. { FrontLeft = true }.
local function buildCar(parent, cf, paint, missing)
	local car = Kit.group("Car", parent)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	local body = Kit.block(car, "Body", Vector3.new(7, 1.8, 15), at(0, 1.5, 0), M.SmoothPlastic, paint)
	body.Reflectance = 0.15 -- a glossy paint job
	local cabin = Kit.block(car, "Cabin", Vector3.new(6, 1.5, 7.5), at(0, 3.15, 1), M.Glass, C.Glass)
	cabin.Transparency = 0.2
	cabin.Reflectance = 0.25
	local roof = Kit.block(car, "Roof", Vector3.new(5.8, 0.2, 6), at(0, 3.95, 1), M.SmoothPlastic, paint)
	roof.Reflectance = 0.15

	for _, side in { -1, 1 } do
		Kit.block(car, "Headlight", Vector3.new(1.4, 0.4, 0.1), at(side * 2.4, 1.9, -7.55), M.Neon, C.CoolLight)
		Kit.block(car, "TailLight", Vector3.new(1.6, 0.3, 0.1), at(side * 2.3, 1.9, 7.55), M.Neon, Color3.fromRGB(200, 20, 30))
	end

	local wheels = {
		FrontLeft = Vector3.new(-3.3, 1.2, -5),
		FrontRight = Vector3.new(3.3, 1.2, -5),
		BackLeft = Vector3.new(-3.3, 1.2, 5),
		BackRight = Vector3.new(3.3, 1.2, 5),
	}
	for name, position in wheels do
		if not missing[name] then
			Kit.cylinder(car, "Tyre", 2.4, 1, at(position.X, position.Y, position.Z), M.SmoothPlastic, C.Rubber)
			local outward = if position.X > 0 then 0.05 else -0.05
			Kit.cylinder(car, "Rim", 1.5, 1, at(position.X + outward, position.Y, position.Z), M.Metal, C.BrushedSteel)
		end
	end

	return car
end

function ChopShop.build(name, origin, accent, parent)
	local model = Kit.newModel(name, parent)

	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end

	local half = WIDTH / 2

	------------------------------------------------------------------
	-- Forecourt
	------------------------------------------------------------------
	local forecourt = Kit.group("Forecourt", model)
	Kit.block(forecourt, "Asphalt", Vector3.new(WIDTH + 4, 0.4, 18), at(0, -0.14, -9), M.Asphalt, C.Asphalt)
	Kit.block(forecourt, "Kerb", Vector3.new(WIDTH + 4, 0.35, 0.8), at(0, 0.15, -18.4), M.Concrete, C.Stone)

	-- Yellow "keep clear" boxes in front of each door.
	for _, side in { -1, 1 } do
		local x = side * DOOR_X
		for _, z in { -1.5, -9.5 } do
			Kit.block(forecourt, "Line", Vector3.new(DOOR_WIDTH, 0.04, 0.3), at(x, 0.08, z), M.SmoothPlastic, C.SafetyYellow)
		end
		for _, dx in { -DOOR_WIDTH / 2, DOOR_WIDTH / 2 } do
			Kit.block(forecourt, "Line", Vector3.new(0.3, 0.04, 8), at(x + dx, 0.08, -5.5), M.SmoothPlastic, C.SafetyYellow)
		end
	end

	------------------------------------------------------------------
	-- Shell: floor, walls, roof
	------------------------------------------------------------------
	local shell = Kit.group("Shell", model)

	local floor = Kit.block(shell, "Floor", Vector3.new(WIDTH - 2, 0.4, DEPTH - 2), at(0, -0.1, DEPTH / 2), M.SmoothPlastic, Color3.fromRGB(78, 82, 90))
	floor.Reflectance = 0.1 -- polished resin floor

	Kit.block(shell, "BackWall", Vector3.new(WIDTH, HEIGHT, 1), at(0, HEIGHT / 2, DEPTH - 0.5), M.Brick, C.Brick)
	for _, side in { -1, 1 } do
		Kit.block(shell, "SideWall", Vector3.new(1, HEIGHT, DEPTH - 2), at(side * (half - 0.5), HEIGHT / 2, DEPTH / 2), M.Brick, C.Brick)
	end
	Kit.block(shell, "Roof", Vector3.new(WIDTH + 1, 1, DEPTH + 1), at(0, HEIGHT + 0.5, DEPTH / 2), M.Metal, C.Steel)
	Kit.block(shell, "Fascia", Vector3.new(WIDTH + 1, 1.4, 0.4), at(0, HEIGHT + 0.6, -0.7), M.Metal, C.Charcoal)

	-- Front wall: three piers between the doors, and a header above them.
	local doorEdge = DOOR_X + DOOR_WIDTH / 2 -- outer edge of each door (15)
	local innerEdge = DOOR_X - DOOR_WIDTH / 2 -- inner edge of each door (3)
	local outerPier = half - doorEdge
	for _, side in { -1, 1 } do
		Kit.block(shell, "Pier", Vector3.new(outerPier, DOOR_HEIGHT, 1), at(side * (doorEdge + outerPier / 2), DOOR_HEIGHT / 2, 0.5), M.Slate, C.Charcoal)
		-- Glowing strips up the front corners.
		Kit.block(shell, "CornerGlow", Vector3.new(0.25, DOOR_HEIGHT, 0.25), at(side * (half - 0.15), DOOR_HEIGHT / 2, -0.15), M.Neon, accent)
	end
	Kit.block(shell, "Pier", Vector3.new(innerEdge * 2, DOOR_HEIGHT, 1), at(0, DOOR_HEIGHT / 2, 0.5), M.Slate, C.Charcoal)
	local headerHeight = HEIGHT - DOOR_HEIGHT
	Kit.block(shell, "Header", Vector3.new(WIDTH, headerHeight, 1), at(0, DOOR_HEIGHT + headerHeight / 2, 0.5), M.Slate, C.Charcoal)

	------------------------------------------------------------------
	-- Doors, sign and outside lights
	------------------------------------------------------------------
	local front = Kit.group("Front", model)

	for _, side in { -1, 1 } do
		local x = side * DOOR_X
		-- The box the roller door rolls up into.
		Kit.block(front, "DoorHousing", Vector3.new(DOOR_WIDTH + 0.6, 1.2, 1.2), at(x, DOOR_HEIGHT + 0.6, -0.6), M.Metal, C.BrushedSteel)
		for _, dx in { -1, 1 } do
			Kit.block(front, "DoorRail", Vector3.new(0.4, DOOR_HEIGHT, 0.6), at(x + dx * (DOOR_WIDTH / 2 - 0.2), DOOR_HEIGHT / 2, 0.3), M.Metal, C.Steel)
		end
	end

	-- The left door is shut: a stack of metal slats.
	local slatHeight = DOOR_HEIGHT / 10
	for i = 0, 9 do
		local shade = if i % 2 == 0 then C.BrushedSteel else Color3.fromRGB(140, 143, 148)
		Kit.block(front, "Slat", Vector3.new(DOOR_WIDTH - 0.8, slatHeight - 0.06, 0.25), at(-DOOR_X, slatHeight * (i + 0.5), 0.6), M.Metal, shade)
	end

	-- A glow strip across the front, above the door housings.
	Kit.block(front, "FrontGlow", Vector3.new(WIDTH, 0.25, 0.25), at(0, DOOR_HEIGHT + 1.4, -0.15), M.Neon, accent)

	local sign = Kit.block(front, "Sign", Vector3.new(22, 2.8, 0.3), at(0, DOOR_HEIGHT + 3.1, -0.15), M.SmoothPlastic, C.Charcoal)
	Kit.sign(sign, Enum.NormalId.Front, "CHOP SHOP", accent, { brightness = 4 })

	local plaque = Kit.block(front, "Plaque", Vector3.new(4.6, 2.4, 0.15), at(0, 7, -0.08), M.Metal, C.Bronze)
	Kit.sign(plaque, Enum.NormalId.Front, "RESPRAYS · REBUILDS · NO QUESTIONS", C.Stone, { brightness = 1.5, weight = Enum.FontWeight.Bold })

	-- Wall lanterns on each pier, shining down.
	for _, x in { -(doorEdge + outerPier / 2), 0, doorEdge + outerPier / 2 } do
		local lantern = Kit.block(front, "Lantern", Vector3.new(0.8, 1.2, 0.6), at(x, 9.2, -0.3), M.Metal, C.Charcoal)
		Kit.block(front, "LanternGlow", Vector3.new(0.6, 0.1, 0.4), at(x, 8.55, -0.3), M.Neon, C.WarmLight)
		Kit.light(lantern, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 80, Range = 14, Brightness = 2, Color = C.WarmLight })
	end

	------------------------------------------------------------------
	-- Inside
	------------------------------------------------------------------
	local inside = Kit.group("Interior", model)

	-- Strip lights along the ceiling.
	for _, x in { -12, 0, 12 } do
		local tube = Kit.block(inside, "StripLight", Vector3.new(0.35, 0.2, 24), at(x, HEIGHT - 0.6, DEPTH / 2), M.Neon, C.CoolLight)
		Kit.light(tube, "SurfaceLight", { Face = Enum.NormalId.Bottom, Angle = 140, Range = 18, Brightness = 1.2, Color = C.CoolLight })
	end

	-- Car lift in the open (right) bay, holding a car with a wheel off.
	local liftZ = 16
	for _, side in { -1, 1 } do
		local postX = DOOR_X + side * 5.2
		Kit.block(inside, "LiftPost", Vector3.new(1.2, 11, 1.4), at(postX, 5.5, liftZ), M.Metal, C.ToolRed)
		for _, dz in { -2.5, 2.5 } do
			Kit.block(inside, "LiftArm", Vector3.new(3.2, 0.35, 0.7), at(DOOR_X + side * 3.6, 4.3, liftZ + dz), M.Metal, C.Steel)
		end
	end
	buildCar(inside, at(DOOR_X, 3.9, liftZ), Color3.fromRGB(24, 66, 48), { FrontLeft = true })

	-- The missing wheel, lying on the floor nearby.
	Kit.cylinder(inside, "LooseTyre", 2.4, 1, at(1.5, 0.6, 11) * Kit.UPRIGHT, M.SmoothPlastic, C.Rubber)

	-- Yellow safety lines around the lift.
	for _, x in { DOOR_X - 6.5, DOOR_X + 6.5 } do
		Kit.block(inside, "SafetyLine", Vector3.new(0.3, 0.04, 18), at(x, 0.12, liftZ), M.SmoothPlastic, C.SafetyYellow)
	end
	for _, z in { liftZ - 9, liftZ + 9 } do
		Kit.block(inside, "SafetyLine", Vector3.new(13.3, 0.04, 0.3), at(DOOR_X, 0.12, z), M.SmoothPlastic, C.SafetyYellow)
	end

	-- Tool wall: a pegboard with tools hung on it, and two tool chests.
	local backFace = DEPTH - 1
	Kit.block(inside, "Pegboard", Vector3.new(16, 6, 0.2), at(-DOOR_X, 7.5, backFace - 0.1), M.SmoothPlastic, Color3.fromRGB(190, 190, 186))
	local random = Random.new(42)
	for i = 1, 10 do
		local toolX = -DOOR_X - 7 + i * 1.3
		local length = random:NextNumber(1.2, 2.6)
		Kit.block(inside, "Tool", Vector3.new(0.25, length, 0.15), at(toolX, 8 - length / 4, backFace - 0.3), M.Metal, C.Steel)
	end
	for _, x in { -14, -4 } do
		Kit.block(inside, "ToolChest", Vector3.new(5, 4, 2), at(x, 2.1, backFace - 1.1), M.Metal, C.ToolRed)
		Kit.block(inside, "ChestTop", Vector3.new(5.2, 0.15, 2.2), at(x, 4.18, backFace - 1.1), M.SmoothPlastic, C.Rubber)
		for drawer = 1, 4 do
			Kit.block(inside, "DrawerHandle", Vector3.new(4.4, 0.12, 0.1), at(x, drawer * 0.85 + 0.3, backFace - 2.15), M.Metal, C.BrushedSteel)
		end
	end

	-- Workbench along the left wall.
	local benchX = -(half - 2.5)
	Kit.block(inside, "BenchTop", Vector3.new(3, 0.4, 10), at(benchX, 3.4, 16), M.WoodPlanks, C.Wood)
	for _, dx in { -1.2, 1.2 } do
		for _, dz in { -4.6, 4.6 } do
			Kit.block(inside, "BenchLeg", Vector3.new(0.4, 3.2, 0.4), at(benchX + dx, 1.6, 16 + dz), M.Metal, C.Charcoal)
		end
	end

	-- Tyre stacks in the back-right corner.
	for _, z in { 24, 28 } do
		for level = 0, 3 do
			Kit.cylinder(inside, "Tyre", 2.8, 0.95, at(half - 3, 0.6 + level, z) * Kit.UPRIGHT, M.SmoothPlastic, C.Rubber)
		end
	end

	-- Oil drums by the front-left corner.
	Kit.cylinder(inside, "Drum", 2, 3, at(-(half - 2.5), 1.6, 4) * Kit.UPRIGHT, M.Metal, Color3.fromRGB(30, 60, 120))
	Kit.cylinder(inside, "Drum", 2, 3, at(-(half - 2.5), 1.6, 6.4) * Kit.UPRIGHT, M.Metal, Color3.fromRGB(150, 30, 30))

	------------------------------------------------------------------
	-- Roof
	------------------------------------------------------------------
	Kit.block(model, "ACUnit", Vector3.new(4, 2.2, 3), at(12, HEIGHT + 2.1, 24), M.Metal, C.BrushedSteel)

	return model
end

return ChopShop
