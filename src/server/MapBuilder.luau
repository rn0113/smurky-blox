--[[
	MapBuilder
	==========
	Builds premium-looking crew bases and chop shops into your map, and sets
	up realistic lighting. You run it ONCE from Studio's Command Bar (View >
	Command Bar) while the game is NOT running. What it builds is saved in
	your place file like anything you build by hand, so publish afterwards.

	Commands (paste one into the Command Bar and press Enter):

	  local MB = require(game.ServerScriptService.Server.MapBuilder)

	  MB.lighting()                -- realistic lighting, glow and haze
	  MB.crewBase("MudlarkMob")    -- one crew's base, built around its spawn
	  MB.allCrewBases()            -- a base for every active crew
	  MB.chopShop()                -- a chop shop where your selected part is
	  MB.chopShop("MudlarkMob")    -- the same, with that crew's colours

	Running crewBase again replaces that crew's old generated base. It only
	ever deletes models it made itself (they have a "GeneratedBy" attribute),
	never your own builds. Ctrl+Z undoes a build.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Kit = require(script.Parent.MapBuilderKit)
local CrewBase = require(script.Parent.MapBuilderCrewBase)
local ChopShop = require(script.Parent.MapBuilderChopShop)
local CrewConfig = require(ReplicatedStorage.Shared.CrewConfig)

local MapBuilder = {}

-- Chop shops not tied to a crew get this glow colour.
local NEUTRAL_ACCENT = Color3.fromRGB(0, 190, 255)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
-- Builds only work in Edit mode. During a playtest they'd vanish when
-- you press Stop.
local function checkEditMode()
	if RunService:IsRunning() then
		error("[MapBuilder] Stop the playtest first. Things built during a test disappear when it ends.")
	end
end

-- Runs `build` as one step that Ctrl+Z can undo.
local function recorded(stepName, build)
	checkEditMode()
	-- pcall ("protected call") runs a function and catches any error,
	-- instead of letting the error stop everything.
	local ok, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording(stepName)
	end)
	local success, result = pcall(build)
	if ok and recording then
		local operation = if success then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		ChangeHistoryService:FinishRecording(recording, operation)
	end
	if not success then
		error(result, 0) -- pass the original error on
	end
	return result
end

-- A CFrame on the ground at `position`, turned to face `look` (ignoring
-- any up or down tilt).
local function flatCFrame(position, look)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

local function findSpawn(teamColor)
	for _, object in workspace:GetDescendants() do
		if object:IsA("SpawnLocation") and not object.Neutral and object.TeamColor == teamColor then
			return object
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Lighting
------------------------------------------------------------------------
-- Replaces any effect of this class that MapBuilder made before.
local function freshEffect(className, parent)
	local name = "MapBuilder" .. className
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local effect = Instance.new(className)
	effect.Name = name
	return effect
end

function MapBuilder.lighting()
	recorded("MapBuilder lighting", function()
		-- Future is Roblox's most realistic lighting: real shadows from
		-- every lamp. Some settings can only be changed in Studio, so
		-- they're wrapped in pcall in case Roblox refuses one.
		pcall(function()
			Lighting.Technology = Enum.Technology.Future
		end)
		pcall(function()
			MaterialService.Use2022Materials = true -- the detailed material set
		end)

		Lighting.ClockTime = 17.6 -- early evening: neon and lamps show up
		Lighting.GeographicLatitude = 51.5 -- London, so the sun sits right
		Lighting.Brightness = 2.5
		Lighting.GlobalShadows = true
		Lighting.ShadowSoftness = 0.2
		Lighting.EnvironmentDiffuseScale = 1 -- lets the sky light shiny surfaces
		Lighting.EnvironmentSpecularScale = 1
		Lighting.Ambient = Color3.fromRGB(40, 42, 48)
		Lighting.OutdoorAmbient = Color3.fromRGB(110, 115, 125)
		Lighting.ExposureCompensation = 0

		-- Atmosphere: London haze.
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere == nil then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Parent = Lighting
		end
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.25
		atmosphere.Color = Color3.fromRGB(199, 199, 205)
		atmosphere.Decay = Color3.fromRGB(106, 112, 125)
		atmosphere.Glare = 0.3
		atmosphere.Haze = 1.5

		-- Bloom: makes neon and bright lights glow softly.
		local bloom = freshEffect("BloomEffect", Lighting)
		bloom.Intensity = 0.6
		bloom.Size = 28
		bloom.Threshold = 1.6
		bloom.Parent = Lighting

		-- Colour correction: a little more contrast, like a film.
		local grade = freshEffect("ColorCorrectionEffect", Lighting)
		grade.Contrast = 0.12
		grade.Saturation = 0.06
		grade.Brightness = 0.02
		grade.TintColor = Color3.fromRGB(255, 247, 240)
		grade.Parent = Lighting

		local sunRays = freshEffect("SunRaysEffect", Lighting)
		sunRays.Intensity = 0.06
		sunRays.Spread = 0.6
		sunRays.Parent = Lighting
	end)
	print("[MapBuilder] Lighting done.")
end

------------------------------------------------------------------------
-- Crew bases
------------------------------------------------------------------------
function MapBuilder.crewBase(crewId)
	local crew = CrewConfig.Crews[crewId]
	if crew == nil then
		error("[MapBuilder] No crew called '" .. tostring(crewId) .. "'. Use an ID from CrewConfig, e.g. \"MudlarkMob\".")
	end

	local spawn = findSpawn(crew.TeamColor)
	if spawn == nil then
		error("[MapBuilder] " .. crew.DisplayName .. " has no spawn yet. Add a SpawnLocation with TeamColor '" .. crew.TeamColor.Name .. "', untick Neutral, and turn it so its front faces where the gate should go.")
	end

	-- The ground under the spawn, facing the way the spawn faces.
	local ground = spawn.Position - Vector3.new(0, spawn.Size.Y / 2, 0)
	local origin = flatCFrame(ground, spawn.CFrame.LookVector)

	local model = recorded("MapBuilder crew base", function()
		Kit.removeGenerated(workspace, "Base_" .. crewId)
		return CrewBase.build(crewId, origin, workspace)
	end)
	print("[MapBuilder] Built " .. model.Name .. " around the " .. crew.DisplayName .. " spawn.")
	return model
end

function MapBuilder.allCrewBases()
	for _, crewId in CrewConfig.ActiveCrews do
		MapBuilder.crewBase(crewId)
	end
end

------------------------------------------------------------------------
-- Chop shops
------------------------------------------------------------------------
function MapBuilder.chopShop(crewId)
	local accent = NEUTRAL_ACCENT
	if crewId ~= nil then
		local crew = CrewConfig.Crews[crewId]
		if crew == nil then
			error("[MapBuilder] No crew called '" .. tostring(crewId) .. "'.")
		end
		accent = crew.TeamColor.Color
	end

	-- Build on top of the selected part, facing the way it faces.
	local selected = Selection:Get()[1]
	if selected == nil or not selected:IsA("BasePart") or selected:IsA("Terrain") then
		error("[MapBuilder] Select a part first (click it in the 3D view). The chop shop's doors go where that part is, facing the part's front.")
	end
	local top = selected.Position + Vector3.new(0, selected.Size.Y / 2, 0)
	local origin = flatCFrame(top, selected.CFrame.LookVector)

	local name = if crewId then "ChopShop_" .. crewId else "ChopShop"
	local model = recorded("MapBuilder chop shop", function()
		return ChopShop.build(name, origin, accent, workspace)
	end)
	print("[MapBuilder] Built " .. name .. ". You can now delete the marker part you selected.")
	return model
end

return MapBuilder
