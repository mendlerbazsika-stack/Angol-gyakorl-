--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side combat service. Validates melee and ranged attacks: range,
-- fire rate, ammo, durability, and armor are all checked on the server.
-- Clients report intent; the server computes outcomes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("ItemDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local EquipmentService = require(Services:WaitForChild("EquipmentService"))
local EnemyService = require(Services:WaitForChild("EnemyService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local SurvivalService = require(Services:WaitForChild("SurvivalService"))

local CombatService = {}
local started = false

local CombatRemote: RemoteEvent

-- Attack cooldowns per player (server clock based).
local lastAttack: {[Player]: number} = {}

local MaxMeleeRange = 8

local function getArmor(player: Player): number
	local equipment = EquipmentService.GetEquipped(player)
	if not equipment then
		return 0
	end
	local armor = 0
	for _, itemId in pairs(equipment) do
		local definition = ItemDefinitions.Get(itemId)
		if definition and definition.equipment and definition.equipment.armor then
			armor += definition.equipment.armor
		end
	end
	return armor
end

local function applyPlayerDamage(targetPlayer: Player, rawDamage: number, attacker: Player?, bleedChance: number)
	local data = PlayerDataService.GetData(targetPlayer)
	if not data or not data.survival or data.survival.dead then
		return
	end

	-- Armor reduces damage with diminishing returns; never fully negates.
	local armor = getArmor(targetPlayer)
	local multiplier = 100 / (100 + armor)
	local damage = rawDamage * multiplier

	data.survival.health = math.clamp(data.survival.health - damage, 0, 100)

	if bleedChance > 0 and math.random() < bleedChance and not data.survival.bleeding then
		data.survival.bleeding = true
	end

	if CombatRemote then
		CombatRemote:FireClient(targetPlayer, "Damaged", {
			amount = math.floor(damage + 0.5),
			source = if attacker then attacker.Name else "Enemy",
		})
	end

	if data.survival.health <= 0 then
		-- Downed (party) or death flow is owned by SurvivalService.
		SurvivalService.EnterDownedOrDead(targetPlayer)
	end
end

local function getWeaponFor(player: Player, slot: string): any?
	local equipment = EquipmentService.GetEquipped(player)
	if not equipment then
		return nil
	end
	local itemId = equipment[slot]
	if not itemId then
		return nil
	end
	local definition = ItemDefinitions.Get(itemId)
	if not definition or not definition.equipment or not definition.equipment.damage then
		return nil
	end
	return definition
end

local function cooldownViolated(player: Player, fireRateSeconds: number): boolean
	local previous = lastAttack[player] or 0
	local now = os.clock()
	if now - previous < fireRateSeconds * 0.9 then
		return true -- small tolerance for jitter, still blocks rapid-fire exploits
	end
	lastAttack[player] = now
	return false
end

function CombatService.MeleeAttack(player: Player, targetPart: BasePart?): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end
	if data.survival and data.survival.dead then
		return false, "Dead"
	end

	local weapon = getWeaponFor(player, "MainHand")
	if not weapon then
		return false, "NoWeaponEquipped"
	end
	local stats = weapon.equipment
	if stats.ranged then
		return false, "WrongWeaponType"
	end

	if cooldownViolated(player, 1.0) then
		return false, "AttackTooFast"
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false, "NoCharacter"
	end

	if not targetPart or not targetPart:IsA("BasePart") then
		return false, "InvalidTarget"
	end

	-- Server-side range check against the actual target position.
	if (root.Position - targetPart.Position).Magnitude > MaxMeleeRange then
		return false, "TargetOutOfRange"
	end

	-- Durability wear on attack.
	EquipmentService.ApplyDurabilityWear(player, "MainHand", 1)

	-- Determine what was hit: enemy part or player part.
	local enemyModel = targetPart:FindFirstAncestorOfClass("Model")
	local enemyId = if enemyModel then enemyModel:GetAttribute("EnemyId") else nil
	if typeof(enemyId) == "string" then
		EnemyService.DamageEnemy(player, enemyModel :: Model, stats.damage :: number)
		return true, nil
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetPart.Parent)
	if targetPlayer then
		-- PvP is disabled by default; Stage 9 region rules may open zones.
		return false, "PvPDisabled"
	end

	return false, "NoValidTarget"
end

function CombatService.RangedAttack(player: Player, targetPart: BasePart?): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "DataNotReady"
	end
	if data.survival and data.survival.dead then
		return false, "Dead"
	end

	local weapon = getWeaponFor(player, "MainHand")
	if not weapon then
		return false, "NoWeaponEquipped"
	end
	local stats = weapon.equipment
	if not stats.ranged then
		return false, "WrongWeaponType"
	end

	if cooldownViolated(player, stats.fireRateSeconds or 1.0) then
		return false, "AttackTooFast"
	end

	-- Ammo check and consumption (server-side).
	local ammoId = stats.ammoId
	if ammoId then
		if InventoryService.CountItem(player, ammoId) < 1 then
			return false, "OutOfAmmo"
		end
		local ok, err = InventoryService.RemoveItem(player, ammoId, 1)
		if not ok then
			return false, tostring(err)
		end
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false, "NoCharacter"
	end

	if not targetPart or not targetPart:IsA("BasePart") then
		return false, "InvalidTarget"
	end

	local distance = (root.Position - targetPart.Position).Magnitude
	if distance > (stats.rangeStuds or 90) then
		return false, "TargetOutOfRange"
	end

	EquipmentService.ApplyDurabilityWear(player, "MainHand", 1)

	local enemyModel = targetPart:FindFirstAncestorOfClass("Model")
	local enemyId = if enemyModel then enemyModel:GetAttribute("EnemyId") else nil
	if typeof(enemyId) == "string" then
		EnemyService.DamageEnemy(player, enemyModel :: Model, stats.damage :: number)
		return true, nil
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetPart.Parent)
	if targetPlayer then
		return false, "PvPDisabled"
	end

	return false, "NoValidTarget"
end

-- Called by EnemyService when an enemy lands an attack on a player.
function CombatService.EnemyHitPlayer(attackerName: string, targetPlayer: Player, damage: number, bleedChance: number)
	applyPlayerDamage(targetPlayer, damage, nil, bleedChance)
end

local function handleRemote(player: Player, action: string, payload: any)
	local targetPart = nil
	if typeof(payload) == "table" and typeof(payload.targetPart) == "Instance" then
		local instance = payload.targetPart
		if instance:IsA("BasePart") then
			targetPart = instance
		end
	end

	if action == "MeleeAttack" then
		CombatService.MeleeAttack(player, targetPart)
	elseif action == "RangedAttack" then
		CombatService.RangedAttack(player, targetPart)
	end
end

function CombatService.Start()
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
	CombatRemote = remotes:FindFirstChild("CombatRemote")
	if not CombatRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "CombatRemote"
		remote.Parent = remotes
		CombatRemote = remote
	end

	CombatRemote.OnServerEvent:Connect(handleRemote)

	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

return CombatService
