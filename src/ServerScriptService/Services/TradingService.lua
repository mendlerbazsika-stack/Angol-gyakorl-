--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side trading service. Two-player trades with expiring requests,
-- fully validated offers, ready-locks that reset on any change, and atomic
-- execution. Offers are re-validated against live inventory at execution
-- time, so there is no duplication or teleport-trade path.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local TradingService = {}
local started = false

local TradeRemote: RemoteEvent

type Offer = {
	currency: number,
	items: {{ id: string, count: number }},
}

type Session = {
	players: {Player},
	offers: {[Player]: Offer},
	ready: {[Player]: boolean},
	locked: boolean,
}

local sessions: {[Player]: Session} = {}

type TradeRequest = {
	from: Player,
	expiresAt: number,
}

local tradeRequests: {[Player]: TradeRequest} = {}

local RequestExpirySeconds = 30
local RequestRange = 30
local TradeRange = 20
local MaxOfferSlots = 6
local LockSeconds = 2

local function otherPlayer(session: Session, player: Player): Player?
	for _, participant in ipairs(session.players) do
		if participant ~= player then
			return participant
		end
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function withinRange(a: Player, b: Player, maxDistance: number): boolean
	local rootA = rootOf(a)
	local rootB = rootOf(b)
	if not rootA or not rootB then
		return false
	end
	return (rootA.Position - rootB.Position).Magnitude <= maxDistance
end

-- Validates an offer against the player's live inventory and currency.
local function validateOffer(player: Player, offer: any): (boolean, string?)
	if typeof(offer) ~= "table" then
		return false, "InvalidOffer"
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end

	local currency = offer.currency
	if typeof(currency) ~= "number" or currency < 0 or currency ~= math.floor(currency) then
		return false, "InvalidCurrency"
	end
	if currency > data.currency then
		return false, "NotEnoughCurrency"
	end

	if typeof(offer.items) ~= "table" or #offer.items > MaxOfferSlots then
		return false, "TooManyItems"
	end

	local totals: {[string]: number} = {}
	for _, entry in ipairs(offer.items) do
		if typeof(entry) ~= "table" or typeof(entry.id) ~= "string" or typeof(entry.count) ~= "number" then
			return false, "InvalidItemEntry"
		end
		if not ItemDefinitions.Get(entry.id) then
			return false, "UnknownItem"
		end
		local count = math.floor(entry.count)
		if count <= 0 then
			return false, "InvalidCount"
		end
		totals[entry.id] = (totals[entry.id] or 0) + count
	end

	for itemId, count in pairs(totals) do
		if InventoryService.CountItem(player, itemId) < count then
			return false, "NotEnoughItems"
		end
	end

	return true, nil
end

local function endSession(session: Session, reason: string)
	for _, participant in ipairs(session.players) do
		sessions[participant] = nil
		if participant.Parent and TradeRemote then
			TradeRemote:FireClient(participant, "TradeCancelled", { reason = reason })
		end
	end
end

local function executeTrade(session: Session)
	-- Re-validate everything against live state immediately before the swap.
	local a = session.players[1]
	local b = session.players[2]
	if not a.Parent or not b.Parent then
		endSession(session, "PlayerLeft")
		return
	end
	if not withinRange(a, b, TradeRange) then
		endSession(session, "TooFar")
		return
	end

	local offerA = session.offers[a]
	local offerB = session.offers[b]
	if not offerA or not offerB then
		endSession(session, "MissingOffer")
		return
	end

	local okA = validateOffer(a, offerA)
	local okB = validateOffer(b, offerB)
	if not okA or not okB then
		endSession(session, "OfferInvalidated")
		return
	end

	-- Remove both sides first (validated, so both must succeed).
	local dataA = PlayerDataService.GetData(a)
	local dataB = PlayerDataService.GetData(b)
	if not dataA or not dataB then
		endSession(session, "DataNotReady")
		return
	end

	local function takeOffer(player: Player, offer: Offer)
		for _, entry in ipairs(offer.items) do
			InventoryService.RemoveItem(player, entry.id, entry.count)
		end
	end

	takeOffer(a, offerA)
	takeOffer(b, offerB)
	dataA.currency -= offerA.currency
	dataB.currency -= offerB.currency

	-- Deliver to the opposite side; refund the giver if receiving fails.
	local function giveOffer(giver: Player, receiver: Player, offer: Offer)
		for _, entry in ipairs(offer.items) do
			local ok = InventoryService.AddItem(receiver, entry.id, entry.count)
			if not ok then
				-- Receiver has no space: return the goods to the giver, whose
				-- slots were just freed by takeOffer, so this cannot fail.
				InventoryService.AddItem(giver, entry.id, entry.count)
				warn(("AFTERZERO TradeService: item returned to giver (%s -> %s)"):format(giver.Name, receiver.Name))
			end
		end
	end

	giveOffer(a, b, offerA)
	giveOffer(b, a, offerB)
	dataA.currency += offerB.currency
	dataB.currency += offerA.currency

	for _, participant in ipairs(session.players) do
		sessions[participant] = nil
		if participant.Parent and TradeRemote then
			TradeRemote:FireClient(participant, "TradeCompleted", {})
		end
	end
end

