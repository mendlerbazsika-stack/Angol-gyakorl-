--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side party service: party creation, expiring invitations,
-- cooperative reviving of downed members, and shared quest experience
-- for nearby party members. All membership changes are server-validated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local SurvivalService = require(Services:WaitForChild("SurvivalService"))

local PartyService = {}
local started = false

local PartyRemote: RemoteEvent

type Party = {
	leader: Player,
	members: {Player},
}

local partyOfPlayer: {[Player]: Party} = {}

type Invite = {
	leader: Player,
	expiresAt: number,
}

local invites: {[Player]: Invite} = {}

local InviteExpirySeconds = 60
local MaxPartySize = 4
local ReviveRange = 8
local SharedXpRange = 80
local SharedXpFraction = 0.5

local function broadcastParty(party: Party)
	local memberNames = {}
	for _, member in ipairs(party.members) do
		table.insert(memberNames, member.Name)
	end

	local payload = {
		leader = party.leader.Name,
		members = memberNames,
	}

	for _, member in ipairs(party.members) do
		if member.Parent and PartyRemote then
			PartyRemote:FireClient(member, "PartyUpdated", payload)
		end
	end
end

local function disbandParty(party: Party)
	for _, member in ipairs(party.members) do
		partyOfPlayer[member] = nil
		if member.Parent and PartyRemote then
			PartyRemote:FireClient(member, "PartyDisbanded", {})
		end
	end
end

function PartyService.GetParty(player: Player): Party?
	return partyOfPlayer[player]
end

function PartyService.IsInSameParty(a: Player, b: Player): boolean
	local party = partyOfPlayer[a]
	return party ~= nil and party == partyOfPlayer[b]
end

function PartyService.CreateParty(player: Player): (boolean, string?)
	if partyOfPlayer[player] then
		return false, "AlreadyInParty"
	end

	local party: Party = { leader = player, members = { player } }
	partyOfPlayer[player] = party
	broadcastParty(party)
	return true, nil
end

function PartyService.InvitePlayer(player: Player, targetPlayer: Player): (boolean, string?)
	local party = partyOfPlayer[player]
	if not party or party.leader ~= player then
		return false, "NotLeader"
	end
	if #party.members >= MaxPartySize then
		return false, "PartyFull"
	end
	if partyOfPlayer[targetPlayer] then
		return false, "TargetInParty"
	end

	invites[targetPlayer] = {
		leader = player,
		expiresAt = os.clock() + InviteExpirySeconds,
	}

	if PartyRemote then
		PartyRemote:FireClient(targetPlayer, "InviteReceived", {
			leaderName = player.Name,
			expirySeconds = InviteExpirySeconds,
		})
	end

	for _, member in ipairs(party.members) do
		if member ~= player and PartyRemote and member.Parent then
			PartyRemote:FireClient(member, "Notification", {
				text = ("%s was invited to the party."):format(targetPlayer.Name),
			})
		end
	end

	return true, nil
end

function PartyService.AcceptInvite(player: Player): (boolean, string?)
	local invite = invites[player]
	if not invite then
		return false, "NoInvite"
	end
	invites[player] = nil

	if os.clock() > invite.expiresAt then
		return false, "InviteExpired"
	end
	if not invite.leader.Parent then
		return false, "LeaderLeft"
	end

	local party = partyOfPlayer[invite.leader]
	if not party or party.leader ~= invite.leader then
		return false, "PartyDisbanded"
	end
	if #party.members >= MaxPartySize then
		return false, "PartyFull"
	end
	if partyOfPlayer[player] then
		return false, "AlreadyInParty"
	end

	table.insert(party.members, player)
	partyOfPlayer[player] = party
	broadcastParty(party)
	return true, nil
end

function PartyService.DeclineInvite(player: Player)
	invites[player] = nil
end

function PartyService.LeaveParty(player: Player): (boolean, string?)
	local party = partyOfPlayer[player]
	if not party then
		return false, "NotInParty"
	end

	partyOfPlayer[player] = nil

	if #party.members <= 1 then
		disbandParty(party)
		return true, nil
	end

	-- Remove the leaving member, promoting the next member if the leader left.
	local remaining = {}
	for _, member in ipairs(party.members) do
		if member ~= player then
			table.insert(remaining, member)
		end
	end
	party.members = remaining
	if party.leader == player then
		party.leader = remaining[1]
	end

	broadcastParty(party)
	return true, nil
