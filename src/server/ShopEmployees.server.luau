--[[
	ShopEmployees (server script)
	=============================
	Puts a shop employee on every part tagged "ShopEmployee", and lets
	players talk to them or rob them.

	Each employee has two prompts:
	  [E] Talk  -- a friendly chat (the Police also get to ask for tips)
	  [F] Rob   -- hold it to start a robbery (crews only)

	Both run a dialogue script from ShopConfig. The player picks replies
	on screen (the ShopDialogueUI client script draws that), and this
	script decides what happens. Players can't cheat by sending fake
	choices, because every choice is checked here on the server.

	To add an employee to any shop you built yourself:
	  1. Insert a small Part where they should stand, facing the counter.
	  2. In Properties > Tags, add the tag:  ShopEmployee
	  3. Optional: add attributes ShopName (e.g. "the corner shop")
	     and EmployeeName (e.g. "Dave").
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrewConfig = require(ReplicatedStorage.Shared.CrewConfig)
local ShopConfig = require(script.Parent.ShopConfig)
local Cash = require(script.Parent.Cash)

local TAG = "ShopEmployee"
local POLICE_ID = "Police"

-- A RemoteEvent is a two-way message line between the server and each
-- player's computer. The ShopDialogueUI script listens on this one.
local remote = Instance.new("RemoteEvent")
remote.Name = "ShopDialogue"
remote.Parent = ReplicatedStorage

local random = Random.new()

-- Who is talking to whom. Keyed by Player; each value is a table
-- describing that conversation.
local conversations = {}

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------
local function now()
	return workspace:GetServerTimeNow() -- seconds, the same on every server clock
end

local function isPolice(player)
	return player:GetAttribute("CrewId") == POLICE_ID
end

-- Is the player close enough to the employee to keep talking?
local function isNear(player, employee)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return false
	end
	return (root.Position - employee.root.Position).Magnitude <= ShopConfig.TalkDistance
end

-- Swaps {shop}, {name} and any `extra` placeholders in a line of text.
local function fill(text, employee, extra)
	local values = { shop = employee.shopName, name = employee.name }
	for key, value in extra or {} do
		values[key] = value
	end
	-- "{(%w+)}" finds a word in curly brackets. Returning nil keeps it as is.
	return (string.gsub(text, "{(%w+)}", function(key)
		return values[key]
	end))
end

-- Shows a pop-up message at the top of one player's screen.
local function notice(player, text)
	remote:FireClient(player, "notice", text)
end

-- Shows one line from the employee with no replies (not a conversation).
local function sayOnce(player, employee, text)
	remote:FireClient(player, "show", { speaker = employee.name, text = fill(text, employee), options = {} })
end

-- Turns the employee to look at a player (or back to their normal spot).
local function face(employee, player)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		employee.model:PivotTo(employee.home)
		return
	end
	local from = employee.home.Position
	local target = Vector3.new(root.Position.X, from.Y, root.Position.Z)
	if (target - from).Magnitude > 0.1 then
		employee.model:PivotTo(CFrame.lookAt(from, target))
	end
end

------------------------------------------------------------------------
-- Conversations
------------------------------------------------------------------------
local function endConversation(player)
	local convo = conversations[player]
	if convo == nil then
		return
	end
	conversations[player] = nil

	local employee = convo.employee
	if employee.busyWith == player then
		employee.busyWith = nil
	end
	face(employee, nil)
end

local function alertPolice(employee)
	for _, player in Players:GetPlayers() do
		if isPolice(player) then
			notice(player, fill("ALERT: Robbery in progress at {shop}!", employee))
		end
	end
end

-- The robber has to stay close while the till is emptied, which gives
-- the Police time to arrive.
local function emptyTill(player, employee, amount)
	employee.busyWith = player
	notice(player, "Emptying the till... stay close for " .. ShopConfig.Robbery.TillSeconds .. " seconds!")

	-- task.spawn runs this in the background, so the rest of the game
	-- keeps going while we count down.
	task.spawn(function()
		for _ = 1, ShopConfig.Robbery.TillSeconds do
			task.wait(1)
			if player.Parent == nil or not isNear(player, employee) then
				employee.busyWith = nil
				if player.Parent then
					notice(player, "You left before the till was empty. You got nothing!")
				end
				return
			end
		end
		employee.busyWith = nil
		Cash.add(player, amount)
		notice(player, "You got £" .. amount .. "! Now leg it before the Police turn up.")
	end)
end

-- Called when a conversation reaches a node with no replies.
local function finish(player, convo, outcome)
	local employee = convo.employee
	endConversation(player)

	if convo.mode ~= "Robbery" then
		return
	end

	local robbery = ShopConfig.Robbery
	if outcome == "success" or outcome == "partial" or outcome == "fail" then
		-- The shop can't be robbed again for a while.
		employee.cooldownUntil = now() + robbery.CooldownSeconds
	end

	if outcome == "success" then
		emptyTill(player, employee, robbery.Payout)
	elseif outcome == "partial" then
		emptyTill(player, employee, math.floor(robbery.Payout * robbery.PartialShare))
	elseif outcome == "fail" then
		notice(player, "The robbery failed. You got nothing!")
	end
	-- "abort": nothing happens, and the shop stays open for business.
end

-- Sends the current node to the player, or finishes if it has no replies.
local function sendNode(player, convo)
	local employee = convo.employee
	local node = convo.dialogue[convo.nodeName]
	if node == nil then
		warn("[ShopEmployees] Dialogue node '" .. tostring(convo.nodeName) .. "' doesn't exist. Check ShopConfig.")
		endConversation(player)
		remote:FireClient(player, "close")
		return
	end

	local text = node.text
	local extra = nil
	if convo.nodeName == "policeTip" then
		local last = employee.lastRobbery
		if last then
			local crew = CrewConfig.Crews[last.crewId]
			text = ShopConfig.PoliceTipRobbery
			extra = { crew = if crew then crew.DisplayName else "some crew" }
		else
			text = ShopConfig.PoliceTipNoRobbery
		end
	end

	-- Only show replies this player is allowed to pick.
	local visible = {}
	local labels = {}
	for _, option in node.options or {} do
		if not option.policeOnly or isPolice(player) then
			table.insert(visible, option)
			table.insert(labels, option.text)
		end
	end
	convo.visibleOptions = visible

	remote:FireClient(player, "show", { speaker = employee.name, text = fill(text, employee, extra), options = labels })

	if #visible == 0 then
		finish(player, convo, node.outcome)
	end
end

local function startConversation(employee, player, mode)
	if conversations[player] then
		return -- already talking to someone
	end
	if employee.busyWith and employee.busyWith ~= player then
		notice(player, fill(ShopConfig.Lines.Busy, employee))
		return
	end

	employee.busyWith = player
	local convo = {
		employee = employee,
		mode = mode,
		dialogue = if mode == "Robbery" then ShopConfig.RobberyScript else ShopConfig.ChatScript,
		nodeName = "start",
		visibleOptions = {},
	}
	conversations[player] = convo
	face(employee, player)
	sendNode(player, convo)
end

local function startRobbery(employee, player)
	local teamId = player:GetAttribute("CrewId")
	if teamId == nil then
		sayOnce(player, employee, ShopConfig.Lines.NoCrew)
	elseif teamId == POLICE_ID then
		sayOnce(player, employee, ShopConfig.Lines.PoliceCantRob)
	elseif employee.busyWith and employee.busyWith ~= player then
		notice(player, fill(ShopConfig.Lines.Busy, employee))
	elseif now() < employee.cooldownUntil then
		sayOnce(player, employee, ShopConfig.Lines.OnCooldown)
	else
		employee.lastRobbery = { crewId = teamId }
		alertPolice(employee)
		startConversation(employee, player, "Robbery")
	end
end

-- A player clicked a reply (or "Leave") on their screen.
remote.OnServerEvent:Connect(function(player, action, index)
	local convo = conversations[player]
	if convo == nil then
		return
	end

	if action == "leave" then
		endConversation(player)
		return
	end

	-- Never trust what a player's computer sends: check it all.
	if action ~= "choose" or typeof(index) ~= "number" then
		return
	end
	local option = convo.visibleOptions[index]
	if option == nil then
		return
	end
	if not isNear(player, convo.employee) then
		endConversation(player)
		remote:FireClient(player, "close")
		return
	end

	local nextName = option.next
	if option.chance and random:NextNumber() >= option.chance then
		nextName = option.failNext
	end
	convo.nodeName = nextName
	sendNode(player, convo)
end)

-- End a conversation if the player walks away or leaves the game.
Players.PlayerRemoving:Connect(endConversation)
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, convo in conversations do
			if not isNear(player, convo.employee) then
				endConversation(player)
				remote:FireClient(player, "close")
			end
		end
	end
end)

------------------------------------------------------------------------
-- Creating employees
------------------------------------------------------------------------
local function makePrompt(parent, actionText, objectText, key, gamepadKey)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = gamepadKey
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false -- the counter shouldn't block it
	prompt.Parent = parent
	return prompt
end

local function createEmployee(spot)
	if not spot:IsA("BasePart") then
		warn("[ShopEmployees] '" .. spot:GetFullName() .. "' is tagged ShopEmployee but isn't a Part.")
		return
	end

	local name = spot:GetAttribute("EmployeeName") or ShopConfig.Names[random:NextInteger(1, #ShopConfig.Names)]
	local shopName = spot:GetAttribute("ShopName") or "the shop"

	-- A HumanoidDescription describes how a character looks. Roblox builds
	-- a full character (an R15 "rig") from it for us.
	local description = Instance.new("HumanoidDescription")
	local skin = ShopConfig.SkinTones[random:NextInteger(1, #ShopConfig.SkinTones)]
	description.HeadColor = skin
	description.TorsoColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.LeftLegColor = skin
	description.RightLegColor = skin
	description.Shirt = ShopConfig.UniformShirtId
	description.Pants = ShopConfig.UniformPantsId

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[ShopEmployees] Couldn't create an employee: " .. tostring(model))
		return
	end

	model.Name = name
	model:SetAttribute("IsShopEmployee", true)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- employees can't be knocked out

	-- Anchor the root so the employee stays put behind the counter.
	local root = model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true

	-- Hide the marker and stand the employee on it, facing the same way.
	spot.Transparency = 1
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	local feet = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0)
	local home = feet * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	model:PivotTo(home)
	model.Parent = spot.Parent

	local employee = {
		name = name,
		shopName = shopName,
		model = model,
		root = root,
		home = home,
		busyWith = nil, -- the player they're dealing with, if any
		cooldownUntil = 0, -- when they can be robbed again
		lastRobbery = nil, -- which crew robbed them last (for Police tips)
	}

	local talkPrompt = makePrompt(root, "Talk", name, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	local robPrompt = makePrompt(root, "Rob", shopName, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	robPrompt.HoldDuration = ShopConfig.Robbery.HoldSeconds
	robPrompt.UIOffset = Vector2.new(0, 80) -- draw it below the Talk prompt

	talkPrompt.Triggered:Connect(function(player)
		startConversation(employee, player, "Chat")
	end)
	robPrompt.Triggered:Connect(function(player)
		startRobbery(employee, player)
	end)
end

-- Make employees for every marker already in the game, and any added later.
-- (task.spawn because building a character takes a moment.)
for _, spot in CollectionService:GetTagged(TAG) do
	task.spawn(createEmployee, spot)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(spot)
	task.spawn(createEmployee, spot)
end)