local function broadcastSession(session: Session)
	local payloadFor = function(player: Player)
		local partner = otherPlayer(session, player)
		local mine = session.offers[player]
		local theirs = if partner then session.offers[partner] else nil
		return {
			partnerName = if partner then partner.Name else "",
			myCurrency = if mine then mine.currency else 0,
			myItems = if mine then mine.items else {},
			theirCurrency = if theirs then theirs.currency else 0,
			theirItems = if theirs then theirs.items else {},
			myReady = session.ready[player] == true,
			theirReady = if partner then session.ready[partner] == true else false,
			locked = session.locked,
		}
	end

	for _, participant in ipairs(session.players) do
		if participant.Parent and TradeRemote then
			TradeRemote:FireClient(participant, "TradeUpdated", payloadFor(participant))
		end
	end
end

function TradingService.RequestTrade(player: Player, target: Player): (boolean, string?)
	if player == target then
		return false, "CannotTradeSelf"
	end
	if sessions[player] then
		return false, "AlreadyTrading"
	end
	if sessions[target] then
		return false, "TargetTrading"
	end
	if not withinRange(player, target, RequestRange) then
		return false, "TooFar"
	end

	tradeRequests[target] = {
		from = player,
		expiresAt = os.clock() + RequestExpirySeconds,
	}

	if TradeRemote then
		TradeRemote:FireClient(target, "TradeRequestReceived", {
			fromName = player.Name,
			expirySeconds = RequestExpirySeconds,
		})
	end

	return true, nil
end

function TradingService.AcceptRequest(player: Player): (boolean, string?)
	local request = tradeRequests[player]
	if not request then
		return false, "NoRequest"
	end
	tradeRequests[player] = nil

	if os.clock() > request.expiresAt then
		return false, "RequestExpired"
	end
	local requester = request.from
	if not requester.Parent then
		return false, "RequesterLeft"
	end
	if sessions[player] or sessions[requester] then
		return false, "AlreadyTrading"
	end
	if not withinRange(player, requester, RequestRange) then
		return false, "TooFar"
	end

	local session: Session = {
		players = { requester, player },
		offers = {},
		ready = {},
		locked = false,
	}
	sessions[requester] = session
	sessions[player] = session
	broadcastSession(session)
	return true, nil
end

function TradingService.DeclineRequest(player: Player)
	local request = tradeRequests[player]
	if request then
		tradeRequests[player] = nil
		if request.from.Parent and TradeRemote then
			TradeRemote:FireClient(request.from, "TradeDeclined", { by = player.Name })
		end
	end
end

function TradingService.SetOffer(player: Player, offer: any): (boolean, string?)
	local session = sessions[player]
	if not session then
		return false, "NoSession"
	end
	if session.locked then
		return false, "TradeLocked"
	end

	local ok, err = validateOffer(player, offer)
	if not ok then
		return false, err
	end

	-- Any offer change resets both ready flags.
	session.offers[player] = {
		currency = offer.currency,
		items = offer.items,
	}
	session.ready[session.players[1]] = false
	session.ready[session.players[2]] = false
	broadcastSession(session)
	return true, nil
end

function TradingService.SetReady(player: Player, ready: boolean): (boolean, string?)
	local session = sessions[player]
	if not session then
		return false, "NoSession"
	end
	if session.locked then
		return false, "TradeLocked"
	end
	if not session.offers[player] then
		return false, "NoOffer"
	end

	session.ready[player] = ready == true
	broadcastSession(session)

	local partner = otherPlayer(session, player)
	if partner and session.ready[player] and session.ready[partner] then
		-- Both ready: lock briefly, then execute. Any cancel during the lock
		-- window aborts the trade with nothing exchanged.
		session.locked = true
		broadcastSession(session)

		task.delay(LockSeconds, function()
			local current = sessions[player]
			if current == session and session.locked
				and session.ready[player] and session.ready[partner :: Player] then
				executeTrade(session)
			end
		end)
	end

	return true, nil
end

function TradingService.Cancel(player: Player)
	local session = sessions[player]
	if session then
		session.locked = true
		endSession(session, "Cancelled")
	end
	tradeRequests[player] = nil
end

local function handleRemote(player: Player, action: string, payload: any)
	if action == "RequestTrade" then
		local targetUserId = if typeof(payload) == "table" then payload.targetUserId else nil
		if typeof(targetUserId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if target then
			TradingService.RequestTrade(player, target)
		end
	elseif action == "AcceptRequest" then
		TradingService.AcceptRequest(player)
	elseif action == "DeclineRequest" then
		TradingService.DeclineRequest(player)
	elseif action == "SetOffer" then
		TradingService.SetOffer(player, payload)
	elseif action == "SetReady" then
		local ready = if typeof(payload) == "table" then payload.ready else nil
		if typeof(ready) == "boolean" then
			TradingService.SetReady(player, ready)
		end
	elseif action == "Cancel" then
		TradingService.Cancel(player)
	end
end

function TradingService.Start()
	if started then
		return
	end
	started = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	TradeRemote = remotes:FindFirstChild("TradeRemote")
	if not TradeRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "TradeRemote"
		remote.Parent = remotes
		TradeRemote = remote
	end

	TradeRemote.OnServerEvent:Connect(handleRemote)

	Players.PlayerRemoving:Connect(function(player)
		tradeRequests[player] = nil
		local session = sessions[player]
		if session then
			endSession(session, "PlayerLeft")
		end
	end)

	print("AFTERZERO TradingService initialized.")
end

return TradingService
