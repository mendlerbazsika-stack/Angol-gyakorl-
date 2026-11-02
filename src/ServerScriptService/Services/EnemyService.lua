--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side enemy service. Spawns blockout enemy rigs at fixed locations
-- with a bounded state machine: Patrol -> Detect -> Pursue -> Attack ->
-- Search -> Return. Updates at a fixed 0.5s cadence, never per-frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyDefinitions = require(Shared:WaitForChild("EnemyDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local EnemyService = {}
local started = false

type EnemyInstance = {
	config: any,
	model: Model,
	torso: BasePart,
	homePosition: Vector3,
	health: number,
	state: string, -- "Patrol" | "Pursue" | "Attack" | "Search" | "Return"
	targetPlayer: Player?,
	lastAttackAt: number,
	stateSince: number,
	dead: boolean,
}

local enemies: {EnemyInstance} = {}

local UpdateInterval = 0.5
local PatrolRadius = 10
local GiveUpDistance = 70
local SearchSeconds = 6
local RespawnSeconds = 120

local SpawnPoints = {
	{ enemyId = "Scavenger", position = Vector3.new(150, 0, 200) },
	{ enemyId = "Scavenger", position = Vector3.new(185, 0, 280) },
	{ enemyId = "FeralDog", position = Vector3.new(-100, 0, -110) },
	{ enemyId = "FeralDog", position = Vector3.new(-135, 0, 150) },
	{ enemyId = "Scavenger", position = Vector3.new(230, 0, -100) },
}

local function buildRig(config: any, position: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Enemy_" .. config.id

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, if config.id == "FeralDog" then 2.5 else 5, 1)
	torso.CFrame = CFrame.new(position.X, if config.id == "FeralDog" then 1.5 else 3, position.Z)
	torso.Color = if config.id == "FeralDog" then Color3.fromRGB(74, 60, 48) else Color3.fromRGB(70, 74, 70)
	torso.Material = Enum.Material.Fabric
	torso.Anchored = true
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.CFrame = CFrame.new(position.X, if config.id == "FeralDog" then 3 else 6.3, position.Z)
	head.Color = if config.id == "FeralDog" then Color3.fromRGB(60, 48, 38) else Color3.fromRGB(150, 122, 96)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.Parent = model

	model.PrimaryPart = torso
	return model, torso
end

local function spawnEnemy(spawnInfo: any)
	local config = EnemyDefinitions.Get(spawnInfo.enemyId)
	if not config then
		return
	end

	-- Check whether an active or respawning enemy already occupies this point.
	for _, enemy in ipairs(enemies) do
		if enemy.homePosition == spawnInfo.position and not enemy.dead then
			return
		end
	end

	local model, torso = buildRig(config, spawnInfo.position)
	model:SetAttribute("EnemyId", config.id)
	model.Parent = Workspace

	table.insert(enemies, {
		config = config,
		model = model,
		torso = torso,
		homePosition = spawnInfo.position,
		health = config.health,
		state = "Patrol",
		targetPlayer = nil,
		lastAttackAt = 0,
		stateSince = os.clock(),
		dead = false,
	})
end

local function nearestVisiblePlayer(position: Vector3, aggroRange: number): Player?
	local closest: Player? = nil
	local closestDistance = aggroRange
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local data = PlayerDataService.GetData(player)
			if not data or not data.survival or data.survival.dead then
				continue
			end
			local distance = (root.Position - position).Magnitude
			if distance <= closestDistance then
				closestDistance = distance
				closest = player
			end
		end
	end
	return closest
end

function EnemyService.DamageEnemy(attacker: Player, model: Model, damage: number)
	-- The model lookup is authoritative: the part sent by the client must
	-- belong to a live enemy tracked by this service.
	local enemy: EnemyInstance? = nil
	for _, candidate in ipairs(enemies) do
		if candidate.model == model and not candidate.dead then
			enemy = candidate
			break
		end
	end
	if not enemy then
		return
	end

	enemy.health -= damage
	if enemy.health <= 0 then
		enemy.dead = true
		enemy.model:Destroy()

		-- Rewards: experience, then weighted loot directly into inventory.
		local data = PlayerDataService.GetData(attacker)
		if data then
			data.character.experience += enemy.config.experience
		end
		local drops = EnemyDefinitions.RollLoot(enemy.config)
		for _, drop in ipairs(drops) do
			InventoryService.AddItem(attacker, drop.id, drop.count)
		end

		-- Respawn the spawn point after a delay.
		local homePosition = enemy.homePosition
		local enemyId = enemy.config.id
		task.delay(RespawnSeconds, function()
			if started then
				spawnEnemy({ enemyId = enemyId, position = homePosition })
			end
		end)
	end
end

local function attackPlayer(enemy: EnemyInstance, player: Player)
	local now = os.clock()
	if now - enemy.lastAttackAt < enemy.config.attackCooldown then
		return
	end
	enemy.lastAttackAt = now

	local CombatService = require(Services:WaitForChild("CombatService"))
	CombatService.EnemyHitPlayer(enemy.config.name, player, enemy.config.damage, enemy.config.bleedChance)
end

local function updateEnemy(enemy: EnemyInstance)
	if enemy.dead then
		return
	end

	local now = os.clock()
	local config = enemy.config
	local torso = enemy.torso

	if enemy.state == "Patrol" then
		-- Slow wander around home position.
		local wander = math.noise(now * 0.05, enemy.homePosition.X, enemy.homePosition.Z) * PatrolRadius
		local target = CFrame.new(enemy.homePosition.X + wander, torso.Position.Y, enemy.homePosition.Z + wander * 0.6)
		torso.CFrame = torso.CFrame:Lerp(target, 0.02)

		local detected = nearestVisiblePlayer(torso.Position, config.aggroRange)
		if detected then
			enemy.state = "Pursue"
			enemy.targetPlayer = detected
			enemy.stateSince = now
		end
	elseif enemy.state == "Pursue" then
		local target = enemy.targetPlayer
		local root = if target and target.Character then target.Character:FindFirstChild("HumanoidRootPart") else nil
		if not target or not root or not root:IsA("BasePart") then
			enemy.state = "Return"
			enemy.stateSince = now
			return
		end

		local distance = (torso.Position - root.Position).Magnitude
		if distance > GiveUpDistance then
			enemy.state = "Return"
			enemy.stateSince = now
			return
		end
		if distance <= config.attackRange then
			enemy.state = "Attack"
			enemy.stateSince = now
			return
		end

		local direction = (root.Position - torso.Position).Unit
		local step = direction * config.walkSpeed * UpdateInterval
		torso.CFrame = CFrame.lookAt(torso.Position + step, root.Position)
	elseif enemy.state == "Attack" then
		local target = enemy.targetPlayer
		local root = if target and target.Character then target.Character:FindFirstChild("HumanoidRootPart") else nil
		if not target or not root or not root:IsA("BasePart") then
			enemy.state = "Return"
			enemy.stateSince = now
			return
		end

		local distance = (torso.Position - root.Position).Magnitude
		if distance > config.attackRange * 1.4 then
			enemy.state = "Pursue"
			enemy.stateSince = now
			return
		end

		attackPlayer(enemy, target)
	elseif enemy.state == "Search" then
		if now - enemy.stateSince > SearchSeconds then
			enemy.state = "Return"
			enemy.stateSince = now
		end
	elseif enemy.state == "Return" then
		local direction = (enemy.homePosition - torso.Position)
		if direction.Magnitude < 2 then
			enemy.state = "Patrol"
			enemy.stateSince = now
			enemy.targetPlayer = nil
			return
		end
		local step = direction.Unit * config.walkSpeed * UpdateInterval
		torso.CFrame = CFrame.lookAt(torso.Position + step, torso.Position + direction)
	end
end

function EnemyService.Start()
	if started then
		return
	end
	started = true

	local world = Workspace:FindFirstChild("World")
	if not world then
		warn("AFTERZERO EnemyService: world not generated; enemies not spawned")
	else
		local folder = world:FindFirstChild("Enemies")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Enemies"
			folder.Parent = world
		end
		for _, spawnInfo in ipairs(SpawnPoints) do
			spawnEnemy(spawnInfo)
		end
	end

	task.spawn(function()
		while started do
			task.wait(UpdateInterval)
			for index = #enemies, 1, -1 do
				local enemy = enemies[index]
				if enemy.dead then
					table.remove(enemies, index)
				else
					updateEnemy(enemy)
				end
			end
		end
	end)

	print("AFTERZERO EnemyService initialized.")
end

return EnemyService
