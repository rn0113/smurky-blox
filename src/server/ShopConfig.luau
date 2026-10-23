--[[
	ShopConfig
	==========
	Everything about shop employees in one place: their names, what they
	say, and how robberies pay out. The ShopEmployees script reads this.

	It lives on the server (not in Shared) so players can't peek at the
	payout numbers or the odds.

	HOW THE DIALOGUE SCRIPTS WORK
	-----------------------------
	A conversation is a set of "nodes". Each node is one thing the employee
	says, plus the replies the player can pick:

	  nodeName = {
	      text = "What the employee says.",
	      options = {
	          { text = "What the player says", next = "anotherNode" },
	      },
	  }

	Every conversation starts at the node called `start`.
	In `text`, {shop} becomes the shop's name and {name} the employee's name.

	Extras an option can have:
	  chance = 0.6, failNext = "otherNode"  -- 60% go to `next`, otherwise to `failNext`
	  policeOnly = true                     -- only Police players see this reply

	A node with no options ends the conversation. In a robbery, an ending
	node also has an `outcome`:
	  "success"  -- the player empties the till (full payout)
	  "partial"  -- the player gets a smaller payout
	  "fail"     -- the player gets nothing
	  "abort"    -- the player backed out; the shop isn't put on cooldown
]]

local ShopConfig = {}

------------------------------------------------------------------------
-- Robbery numbers
------------------------------------------------------------------------
-- FAIRNESS RULE: payouts are the same for every crew.
-- (The Barrow Boys' perk is for district income, not robberies.)
ShopConfig.Robbery = {
	Payout = 250, -- cash for a "success"
	PartialShare = 0.4, -- a "partial" pays 40% of Payout
	TillSeconds = 6, -- how long the robber must stay while the till is emptied
	CooldownSeconds = 180, -- how long before the same shop can be robbed again
	HoldSeconds = 1.5, -- how long to hold the Rob key, so it can't happen by accident
}

-- How close (in studs) a player must stay to keep talking.
ShopConfig.TalkDistance = 14

------------------------------------------------------------------------
-- Employees
------------------------------------------------------------------------
-- Each employee gets a random name from this list, unless the marker
-- part has an "EmployeeName" attribute.
ShopConfig.Names = { "Dave", "Bev", "Kev", "Tamsin", "Raj", "Shaz", "Clive", "Dot", "Femi", "Gaz" }

-- Skin tones picked at random for each employee.
ShopConfig.SkinTones = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 192, 160),
	Color3.fromRGB(198, 145, 110),
	Color3.fromRGB(160, 110, 80),
	Color3.fromRGB(110, 72, 50),
	Color3.fromRGB(78, 52, 38),
}

-- Shop uniform: a Shirt and Pants asset ID (0 = the default plain look).
-- See OutfitConfig for how to find an asset ID.
ShopConfig.UniformShirtId = 0
ShopConfig.UniformPantsId = 0

------------------------------------------------------------------------
-- Dialogue: just chatting (the "Talk" prompt)
------------------------------------------------------------------------
ShopConfig.ChatScript = {
	start = {
		text = "Alright? Welcome to {shop}. What can I do you for?",
		options = {
			{ text = "Just browsing.", next = "browse" },
			{ text = "How's business?", next = "business" },
			{ text = "Seen anything suspicious?", next = "policeTip", policeOnly = true },
			{ text = "See you later.", next = "bye" },
		},
	},
	browse = {
		text = "No worries. Give us a shout if you need anything.",
	},
	business = {
		text = "Quiet. Too quiet. Someone's always trying to nick the till round here.",
		options = {
			{ text = "Sounds rough. Chin up.", next = "bye" },
		},
	},
	-- The ShopEmployees script fills in this node's text itself, using
	-- what it knows about the last robbery at this shop.
	policeTip = {
		text = "",
	},
	bye = {
		text = "Ta-ra! Mind how you go.",
	},
}

-- What the employee tells the Police (used by the policeTip node).
ShopConfig.PoliceTipNoRobbery = "Nothing to report, officer. Quiet as a church mouse."
ShopConfig.PoliceTipRobbery = "Yes! Someone from {crew} cleaned out the till. Went that way, sharpish!"

------------------------------------------------------------------------
-- Dialogue: a robbery (the "Rob" prompt)
------------------------------------------------------------------------
ShopConfig.RobberyScript = {
	start = {
		text = "Oh, you're having a laugh. Not again! ...Go on then, what do you want?",
		options = {
			{ text = "Open the till. Nice and calm, no heroics.", next = "firm" },
			{ text = "Fancy a cut? Ten percent and you never saw me.", next = "bribeYes", chance = 0.6, failNext = "bribeNo" },
			{ text = "Bit skint this week, mate. Help a crew out?", next = "sobStory" },
			{ text = "Actually, never mind. Sorry for the fright.", next = "backOut" },
		},
	},
	firm = {
		text = "Alright, alright! It's all yours. Just mind the display.",
		outcome = "success",
	},
	bribeYes = {
		text = "Ten percent? ...Go on then. I didn't see a thing.",
		outcome = "success",
	},
	bribeNo = {
		text = "Nice try. I've already pressed the button under the counter. Police are on their way!",
		outcome = "fail",
	},
	sobStory = {
		text = "...You know what, I've been there. Take what's in the tip jar and leave the till.",
		outcome = "partial",
	},
	backOut = {
		text = "Go on, hop it. And wipe your feet next time.",
		outcome = "abort",
	},
}

-- What the employee says in special cases.
ShopConfig.Lines = {
	Busy = "{name} is busy with someone else.",
	OnCooldown = "Already been done over today. The till's empty! Come back later.",
	PoliceCantRob = "You're the police! You can't rob me. Try the 'Talk' option.",
	NoCrew = "You're not in a crew. Who are you working for?",
}

return ShopConfig
