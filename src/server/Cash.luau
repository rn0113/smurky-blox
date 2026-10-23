--[[
	Cash
	====
	Keeps track of each player's money and shows it on the leaderboard
	(the list of players in the top-right corner).

	Roblox shows any values inside a Folder called "leaderstats" on the
	player as leaderboard columns. That's all this does.

	Note: cash isn't saved yet. It resets when the player leaves. Saving it
	(with a DataStore) is a later step.
]]

local Players = game:GetService("Players")

local Cash = {}

-- Finds the player's Cash value, creating it if it isn't there yet.
local function getValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats" -- this exact name is what Roblox looks for
		leaderstats.Parent = player
	end

	local value = leaderstats:FindFirstChild("Cash")
	if value == nil then
		value = Instance.new("IntValue") -- a whole number
		value.Name = "Cash"
		value.Value = 0
		value.Parent = leaderstats
	end
	return value
end

function Cash.get(player)
	return getValue(player).Value
end

function Cash.add(player, amount)
	local value = getValue(player)
	value.Value += amount -- `+=` means "add to what's already there"
end

-- Give everyone a Cash column as soon as they join, so it shows from the start.
-- This runs once, the first time any script requires this module.
Players.PlayerAdded:Connect(getValue)
for _, player in Players:GetPlayers() do
	getValue(player)
end

return Cash
