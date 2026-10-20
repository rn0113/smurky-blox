--[[
	CrewAssignment (server script)
	==============================
	Runs once when a server starts. It:
	  1. Creates one Roblox "Team" for each active crew, plus the Police.
	  2. Puts each player who joins into the team that is the LEAST full.
	  3. Warns you in the Output window if a team has no spawn point yet.

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

-- The ID the Police team uses wherever a crew would use its crew ID.
local POLICE_ID = "Police"

-- Every team players can join, in one list. Each entry remembers its ID,
-- its Team object and how many players it can hold.
local joinableTeams = {}

------------------------------------------------------------------------
-- 0. Check the config for mistakes
------------------------------------------------------------------------
-- A typo in CrewConfig would otherwise cause a confusing error further
-- down (or silently break spawning). `error(...)` stops this script and
-- shows the message in red in the Output window, so you know exactly
-- what to fix.
local usedColors = {} -- colour name -> ID of the team that already uses it

local function claimColor(id, teamColor)
	-- Two teams with the same TeamColor would share spawn points.
	local colorName = teamColor.Name
	if usedColors[colorName] then
		error("[CrewAssignment] " .. id .. " and " .. usedColors[colorName] .. " both use TeamColor '" .. colorName .. "'. Every team needs its own colour.")
	end
	usedColors[colorName] = id
end

for _, crewId in CrewConfig.ActiveCrews do
	local crew = CrewConfig.Crews[crewId]
	if crew == nil then
		error("[CrewAssignment] ActiveCrews lists '" .. crewId .. "', but CrewConfig.Crews has no crew with that ID. Check the spelling.")
	end

	if CrewConfig.PerkStrength[crew.Perk] == nil then
		error("[CrewAssignment] " .. crewId .. " has Perk '" .. tostring(crew.Perk) .. "', which isn't in CrewConfig.PerkStrength.")
	end

	claimColor(crewId, crew.TeamColor)
end
claimColor(POLICE_ID, CrewConfig.Police.TeamColor)

------------------------------------------------------------------------
-- 1. Create the teams
------------------------------------------------------------------------
local function createTeam(id, displayName, teamColor, maxSize)
	local team = Instance.new("Team") -- make a brand-new Team object
	team.Name = displayName -- the name shown on the leaderboard
	team.TeamColor = teamColor
	team.AutoAssignable = false -- WE choose teams, not Roblox's random picker
	team:SetAttribute("CrewId", id) -- a hidden label other scripts can read
	team.Parent = Teams -- putting it in Teams makes it "real"

	-- `{ key = value }` makes a table with named fields.
	table.insert(joinableTeams, { id = id, team = team, maxSize = maxSize })
end

-- `for _, crewId in list do` loops over the list one item at a time.
-- `_` is a placeholder for the position number, which we don't need.
for _, crewId in CrewConfig.ActiveCrews do
	local crew = CrewConfig.Crews[crewId]
	createTeam(crewId, crew.DisplayName, crew.TeamColor, CrewConfig.MaxCrewSize)
end

local police = CrewConfig.Police
createTeam(POLICE_ID, police.DisplayName, police.TeamColor, police.MaxSize)

------------------------------------------------------------------------
-- 2. Pick the least-full team
------------------------------------------------------------------------
-- Teams have different caps (crews hold 6, Police hold 4), so we compare
-- how FULL each team is, not just how many players it has. 3 of 6 is
-- half full; 2 of 4 is also half full. That keeps the Police filling up
-- at the same pace as the crews.
--
-- A "function" is a reusable chunk of code. This one returns the Team a
-- new player should join, or nil (Luau's word for "nothing") if every
-- team is full.
local function pickTeamForNewPlayer()
	local lowestFill = math.huge -- start with "infinity" so anything is lower
	local candidates = {} -- teams tied for least full

	for _, entry in joinableTeams do
		local size = #entry.team:GetPlayers() -- `#` means "how many items in this list"

		if size < entry.maxSize then
			local fill = size / entry.maxSize -- 0 = empty, 1 = full
			if fill < lowestFill then
				-- New record for least full: start a fresh list.
				lowestFill = fill
				candidates = { entry.team }
			elseif fill == lowestFill then
				-- A tie: add it to the list.
				table.insert(candidates, entry.team)
			end
		end
	end

	if #candidates == 0 then
		return nil -- every team is full
	end

	-- On a tie, pick one at random so no team always gets the first player.
	return candidates[math.random(1, #candidates)]
end

------------------------------------------------------------------------
-- 3. Assign players as they join
------------------------------------------------------------------------
local function onPlayerAdded(player)
	-- Skip anyone who already has a team. A player who joins just as this
	-- script starts can reach this function twice (once from the event,
	-- once from the loop at the bottom), and we don't want to move them.
	if player:GetAttribute("CrewId") ~= nil then
		return
	end

	local team = pickTeamForNewPlayer()

	if team == nil then
		-- This shouldn't happen if the server size matches the team caps.
		warn("[CrewAssignment] Every team is full. " .. player.Name .. " has no team.")
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
-- Helpful check: does every team have a spawn point?
------------------------------------------------------------------------
-- Roblox spawns a player at a SpawnLocation whose TeamColor matches
-- their team's colour, as long as that SpawnLocation's "Neutral" box is
-- unticked. If none matches, players spawn somewhere random. This check
-- tells you when that would happen.
for _, entry in joinableTeams do
	local team = entry.team
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
