--[[
	Outfits (server script)
	=======================
	Dresses every player in their team's outfit each time they spawn.
	What each team wears is set in src/shared/OutfitConfig.luau.

	It works with both body types Roblox uses:
	  - R15 (15 body parts, e.g. "UpperTorso", "LeftUpperArm")
	  - R6  (6 body parts, e.g. "Torso", "Left Arm")
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrewConfig = require(ReplicatedStorage.Shared.CrewConfig)
local OutfitConfig = require(ReplicatedStorage.Shared.OutfitConfig)

-- Every piece of gear gets this name, so we can find and remove old gear.
local GEAR_FOLDER_NAME = "TeamGear"

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------
-- Returns the first body part that exists out of the names given.
-- `...` means "any number of extra arguments".
local function findPart(character, ...)
	for _, name in { ... } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- Makes one piece of gear and glues it to a body part.
-- `offset` says where it sits, measured from the body part's centre.
local function addGear(folder, bodyPart, name, size, offset, color, material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.CFrame = bodyPart.CFrame * offset

	-- Gear is just for looks: it shouldn't weigh anything, block bullets
	-- or trip the player up.
	piece.Massless = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false

	-- A WeldConstraint glues two parts together so they move as one.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = piece
	weld.Parent = piece

	piece.Parent = folder
	return piece
end

-- Puts text on one face of a part. With `topOnly`, the text only uses
-- the top part of the face (so it stays clear of the vest's hi-vis band).
local function addText(part, face, text, color, topOnly)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100

	local label = Instance.new("TextLabel")
	if topOnly then
		label.Size = UDim2.fromScale(0.9, 0.3)
		label.Position = UDim2.fromScale(0.05, 0.1)
	else
		label.Size = UDim2.fromScale(1, 1)
	end
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.Parent = gui

	gui.Parent = part
end

------------------------------------------------------------------------
-- Uniform clothing
------------------------------------------------------------------------
-- Swaps the player's Shirt or Pants for the team's, if the team has one.
local function setClothing(character, className, propertyName, assetId)
	if assetId == 0 then
		return -- no uniform set: keep the player's own clothes
	end

	local clothing = character:FindFirstChildOfClass(className)
	if clothing == nil then
		clothing = Instance.new(className)
		clothing.Parent = character
	end
	clothing[propertyName] = "rbxassetid://" .. assetId
end

------------------------------------------------------------------------
-- Gear
------------------------------------------------------------------------
local function addCrewGear(folder, character, crewColor, outfit)
	local torso = findPart(character, "UpperTorso", "Torso")
	local leftArm = findPart(character, "LeftUpperArm", "Left Arm")

	if leftArm then
		-- An armband around the upper arm, a little bigger than the arm.
		local armSize = leftArm.Size
		local isR6 = leftArm.Name == "Left Arm"
		local bandY = if isR6 then armSize.Y * 0.3 else armSize.Y * 0.1
		addGear(
			folder,
			leftArm,
			"Armband",
			Vector3.new(armSize.X + 0.08, 0.35, armSize.Z + 0.08),
			CFrame.new(0, bandY, 0),
			crewColor,
			Enum.Material.Fabric
		)
	end

	if torso then
		-- A small badge on the left side of the chest. Measured from the
		-- torso: -Z is the front of the body and -X is the wearer's left.
		local size = torso.Size
		local front = -size.Z / 2 -- the front surface of the torso
		local badgeOffset = CFrame.new(-size.X * 0.25, size.Y * 0.2, front - 0.03)

		addGear(folder, torso, "BadgeTrim", Vector3.new(0.5, 0.5, 0.05), badgeOffset, OutfitConfig.BadgeTrimColor, Enum.Material.Metal)
		local badge = addGear(
			folder,
			torso,
			"Badge",
			Vector3.new(0.42, 0.42, 0.05),
			badgeOffset * CFrame.new(0, 0, -0.02),
			OutfitConfig.BadgeBackColor,
			Enum.Material.SmoothPlastic
		)
		addText(badge, Enum.NormalId.Front, outfit.BadgeText, crewColor)
	end
end

local function addPoliceGear(folder, character, outfit)
	local torso = findPart(character, "UpperTorso", "Torso")
	if torso == nil then
		return
	end

	-- A stab vest: a slightly bigger box around the torso.
	local size = torso.Size
	local vestSize = Vector3.new(size.X + 0.12, size.Y * 0.85, size.Z + 0.25)
	local vestOffset = CFrame.new(0, -size.Y * 0.05, 0)
	local vest = addGear(folder, torso, "Vest", vestSize, vestOffset, outfit.VestColor, Enum.Material.Fabric)

	-- Hi-vis band around the middle of the vest.
	addGear(
		folder,
		torso,
		"HiVisBand",
		Vector3.new(vestSize.X + 0.02, vestSize.Y * 0.18, vestSize.Z + 0.02),
		vestOffset * CFrame.new(0, -vestSize.Y * 0.2, 0),
		outfit.HiVisColor,
		Enum.Material.SmoothPlastic
	)

	-- "POLICE" across the chest and the back.
	addText(vest, Enum.NormalId.Front, outfit.VestText, Color3.new(1, 1, 1), true)
	addText(vest, Enum.NormalId.Back, outfit.VestText, Color3.new(1, 1, 1), true)
end

------------------------------------------------------------------------
-- Dress a character
------------------------------------------------------------------------
local function dress(player, character)
	local teamId = player:GetAttribute("CrewId")
	local outfit = OutfitConfig.Teams[teamId]
	if outfit == nil then
		return -- no team (or no outfit for it) yet
	end

	setClothing(character, "Shirt", "ShirtTemplate", outfit.ShirtId)
	setClothing(character, "Pants", "PantsTemplate", outfit.PantsId)

	-- Remove gear from an earlier dress-up, then build fresh gear.
	local oldFolder = character:FindFirstChild(GEAR_FOLDER_NAME)
	if oldFolder then
		oldFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = GEAR_FOLDER_NAME
	folder.Parent = character

	if teamId == "Police" then
		addPoliceGear(folder, character, outfit)
	else
		local crew = CrewConfig.Crews[teamId]
		addCrewGear(folder, character, crew.TeamColor.Color, outfit)
	end
end

------------------------------------------------------------------------
-- Hook it up
------------------------------------------------------------------------
-- CharacterAppearanceLoaded fires after the player's own avatar clothes
-- have finished loading, so our uniform goes on top instead of being
-- replaced by them a moment later.
local function onPlayerAdded(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		dress(player, character)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
	if player.Character and player:HasAppearanceLoaded() then
		dress(player, player.Character)
	end
end
