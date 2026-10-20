--[[
	OutfitConfig
	============
	What each team wears. The Outfits server script reads this every time a
	player spawns.

	Two layers make up an outfit:

	1. UNIFORM CLOTHING (ShirtId / PantsId)
	   Classic Roblox clothing: a flat image wrapped around the body.
	   To use one, find a suit or uniform in the Creator Store (Studio's
	   Toolbox, or create.roblox.com/store), open its page, and copy the
	   number from the web address, e.g. roblox.com/catalog/1234567/... -> 1234567.
	   Leave it at 0 to let players keep their own clothes.
	   Tip: make your own matching set (one shirt + one pants template
	   per crew) so every crew looks equally sharp. That's fair, and you
	   own the designs.

	2. GEAR
	   Small 3D pieces the script builds and fits to each body, so teams
	   are easy to tell apart even before you add clothing:
	     - crews get an armband and a chest badge in their crew colour
	     - the Police get a stab vest with hi-vis bands and "POLICE" on it

	The crew colours themselves come from CrewConfig, so they always match
	the team colour on the leaderboard.
]]

local OutfitConfig = {}

-- Keyed by crew ID (same IDs as CrewConfig.Crews), plus "Police".
OutfitConfig.Teams = {
	MudlarkMob = {
		ShirtId = 0,
		PantsId = 0,
		BadgeText = "MM", -- the letters on the chest badge
	},
	BlackCabBrawlers = {
		ShirtId = 0,
		PantsId = 0,
		BadgeText = "BC",
	},
	BarrowBoys = {
		ShirtId = 0,
		PantsId = 0,
		BadgeText = "BB",
	},
	TowerBlockTerrors = {
		ShirtId = 0,
		PantsId = 0,
		BadgeText = "TB",
	},
	Police = {
		ShirtId = 0,
		PantsId = 0,
		-- A made-up force. No real police logos or checker patterns.
		VestText = "POLICE",
		VestColor = Color3.fromRGB(24, 28, 36), -- near-black navy
		HiVisColor = Color3.fromRGB(210, 255, 40), -- fluorescent yellow-green
	},
}

-- Colours shared by every crew's gear, so all crews look equally smart.
OutfitConfig.BadgeBackColor = Color3.fromRGB(28, 28, 30) -- dark badge plate
OutfitConfig.BadgeTrimColor = Color3.fromRGB(196, 168, 108) -- brushed brass edge

return OutfitConfig
