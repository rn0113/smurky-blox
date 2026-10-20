--[[
	CrewConfig
	==========
	ONE place that describes every crew in the game.

	This is a "ModuleScript". A ModuleScript doesn't run on its own. Other
	scripts load it with `require(...)` and get back whatever it `return`s
	at the bottom (here, the `CrewConfig` table).

	It lives in ReplicatedStorage, so both the server AND players' computers
	can read it. That matters later, when the on-screen UI needs crew colours.

	FAIRNESS RULE: every number that makes one crew different from another
	lives in this file, so you can tune balance here without hunting
	through other scripts.
]]

-- A "table" is Luau's all-purpose container. `{}` makes an empty one.
local CrewConfig = {}

-- Crews that are actually playable right now. To switch to 4 crews later,
-- add "BarrowBoys" and "TowerBlockTerrors" to this list. Nothing else changes.
CrewConfig.ActiveCrews = { "MudlarkMob", "BlackCabBrawlers" }

-- The most players any one crew can have.
CrewConfig.MaxCrewSize = 6

-- The Police are their own team, not a crew, so they have their own cap.
-- Your game's server size (set on the Roblox website) should be no bigger
-- than MaxCrewSize × number of active crews + Police.MaxSize.
-- Right now that's 6 × 2 + 4 = 16.
CrewConfig.Police = {
	DisplayName = "Police",
	TeamColor = BrickColor.new("Navy blue"),
	MaxSize = 4,
}

-- Perk strengths. 0.05 means 5%. Keep them all equal for fairness.
-- Step 1 doesn't use these yet. Each one gets wired up when its system
-- (respawning, movement, income, defences) is built.
CrewConfig.PerkStrength = {
	FasterRespawn = 0.05, -- Mudlark Mob: respawn 5% sooner
	TravelSpeed = 0.05, -- Black Cab Brawlers: +5% speed between districts (not in combat)
	DistrictIncome = 0.05, -- Barrow Boys: +5% income from held districts
	DefenceDiscount = 0.05, -- Tower Block Terrors: defences cost 5% less
}

-- Every crew, keyed by an ID with no spaces (code uses the ID; players see DisplayName).
-- TeamColor must be a BrickColor. Roblox uses it to match each team to its
-- SpawnLocation, so no two crews may share one.
CrewConfig.Crews = {
	MudlarkMob = {
		DisplayName = "Mudlark Mob",
		TeamColor = BrickColor.new("Teal"), -- murky river water
		Perk = "FasterRespawn",
		Tagline = "Whatever the river coughs up, we keep.",
	},
	BlackCabBrawlers = {
		DisplayName = "Black Cab Brawlers",
		TeamColor = BrickColor.new("New Yeller"), -- taxi yellow
		Perk = "TravelSpeed",
		Tagline = "Where to, guv? Your district.",
	},
	BarrowBoys = {
		DisplayName = "Barrow Boys",
		TeamColor = BrickColor.new("Bright red"), -- market-stall awnings
		Perk = "DistrictIncome",
		Tagline = "Lovely jubbly. Now hand it over.",
	},
	TowerBlockTerrors = {
		DisplayName = "Tower Block Terrors",
		TeamColor = BrickColor.new("Neon orange"), -- hi-vis on concrete grey
		Perk = "DefenceDiscount",
		Tagline = "We've got the high ground. All twenty floors of it.",
	},
}

return CrewConfig
