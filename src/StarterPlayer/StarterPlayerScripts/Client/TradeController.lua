--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Trade controller: renders the server's session snapshot, edits the local
-- offer draft (validated server-side on submit), ready/cancel, and incoming
-- request prompts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UIFactory = require(script.Parent.UIFactory)

local TradeController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tradeRemote = remotes:WaitForChild("TradeRemote")

local gui: ScreenGui
local window: Frame

function TradeController.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_Trade"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	window = UIFactory.Frame("TradeWindow", gui, UDim2.new(0, 460, 0, 340), UDim2.new(0.5, -230, 0.5, -170), Theme.Colors.BackgroundRaised)
	window.Visible = false

	UIFactory.Label("PartnerLabel", window, "", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 10), Theme.Colors.Accent, Theme.Fonts.Header, 16)

	local myPane = UIFactory.Frame("MyOffer", window, UDim2.new(0, 200, 1, -120), UDim2.new(0, 12, 0, 44), Theme.Colors.Background)
	local theirPane = UIFactory.Frame("TheirOffer", window, UDim2.new(0, 200, 1, -120), UDim2.new(1, -212, 0, 44), Theme.Colors.Background)

	UIFactory.Label("MyLabel", myPane, "YOUR OFFER", UDim2.new(1, -12, 0, 18), UDim2.new(0, 8, 0, 6), Theme.Colors.TextMuted, Theme.Fonts.Header, 11)
	UIFactory.Label("TheirLabel", theirPane, "THEIR OFFER", UDim2.new(1, -12, 0, 18), UDim2.new(0, 8, 0, 6), Theme.Colors.TextMuted, Theme.Fonts.Header, 11)

	local myItems = UIFactory.Label("MyItems", myPane, "Nothing offered", UDim2.new(1, -12, 1, -100), UDim2.new(0, 8, 0, 28), Theme.Colors.TextPrimary, Theme.Fonts.Mono, 11)
	local theirItems = UIFactory.Label("TheirItems", theirPane, "Nothing offered", UDim2.new(1, -12, 1, -100), UDim2.new(0, 8, 0, 28), Theme.Colors.TextPrimary, Theme.Fonts.Mono, 11)

	local currencyEntry = Instance.new("TextBox")
	currencyEntry.Name = "CurrencyEntry"
	currencyEntry.Size = UDim2.new(1, -12, 0, 26)
	currencyEntry.Position = UDim2.new(0, 8, 1, -70)
	currencyEntry.BackgroundColor3 = Theme.Colors.BackgroundPanel
	currencyEntry.TextColor3 = Theme.Colors.TextPrimary
	currencyEntry.PlaceholderText = "Currency to offer"
	currencyEntry.Font = Theme.Fonts.Mono
	currencyEntry.TextSize = 11
	currencyEntry.BorderSizePixel = 0
	currencyEntry.Text = "0"
	currencyEntry.Parent = myPane
	currencyEntry:AddChild(Theme.UICorner())

	local itemEntry = Instance.new("TextBox")
	itemEntry.Name = "ItemEntry"
	itemEntry.Size = UDim2.new(0, 130, 0, 26)
	itemEntry.Position = UDim2.new(0, 8, 1, -38)
	itemEntry.BackgroundColor3 = Theme.Colors.BackgroundPanel
	itemEntry.TextColor3 = Theme.Colors.TextPrimary
	itemEntry.PlaceholderText = "Item id"
	itemEntry.Font = Theme.Fonts.Mono
	itemEntry.TextSize = 11
	itemEntry.BorderSizePixel = 0
	itemEntry.Parent = myPane
	itemEntry:AddChild(Theme.UICorner())

	local countEntry = Instance.new("TextBox")
	countEntry.Name = "CountEntry"
	countEntry.Size = UDim2.new(0, 54, 0, 26)
	countEntry.Position = UDim2.new(1, -62, 1, -38)
	countEntry.BackgroundColor3 = Theme.Colors.BackgroundPanel
	countEntry.TextColor3 = Theme.Colors.TextPrimary
	countEntry.PlaceholderText = "Qty"
	countEntry.Font = Theme.Fonts.Mono
	countEntry.TextSize = 11
	countEntry.BorderSizePixel = 0
	countEntry.Text = "1"
	countEntry.Parent = myPane
	countEntry:AddChild(Theme.UICorner())

	-- Local offer draft; the server validates every submit.
	local draft = { currency = 0, items = {} }

	local function formatOffer(offer)
		if not offer then
			return "Nothing offered"
		end
		local lines = {}
		for _, entry in ipairs(offer.items or {}) do
			table.insert(lines, ("%s ×%d"):format(entry.id, entry.count))
		end
		if (offer.currency or 0) > 0 then
			table.insert(lines, ("%d currency"):format(offer.currency))
		end
		return if #lines > 0 then table.concat(lines, "\n") else "Nothing offered"
	end

	local function refresh()
		local payload = window:GetAttribute("LastSnapshot")
		-- Snapshot state is kept locally from events; re-render below.
	end

	local setOfferButton = UIFactory.Button("SetOfferButton", myPane, "+ Add", UDim2.new(1, -12, 0, 24), UDim2.new(0, 8, 1, -96), function()
		local itemId = itemEntry.Text
		local count = tonumber(countEntry.Text) or 0
		if itemId and #itemId > 0 and count > 0 then
			table.insert(draft.items, { id = itemId, count = count })
			myItems.Text = formatOffer(draft)
		end
	end)

	local sendOfferButton = UIFactory.Button("SendOfferButton", window, "Send Offer", UDim2.new(0, 140, 0, 30), UDim2.new(0, 12, 1, -40), function()
		draft.currency = tonumber(currencyEntry.Text) or 0
		tradeRemote:FireServer("SetOffer", draft)
	end)
	sendOfferButton.BackgroundColor3 = Theme.Colors.AccentDark

	local readyButton = UIFactory.Button("ReadyButton", window, "Ready", UDim2.new(0, 140, 0, 30), UDim2.new(0.5, -70, 1, -40), function()
		tradeRemote:FireServer("SetReady", { ready = true })
	end)
	readyButton.BackgroundColor3 = Theme.Colors.Success

	local cancelButton = UIFactory.Button("CancelButton", window, "Cancel", UDim2.new(0, 140, 0, 30), UDim2.new(1, -152, 1, -40), function()
		tradeRemote:FireServer("Cancel", {})
		window.Visible = false
	end)
	cancelButton.BackgroundColor3 = Theme.Colors.Danger

	tradeRemote.OnClientEvent:Connect(function(action, payload)
		if action == "TradeUpdated" and type(payload) == "table" then
			window.Visible = true
			local partnerLabel = window:FindFirstChild("PartnerLabel")
			if partnerLabel then
				partnerLabel.Text = ("TRADING WITH %s"):format(string.upper(payload.partnerName or "?"))
			end
			myItems.Text = formatOffer(payload)
			theirItems.Text = formatOffer({ items = payload.theirItems, currency = payload.theirCurrency })

			readyButton.Text = if payload.myReady then "READY ✓" else "Ready"
			readyButton.TextColor3 = if payload.locked then Theme.Colors.TextMuted else Theme.Colors.TextPrimary
			sendOfferButton.Text = if payload.locked then "LOCKED" else "Send Offer"

			if payload.locked then
				sendOfferButton.Active = false
				cancelButton.Active = false
			else
				sendOfferButton.Active = true
				cancelButton.Active = true
			end

			-- Reset the local draft whenever the server confirms a change.
			draft = { currency = tonumber(currencyEntry.Text) or 0, items = {} }
		elseif action == "TradeRequestReceived" and type(payload) == "table" then
			local requestPrompt = UIFactory.Window("TradeRequest", gui, "TRADE REQUEST", UDim2.new(0, 320, 0, 140), UDim2.new(0.5, -160, 0.5, -70))
			requestPrompt.Visible = true

			UIFactory.Label("RequestText", requestPrompt, ("%s wants to trade."):format(payload.fromName or "Someone"), UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 0, 44), Theme.Colors.TextPrimary, Theme.Fonts.Body, 13)

			UIFactory.Button("AcceptTrade", requestPrompt, "Accept", UDim2.new(0, 130, 0, 30), UDim2.new(0, 12, 1, -40), function()
				tradeRemote:FireServer("AcceptRequest", {})
				requestPrompt:Destroy()
			end).BackgroundColor3 = Theme.Colors.Success

			UIFactory.Button("DeclineTrade", requestPrompt, "Decline", UDim2.new(0, 130, 0, 30), UDim2.new(1, -142, 1, -40), function()
				tradeRemote:FireServer("DeclineRequest", {})
				requestPrompt:Destroy()
			end).BackgroundColor3 = Theme.Colors.Danger

			task.delay(payload.expirySeconds or 30, function()
				if requestPrompt.Parent then
					requestPrompt:Destroy()
				end
			end)
		elseif action == "TradeCompleted" then
			window.Visible = false
		elseif action == "TradeCancelled" then
			window.Visible = false
		end
	end)
end

return TradeController
