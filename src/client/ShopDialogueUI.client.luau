--[[
	ShopDialogueUI (client script)
	==============================
	Draws the conversation panel when you talk to (or rob) a shop
	employee, and the pop-up messages at the top of the screen.

	This runs on each player's own computer. It only DRAWS things and
	tells the server which reply was clicked. The ShopEmployees server
	script decides what actually happens.

	Replies can be clicked/tapped, or picked with the number keys 1-6.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("ShopDialogue")

-- Colours and fonts, matching the dark, brass-trimmed look of the shops.
local PANEL_COLOR = Color3.fromRGB(18, 19, 23)
local BUTTON_COLOR = Color3.fromRGB(34, 36, 42)
local TEXT_COLOR = Color3.fromRGB(240, 240, 236)
local MUTED_COLOR = Color3.fromRGB(160, 162, 170)
local BRASS = Color3.fromRGB(196, 168, 108)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json")
local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }

------------------------------------------------------------------------
-- Build the screen pieces once
------------------------------------------------------------------------
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function padding(parent, pixels)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, pixels)
	p.PaddingBottom = UDim.new(0, pixels)
	p.PaddingLeft = UDim.new(0, pixels)
	p.PaddingRight = UDim.new(0, pixels)
	p.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShopDialogue"
gui.ResetOnSpawn = false -- keep it when the player respawns
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

-- The conversation panel along the bottom of the screen.
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -24)
panel.Size = UDim2.new(0.92, 0, 0, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y -- grows to fit the text
panel.BackgroundColor3 = PANEL_COLOR
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
corner(panel, 12)
padding(panel, 16)

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(640, math.huge) -- not too wide on big screens
sizeLimit.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = BRASS
stroke.Transparency = 0.5
stroke.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local speaker = Instance.new("TextLabel")
speaker.LayoutOrder = 1
speaker.Size = UDim2.new(1, 0, 0, 20)
speaker.BackgroundTransparency = 1
speaker.FontFace = FONT_BOLD
speaker.TextSize = 16
speaker.TextColor3 = BRASS
speaker.TextXAlignment = Enum.TextXAlignment.Left
speaker.Parent = panel

local line = Instance.new("TextLabel")
line.LayoutOrder = 2
line.Size = UDim2.new(1, 0, 0, 0)
line.AutomaticSize = Enum.AutomaticSize.Y
line.BackgroundTransparency = 1
line.FontFace = FONT
line.TextSize = 18
line.TextColor3 = TEXT_COLOR
line.TextWrapped = true
line.TextXAlignment = Enum.TextXAlignment.Left
line.Parent = panel

local optionList = Instance.new("Frame")
optionList.LayoutOrder = 3
optionList.Size = UDim2.new(1, 0, 0, 0)
optionList.AutomaticSize = Enum.AutomaticSize.Y
optionList.BackgroundTransparency = 1
optionList.Parent = panel

local optionLayout = Instance.new("UIListLayout")
optionLayout.Padding = UDim.new(0, 6)
optionLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionLayout.Parent = optionList

-- The pop-up message near the top of the screen.
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 80)
toast.Size = UDim2.new(0.9, 0, 0, 0)
toast.AutomaticSize = Enum.AutomaticSize.Y
toast.BackgroundColor3 = PANEL_COLOR
toast.FontFace = FONT_BOLD
toast.TextSize = 18
toast.TextColor3 = TEXT_COLOR
toast.TextWrapped = true
toast.Visible = false
toast.Parent = gui
corner(toast, 10)
padding(toast, 12)

local toastLimit = Instance.new("UISizeConstraint")
toastLimit.MaxSize = Vector2.new(520, math.huge)
toastLimit.Parent = toast

------------------------------------------------------------------------
-- Showing and hiding
------------------------------------------------------------------------
-- Each new line gets a number. Older timers check it so they don't hide
-- or overwrite a newer line.
local showCount = 0
local currentChoices = {} -- functions for the number keys

local function hidePanel()
	showCount += 1
	panel.Visible = false
	currentChoices = {}
end

local function clearOptions()
	currentChoices = {}
	for _, child in optionList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function addButton(order, text, color, onClick)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 0)
	button.AutomaticSize = Enum.AutomaticSize.Y
	button.BackgroundColor3 = BUTTON_COLOR
	button.FontFace = FONT
	button.TextSize = 17
	button.TextColor3 = color
	button.TextWrapped = true
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = text
	button.Parent = optionList
	corner(button, 8)
	padding(button, 10)
	button.Activated:Connect(onClick) -- works for mouse, touch and gamepad
end

-- Reveals the text a few letters at a time, like someone speaking.
local function typeOut(text, myCount)
	line.Text = text
	local total = utf8.len(text) or #text
	for shown = 1, total do
		if showCount ~= myCount then
			return -- a newer line replaced this one
		end
		line.MaxVisibleGraphemes = shown
		task.wait(0.018)
	end
	line.MaxVisibleGraphemes = -1 -- -1 means "show everything"
end

local function showLine(data)
	showCount += 1
	local myCount = showCount

	panel.Visible = true
	speaker.Text = data.speaker
	line.MaxVisibleGraphemes = 0
	task.spawn(typeOut, data.text, myCount)
	clearOptions()

	for index, label in data.options do
		local function choose()
			clearOptions() -- stop double-clicks sending twice
			remote:FireServer("choose", index)
		end
		addButton(index, index .. ".  " .. label, TEXT_COLOR, choose)
		currentChoices[index] = choose
	end

	if #data.options > 0 then
		addButton(100, "Leave", MUTED_COLOR, function()
			remote:FireServer("leave")
			hidePanel()
		end)
	else
		-- The conversation is over: offer a Close button, and close by
		-- itself after a few seconds.
		addButton(100, "Close", MUTED_COLOR, hidePanel)
		task.delay(5, function()
			if showCount == myCount then
				hidePanel()
			end
		end)
	end
end

local toastCount = 0
local function showToast(text)
	toastCount += 1
	local myCount = toastCount
	toast.Text = text
	toast.BackgroundTransparency = 0.08
	toast.TextTransparency = 0
	toast.Visible = true

	task.delay(4, function()
		if toastCount ~= myCount then
			return
		end
		-- Fade out smoothly over half a second.
		local fade = TweenInfo.new(0.5)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.5)
		if toastCount == myCount then
			toast.Visible = false
		end
	end)
end

------------------------------------------------------------------------
-- Listen to the server and the keyboard
------------------------------------------------------------------------
remote.OnClientEvent:Connect(function(action, data)
	if action == "show" then
		showLine(data)
	elseif action == "close" then
		hidePanel()
	elseif action == "notice" then
		showToast(data)
	end
end)

UserInputService.InputBegan:Connect(function(input, typingInChat)
	if typingInChat or not panel.Visible then
		return
	end
	for index, key in NUMBER_KEYS do
		if input.KeyCode == key and currentChoices[index] then
			currentChoices[index]()
		end
	end
end)