end

-- Shared quest experience: nearby party members who still have the same quest
-- active receive a fraction of the quest's experience when one member turns
-- it in. Items and currency are never shared — no reward duplication path.
function PartyService.ShareQuestCompletion(player: Player, quest: any)
	local party = partyOfPlayer[player]
	if not party then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end

	local sharedXp = math.floor((quest.rewards.experience or 0) * SharedXpFraction)
	if sharedXp <= 0 then
		return
	end

	for _, member in ipairs(party.members) do
		if member ~= player and member.Parent then
			local memberRoot = if member.Character then member.Character:FindFirstChild("HumanoidRootPart") else nil
			if memberRoot and memberRoot:IsA("BasePart")
				and (memberRoot.Position - root.Position).Magnitude <= SharedXpRange then
				local data = PlayerDataService.GetData(member)
				if data and data.progression.activeQuests[quest.id] then
					data.character.experience += sharedXp
					if PartyRemote then
						PartyRemote:FireClient(member, "SharedExperience", {
							questId = quest.id,
							experience = sharedXp,
							from = player.Name,
						})
					end
				end
			end
		end
	end
end

local function tryRevive(reviver: Player, target: Player): (boolean, string?)
	if reviver == target then
		return false, "CannotReviveSelf"
	end
	if not PartyService.IsInSameParty(reviver, target) then
		return false, "NotInSameParty"
	end

	local reviverCharacter = reviver.Character
	local reviverRoot = if reviverCharacter then reviverCharacter:FindFirstChild("HumanoidRootPart") else nil
	local targetCharacter = target.Character
	local targetRoot = if targetCharacter then targetCharacter:FindFirstChild("HumanoidRootPart") else nil
	if not reviverRoot or not reviverRoot:IsA("BasePart") or not targetRoot or not targetRoot:IsA("BasePart") then
		return false, "NoCharacter"
	end
	if (reviverRoot.Position - targetRoot.Position).Magnitude > ReviveRange then
		return false, "TooFar"
	end
	if target:GetAttribute("IsDowned") ~= true then
		return false, "TargetNotDowned"
	end

	local revived = SurvivalService.TryRevive(target)
	if not revived then
		return false, "ReviveFailed"
	end

	if PartyRemote then
		PartyRemote:FireClient(target, "Revived", { by = reviver.Name })
		PartyRemote:FireClient(reviver, "ReviveSuccess", { target = target.Name })
	end

	return true, nil
end

local function handleRemote(player: Player, action: string, payload: any)
	if action == "CreateParty" then
		PartyService.CreateParty(player)
	elseif action == "InvitePlayer" then
		local targetUserId = if typeof(payload) == "table" then payload.targetUserId else nil
		if typeof(targetUserId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if target then
			PartyService.InvitePlayer(player, target)
		end
	elseif action == "AcceptInvite" then
		PartyService.AcceptInvite(player)
	elseif action == "DeclineInvite" then
		PartyService.DeclineInvite(player)
	elseif action == "LeaveParty" then
		PartyService.LeaveParty(player)
	elseif action == "ReviveTarget" then
		local targetUserId = if typeof(payload) == "table" then payload.targetUserId else nil
		if typeof(targetUserId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if target then
			tryRevive(player, target)
		end
	elseif action == "RequestState" then
		local party = partyOfPlayer[player]
		if party then
			broadcastParty(party)
		elseif PartyRemote then
			PartyRemote:FireClient(player, "PartyUpdated", {
				leader = player.Name,
				members = { player.Name },
			})
		end
	end
end

function PartyService.Start()
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
	PartyRemote = remotes:FindFirstChild("PartyRemote")
	if not PartyRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "PartyRemote"
		remote.Parent = remotes
		PartyRemote = remote
	end

	PartyRemote.OnServerEvent:Connect(handleRemote)

	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		PartyService.LeaveParty(player)
	end)

	print("AFTERZERO PartyService initialized.")
end

return PartyService
