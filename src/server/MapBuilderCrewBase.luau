--[[
	MapBuilderCrewBase
	==================
	Builds one crew's hideout: a walled compound with a gated entrance, a
	two-storey HQ with lit windows and a rooftop sign, floodlights,
	bollards, trees and crew banners. Accents use the crew's team colour.

	Don't run this file directly. Use MapBuilder (see the README).

	Layout, seen from above (the gate is at the front, -Z):

	    back wall
	   +-----------------------------+
	   |        [  H Q  ]            |
	   |      canopy + door          |
	   | banner      |      banner   |
	   |   bench   driveway  bench   |
	   |          (spawn)            |
	   | tree        |        tree   |
	   +--------[  gate  ]-----------+
	                front
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.MapBuilderKit)
local CrewConfig = require(ReplicatedStorage.Shared.CrewConfig)

local C = Kit.Colors
local M = Enum.Material

-- Sizes in studs. Change these to resize the base.
local HALF = 36 -- the compound is HALF × 2 = 72 studs across
local WALL_HEIGHT = 10
local WALL_THICK = 2
local GATE_WIDTH = 18
local HQ_WIDTH = 48
local HQ_DEPTH = 18
local FLOOR_HEIGHT = 11 -- height of one storey
local HQ_FRONT = 15 -- how far behind the spawn the HQ's front wall is

-- Turning a window to face left or right. CFrame.Angles(x, y, z) rotates
-- around each axis, in radians (math.pi = half a turn).
local FACE_RIGHT = CFrame.Angles(0, -math.pi / 2, 0) -- faces +X
local FACE_LEFT = CFrame.Angles(0, math.pi / 2, 0) -- faces -X

local CrewBase = {}

-- Builds the base. `origin` is a CFrame on the ground at the crew's
-- spawn, facing out through the gate.
function CrewBase.build(crewId, origin, parent)
	local crew = CrewConfig.Crews[crewId]
	local accent = crew.TeamColor.Color

	local model = Kit.newModel("Base_" .. crewId, parent)
	model:SetAttribute("CrewId", crewId)

	-- `at(x, y, z)` turns a position measured from the spawn into a real
	-- position in the world, so the whole base can be moved and turned.
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end

	-- Same pattern, used everywhere: `math.random` would give a different
	-- base each time, so we seed it with the crew's name instead.
	local random = Random.new(#crewId * 7919)

	------------------------------------------------------------------
	-- Ground
	------------------------------------------------------------------
	local ground = Kit.group("Ground", model)
	-- The paving's top sits a hair above the ground so it doesn't flicker.
	Kit.block(ground, "Paving", Vector3.new(HALF * 2, 1, HALF * 2), at(0, -0.48, 0), M.Pavement, C.Paving)

	local driveLength = HALF + HQ_FRONT
	local driveZ = (-HALF + HQ_FRONT) / 2
	Kit.block(ground, "Driveway", Vector3.new(GATE_WIDTH, 0.1, driveLength), at(0, 0.05, driveZ), M.Asphalt, C.Asphalt)
	for _, side in { -1, 1 } do
		Kit.block(ground, "Kerb", Vector3.new(0.8, 0.35, driveLength), at(side * (GATE_WIDTH / 2 + 0.4), 0.15, driveZ), M.Concrete, C.Stone)
	end

	------------------------------------------------------------------
	-- Perimeter walls
	------------------------------------------------------------------
	local walls = Kit.group("Walls", model)

	-- One straight run of wall, with a stone base, a stone cap, stone
	-- columns ("pilasters") along it, and a crew-coloured uplight at each
	-- column. (inX, inZ) points into the compound.
	local function wallRun(x, z, length, alongX, inX, inZ)
		local function size(along, height, thick)
			if alongX then
				return Vector3.new(along, height, thick)
			end
			return Vector3.new(thick, height, along)
		end

		Kit.block(walls, "Wall", size(length, WALL_HEIGHT, WALL_THICK), at(x, WALL_HEIGHT / 2, z), M.Brick, C.Brick)
		Kit.block(walls, "Plinth", size(length, 1.2, WALL_THICK + 0.4), at(x, 0.6, z), M.Concrete, C.Stone)
		Kit.block(walls, "Coping", size(length, 0.6, WALL_THICK + 0.6), at(x, WALL_HEIGHT + 0.3, z), M.Concrete, C.Stone)

		local count = math.max(1, math.floor(length / 13))
		for i = 1, count - 1 do
			local offset = -length / 2 + i * (length / count)
			local px = if alongX then x + offset else x
			local pz = if alongX then z else z + offset
			Kit.block(walls, "Pilaster", Vector3.new(3, WALL_HEIGHT + 1, 3), at(px, (WALL_HEIGHT + 1) / 2, pz), M.Concrete, C.Stone)

			local fixture = Kit.block(walls, "Uplight", Vector3.new(0.8, 0.4, 0.8), at(px + inX * 2, 0.2, pz + inZ * 2), M.Metal, C.Charcoal)
			Kit.light(fixture, "SpotLight", { Face = Enum.NormalId.Top, Angle = 40, Range = 14, Brightness = 2, Color = accent })
		end
	end

	local edge = HALF - 1 -- the middle of the wall's thickness
	local runLength = HALF * 2 - 4 -- leaves room for the corner piers
	wallRun(0, edge, runLength, true, 0, -1) -- back
	wallRun(-edge, 0, runLength, false, 1, 0) -- left
	wallRun(edge, 0, runLength, false, -1, 0) -- right

	-- Front wall: two runs, one each side of the gate.
	local gateSide = GATE_WIDTH / 2 + 3 -- where the gate pillars end
	local frontLength = (HALF - 2) - gateSide
	for _, side in { -1, 1 } do
		wallRun(side * (gateSide + frontLength / 2), -edge, frontLength, true, 0, 1)
	end

	-- Corner piers.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.block(walls, "CornerPier", Vector3.new(3.6, 12, 3.6), at(sx * edge, 6, sz * edge), M.Concrete, C.Stone)
			Kit.block(walls, "PierCap", Vector3.new(4, 0.5, 4), at(sx * edge, 12.25, sz * edge), M.Slate, C.Charcoal)
		end
	end

	------------------------------------------------------------------
	-- Gate
	------------------------------------------------------------------
	local gate = Kit.group("Gate", model)
	local pillarX = GATE_WIDTH / 2 + 1.5
	for _, side in { -1, 1 } do
		Kit.block(gate, "GatePillar", Vector3.new(3, 13, 3.2), at(side * pillarX, 6.5, -edge), M.Slate, C.Charcoal)
		-- A glowing strip down the outside face of each pillar.
		Kit.block(gate, "PillarStrip", Vector3.new(0.3, 10, 0.2), at(side * pillarX, 6.5, -edge - 1.7), M.Neon, accent)
	end

	-- The beam across the top, with the crew's name facing the street and
	-- their tagline facing the courtyard.
	local beamWidth = GATE_WIDTH + 6
	Kit.block(gate, "GateBeam", Vector3.new(beamWidth, 2.6, 1.6), at(0, 14.3, -edge), M.Metal, C.Charcoal)
	local outerSign = Kit.block(gate, "NameSign", Vector3.new(GATE_WIDTH + 2, 2, 0.2), at(0, 14.3, -edge - 0.9), M.SmoothPlastic, C.Charcoal)
	Kit.sign(outerSign, Enum.NormalId.Front, string.upper(crew.DisplayName), accent, { brightness = 4 })
	local innerSign = Kit.block(gate, "TaglineSign", Vector3.new(GATE_WIDTH + 2, 1.6, 0.2), at(0, 14.3, -edge + 0.9), M.SmoothPlastic, C.Charcoal)
	Kit.sign(innerSign, Enum.NormalId.Back, crew.Tagline, C.Stone, { brightness = 1.5, weight = Enum.FontWeight.Medium })

	local underglow = Kit.block(gate, "Underglow", Vector3.new(GATE_WIDTH, 0.2, 0.3), at(0, 12.9, -edge), M.Neon, accent)
	Kit.light(underglow, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 90, Range = 16, Brightness = 2, Color = accent })

	------------------------------------------------------------------
	-- HQ building
	------------------------------------------------------------------
	local hq = Kit.group("HQ", model)
	local hqHeight = FLOOR_HEIGHT * 2
	local hqCentreZ = HQ_FRONT + HQ_DEPTH / 2
	local hqHalfWidth = HQ_WIDTH / 2

	Kit.block(hq, "Core", Vector3.new(HQ_WIDTH, hqHeight, HQ_DEPTH), at(0, hqHeight / 2, hqCentreZ), M.Brick, C.Brick)

	-- Ground floor: dark cladding with a glass shop-front.
	local claddingFront = HQ_FRONT - 0.6
	Kit.block(hq, "Cladding", Vector3.new(HQ_WIDTH + 0.4, FLOOR_HEIGHT, 0.6), at(0, FLOOR_HEIGHT / 2, HQ_FRONT - 0.3), M.Slate, C.Charcoal)

	local bayWidth = 9.6
	for bay = -2, 2 do
		local x = bay * bayWidth
		if bay == 0 then
			-- The entrance: tall glass doors.
			Kit.window(hq, at(x, 4.4, claddingFront), 7, 8.6, true, C.Bronze)
		else
			Kit.window(hq, at(x, 5.4, claddingFront), 7.4, 7.4, true, C.Bronze)
		end
	end

	-- A stone band between the floors, with a crew-coloured glow under it.
	Kit.block(hq, "FloorBand", Vector3.new(HQ_WIDTH + 0.8, 1, 1.2), at(0, FLOOR_HEIGHT, HQ_FRONT - 0.4), M.Concrete, C.Stone)
	Kit.block(hq, "BandGlow", Vector3.new(HQ_WIDTH, 0.2, 0.2), at(0, FLOOR_HEIGHT - 0.6, claddingFront - 0.3), M.Neon, accent)

	-- Upper floor: brick with stone sills and lintels.
	local upperY = FLOOR_HEIGHT + 5.5
	for bay = -2, 2 do
		local x = bay * bayWidth
		Kit.window(hq, at(x, upperY, HQ_FRONT), 5, 6.5, random:NextNumber() < 0.6, C.Bronze)
		Kit.block(hq, "Sill", Vector3.new(6.2, 0.4, 0.9), at(x, upperY - 3.9, HQ_FRONT - 0.4), M.Concrete, C.Stone)
		Kit.block(hq, "Lintel", Vector3.new(6.2, 0.7, 0.6), at(x, upperY + 3.95, HQ_FRONT - 0.25), M.Concrete, C.Stone)
	end

	-- Side windows, both floors.
	for _, z in { HQ_FRONT + 5, HQ_FRONT + 13 } do
		for _, y in { 5.5, upperY } do
			Kit.window(hq, at(hqHalfWidth, y, z) * FACE_RIGHT, 4, 6, random:NextNumber() < 0.5, C.Bronze)
			Kit.window(hq, at(-hqHalfWidth, y, z) * FACE_LEFT, 4, 6, random:NextNumber() < 0.5, C.Bronze)
		end
	end

	-- Roof: a low wall ("parapet") around the edge, with a stone cap.
	local parapetY = hqHeight + 0.8
	Kit.block(hq, "Parapet", Vector3.new(HQ_WIDTH, 1.6, 0.8), at(0, parapetY, HQ_FRONT + 0.4), M.Brick, C.Brick)
	Kit.block(hq, "Parapet", Vector3.new(HQ_WIDTH, 1.6, 0.8), at(0, parapetY, HQ_FRONT + HQ_DEPTH - 0.4), M.Brick, C.Brick)
	Kit.block(hq, "Parapet", Vector3.new(0.8, 1.6, HQ_DEPTH - 1.6), at(hqHalfWidth - 0.4, parapetY, hqCentreZ), M.Brick, C.Brick)
	Kit.block(hq, "Parapet", Vector3.new(0.8, 1.6, HQ_DEPTH - 1.6), at(-hqHalfWidth + 0.4, parapetY, hqCentreZ), M.Brick, C.Brick)
	Kit.block(hq, "ParapetCap", Vector3.new(HQ_WIDTH + 0.6, 0.4, 1.2), at(0, hqHeight + 1.8, HQ_FRONT + 0.4), M.Concrete, C.Stone)
	Kit.block(hq, "RoofDeck", Vector3.new(HQ_WIDTH - 1.6, 0.1, HQ_DEPTH - 1.6), at(0, hqHeight + 0.05, hqCentreZ), M.Slate, C.Roof)

	-- Rooftop sign with the crew's name.
	local signY = hqHeight + 4.4
	for _, side in { -1, 1 } do
		Kit.block(hq, "SignLeg", Vector3.new(0.4, 2.6, 0.4), at(side * 8, hqHeight + 1.3, HQ_FRONT + 2.2), M.Metal, C.Steel)
	end
	local roofSign = Kit.block(hq, "RoofSign", Vector3.new(22, 3.6, 0.8), at(0, signY, HQ_FRONT + 2.2), M.Metal, C.Charcoal)
	Kit.sign(roofSign, Enum.NormalId.Front, string.upper(crew.DisplayName), accent, { brightness = 4 })
	Kit.block(hq, "RoofSignGlow", Vector3.new(20, 0.2, 0.2), at(0, signY - 1.9, HQ_FRONT + 1.7), M.Neon, accent)

	-- Air-conditioning units.
	for _, x in { -12, 12 } do
		Kit.block(hq, "ACUnit", Vector3.new(4, 2.4, 3), at(x, hqHeight + 1.2, HQ_FRONT + 12), M.Metal, C.BrushedSteel)
		Kit.cylinder(hq, "ACFan", 2.2, 0.2, at(x, hqHeight + 2.5, HQ_FRONT + 12) * Kit.UPRIGHT, M.Metal, C.Charcoal)
	end

	-- Flagpole with a crew-coloured flag.
	Kit.cylinder(hq, "Flagpole", 0.4, 12, at(18, hqHeight + 6, HQ_FRONT + 14) * Kit.UPRIGHT, M.Metal, C.BrushedSteel)
	Kit.block(hq, "Flag", Vector3.new(6, 3.6, 0.12), at(21.2, hqHeight + 10, HQ_FRONT + 14), M.Fabric, accent)

	-- Entrance canopy with a glowing edge and a downlight.
	local canopy = Kit.block(hq, "Canopy", Vector3.new(13, 0.6, 5), at(0, 9.6, HQ_FRONT - 2.5), M.Metal, C.Charcoal)
	Kit.light(canopy, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 100, Range = 14, Brightness = 2, Color = C.WarmLight })
	Kit.block(hq, "CanopyGlow", Vector3.new(13, 0.2, 0.2), at(0, 9.2, HQ_FRONT - 4.9), M.Neon, accent)

	------------------------------------------------------------------
	-- Courtyard
	------------------------------------------------------------------
	local yard = Kit.group("Courtyard", model)

	-- A planter with a small tree in it.
	local function planter(x, z, boxSize, treeSize)
		Kit.block(yard, "Planter", Vector3.new(boxSize, 1.8, boxSize), at(x, 0.9, z), M.Concrete, C.Stone)
		Kit.block(yard, "Soil", Vector3.new(boxSize - 0.6, 0.1, boxSize - 0.6), at(x, 1.85, z), M.Grass, C.Foliage)
		Kit.cylinder(yard, "Trunk", treeSize * 0.12, treeSize * 0.6, at(x, 1.8 + treeSize * 0.3, z) * Kit.UPRIGHT, M.Wood, C.Wood)
		Kit.ball(yard, "Leaves", treeSize, at(x, 1.8 + treeSize * 0.9, z), M.Grass, C.Foliage)
	end
	planter(-7.5, HQ_FRONT - 3, 3, 3.4)
	planter(7.5, HQ_FRONT - 3, 3, 3.4)
	planter(-25, -25, 5, 6)
	planter(25, -25, 5, 6)

	-- Floodlights in each corner, aimed at the middle of the yard.
	local aimAt = at(0, 0, -6).Position
	for _, x in { -(HALF - 5), HALF - 5 } do
		for _, z in { -(HALF - 5), HQ_FRONT - 5 } do
			Kit.block(yard, "PoleBase", Vector3.new(1.6, 0.8, 1.6), at(x, 0.4, z), M.Concrete, C.Charcoal)
			Kit.cylinder(yard, "Pole", 0.7, 16, at(x, 8, z) * Kit.UPRIGHT, M.Metal, C.Steel)
			local headPosition = at(x, 16.3, z).Position
			-- CFrame.lookAt makes a CFrame at one point, facing another.
			local head = CFrame.lookAt(headPosition, aimAt)
			local lamp = Kit.block(yard, "LampHead", Vector3.new(2.4, 1, 1), head, M.Metal, C.Charcoal)
			Kit.block(yard, "Lens", Vector3.new(2, 0.7, 0.1), head * CFrame.new(0, 0, -0.55), M.Neon, C.WarmLight)
			Kit.light(lamp, "SpotLight", {
				Face = Enum.NormalId.Front,
				Angle = 60,
				Range = 60,
				Brightness = 2.5,
				Shadows = true,
				Color = C.WarmLight,
			})
		end
	end

	-- Bollards along the driveway, each with a glowing crew-coloured ring.
	local bollardX = GATE_WIDTH / 2 + 1.6
	for _, z in { -28, -18, -8, 2 } do
		for _, side in { -1, 1 } do
			Kit.cylinder(yard, "Bollard", 0.8, 3, at(side * bollardX, 1.5, z) * Kit.UPRIGHT, M.Metal, C.Charcoal)
			local ring = Kit.cylinder(yard, "BollardRing", 0.85, 0.25, at(side * bollardX, 2.6, z) * Kit.UPRIGHT, M.Neon, accent)
			Kit.light(ring, "PointLight", { Range = 6, Brightness = 1, Color = accent })
		end
	end

	-- Benches facing the driveway.
	for _, side in { -1, 1 } do
		local x = side * 22
		Kit.block(yard, "Seat", Vector3.new(1.8, 0.3, 6), at(x, 1.6, -6), M.WoodPlanks, C.Wood)
		Kit.block(yard, "Backrest", Vector3.new(0.3, 1.4, 6), at(x + side * 0.8, 2.5, -6), M.WoodPlanks, C.Wood)
		for _, legZ in { -8.5, -3.5 } do
			Kit.block(yard, "BenchLeg", Vector3.new(1.6, 1.5, 0.3), at(x, 0.75, legZ), M.Metal, C.Charcoal)
		end
	end

	-- Crew banners hanging on the inside of the side walls.
	local innerFace = HALF - WALL_THICK
	for _, z in { -13.6, 0, 13.6 } do
		for _, side in { -1, 1 } do
			local x = side * (innerFace - 0.1)
			Kit.block(yard, "Banner", Vector3.new(0.15, 7, 3.5), at(x, 6, z), M.Fabric, accent)
			Kit.block(yard, "BannerRod", Vector3.new(0.3, 0.3, 4.2), at(x - side * 0.1, 9.65, z), M.Metal, C.Steel)
		end
	end

	return model
end

return CrewBase
