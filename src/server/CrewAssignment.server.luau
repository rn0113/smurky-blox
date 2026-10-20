--[[
	CrewAssignment (server script)
	==============================
	Runs once when a server starts. It:
	  1. Creates one Roblox "Team" for each active crew.
	  2. Puts each player who joins into the crew with the FEWEST players.
	  3. Warns you in the Output window if a crew has no spawn point yet.

	The ".server.luau" ending tells Script Sync to make this a normal Script
	(server-side). Server scripts run on Roblox's computers, not players'
	machines, so players can't tamper with them. That's why team choice
	happens here.

	Later steps will also weigh player rank when balancing. There are no
	ranks yet, so for now this only counts heads.
]]

-- "Services" are Roblox's built-in systems. GetService fetches one.
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load the crew settings. `ReplicatedStorage.Shared` is the folder synced
-- from src/shared, and CrewConfig is the module inside it.
local CrewConfig = require(ReplicatedStorage.Shared.CrewConfig)

-- We'll remember which Team object belongs to which crew ID.
local teamsByCrewId = {}

------------------------------------------------------------------------
-- 0. Check the config for mistakes
------------------------------------------------------------------------
-- A typo in CrewConfig would otherwise cause a confusing error further
-- down (or silently break spawning). `error(...)` stops this script and
-- shows the message in red in the Output window, so you know exactly
-- what to fix.
local usedColors = {} -- colour name -> crew ID that already uses it

for _, crewId in CrewConfig.ActiveCrews do
	local crew = CrewConfig.Crews[crewId]
	if crew == nil then
		error("[CrewAssignment] ActiveCrews lists '" .. crewId .. "', but CrewConfig.Crews has no crew with that ID. Check the spelling.")
	end

	if CrewConfig.PerkStrength[crew.Perk] == nil then
		error("[CrewAssignment] " .. crewId .. " has Perk '" .. tostring(crew.Perk) .. "', which isn't in CrewConfig.PerkStrength.")
	end

	-- Two crews with the same TeamColor would share spawn points.
	local colorName = crew.TeamColor.Name
	if usedColors[colorName] then
		error("[CrewAssignment] " .. crewId .. " and " .. usedColors[colorName] .. " both use TeamColor '" .. colorName .. "'. Every crew needs its own colour.")
	end
	usedColors[colorName] = crewId
end

------------------------------------------------------------------------
-- 1. Create the teams
------------------------------------------------------------------------
-- `for _, crewId in list do` loops over the list one item at a time.
-- `_` is a placeholder for the position number, which we don't need.
for _, crewId in CrewConfig.ActiveCrews do
	local crew = CrewConfig.Crews[crewId]

	local team = Instance.new("Team") -- make a brand-new Team object
	team.Name = crew.DisplayName -- the name shown on the leaderboard
	team.TeamColor = crew.TeamColor
	team.AutoAssignable = false -- WE choose teams, not Roblox's random picker
	team:SetAttribute("CrewId", crewId) -- a hidden label other scripts can read
	team.Parent = Teams -- putting it in Teams makes it "real"

	teamsByCrewId[crewId] = team
end

------------------------------------------------------------------------
-- 2. Pick the smallest crew
------------------------------------------------------------------------
-- A "function" is a reusable chunk of code. This one returns the Team a
-- new player should join, or nil (Luau's word for "nothing") if every
-- crew is full.
local function pickCrewForNewPlayer()
	local smallestSize = math.huge -- start with "infinity" so anything is smaller
	local candidates = {} -- crews tied for smallest

	for _, crewId in CrewConfig.ActiveCrews do
		local team = teamsByCrewId[crewId]
		local size = #team:GetPlayers() -- `#` means "how many items in this list"

		if size < CrewConfig.MaxCrewSize then
			if size < smallestSize then
				-- New record for smallest crew: start a fresh list.
				smallestSize = size
				candidates = { team }
			elseif size == smallestSize then
				-- A tie: add it to the list.
				table.insert(candidates, team)
			end
		end
	end

	if #candidates == 0 then
		return nil -- every crew is full
	end

	-- On a tie, pick one at random so no crew always gets the first player.
	return candidates[math.random(1, #candidates)]
end

------------------------------------------------------------------------
-- 3. Assign players as they join
------------------------------------------------------------------------
local function onPlayerAdded(player)
	-- Skip anyone who already has a crew. A player who joins just as this
	-- script starts can reach this function twice (once from the event,
	-- once from the loop at the bottom), and we don't want to move them.
	if player:GetAttribute("CrewId") ~= nil then
		return
	end

	local team = pickCrewForNewPlayer()

	if team == nil then
		-- This shouldn't happen if the server size matches the crew caps.
		warn("[CrewAssignment] Every crew is full. " .. player.Name .. " has no crew.")
		return
	end

	player.Team = team
	player:SetAttribute("CrewId", team:GetAttribute("CrewId"))
	-- `..` joins pieces of text together.
	print("[CrewAssignment] " .. player.Name .. " joined " .. team.Name)
end

-- Run onPlayerAdded every time someone joins from now on...
Players.PlayerAdded:Connect(onPlayerAdded)

-- ...and also for anyone who joined before this script started.
-- (This happens in Studio testing, where you can join very quickly.)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

------------------------------------------------------------------------
-- Helpful check: does every crew have a spawn point?
------------------------------------------------------------------------
-- Roblox spawns a player at a SpawnLocation whose TeamColor matches
-- their team's colour, as long as that SpawnLocation's "Neutral" box is
-- unticked. If none matches, players spawn somewhere random. This check
-- tells you when that would happen.
for _, team in teamsByCrewId do
	local found = false
	for _, object in workspace:GetDescendants() do
		if object:IsA("SpawnLocation") and not object.Neutral and object.TeamColor == team.TeamColor then
			found = true
			break -- stop searching, we found one
		end
	end
	if not found then
		warn(
			"[CrewAssignment] No spawn point for "
				.. team.Name
				.. ". Add a SpawnLocation with TeamColor '"
				.. team.TeamColor.Name
				.. "' and untick Neutral."
		)
	end
end
