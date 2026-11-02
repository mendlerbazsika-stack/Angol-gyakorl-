--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side region service. Builds compact blockouts for the four campaign
-- regions from RegionDefinitions and manages travel between them with
-- server-validated unlock checks. Gate prompts teleport only after the
-- player's campaign data confirms the region is unlocked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegionDefinitions = require(Shared:WaitForChild("RegionDefinitions"))

local Services = ServerScriptService:WaitForChild("Services")
local CampaignService = require(Services:WaitForChild("CampaignService"))
local LootService = require(Services:WaitForChild("LootService"))
local EnemyService = require(Services:WaitForChild("EnemyService"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local RegionService = {}
local started = false

local Palette = {
	Ground = Color3.fromRGB(69, 78, 59),
	Road = Color3.fromRGB(43, 45, 43),
	Concrete = Color3.fromRGB(94, 91, 82),
	Wood = Color3.fromRGB(101, 88, 70),
	Metal = Color3.fromRGB(74, 79, 78),
	Water = Color3.fromRGB(45, 78, 87),
	Leaf = Color3.fromRGB(47, 70, 46),
}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function addBuilding(parent: Instance, poi: any, basePosition: Vector3)
	local model = Instance.new("Model")
	model.Name = poi.name
	model.Parent = parent

	part(model, "Foundation", Vector3.new(poi.dimensions.X + 2, 1, poi.dimensions.Z + 2), basePosition + Vector3.new(poi.position.X, 0.5, poi.position.Z), Palette.Concrete, Enum.Material.Concrete)
	part(model, "Shell", poi.dimensions, basePosition + Vector3.new(poi.position.X, poi.dimensions.Y / 2 + 1, poi.position.Z), Palette.Wood, Enum.Material.WoodPlanks)
	part(model, "Roof", Vector3.new(poi.dimensions.X + 1, 1, poi.dimensions.Z + 1), basePosition + Vector3.new(poi.position.X, poi.dimensions.Y + 1.5, poi.position.Z), Palette.Metal, Enum.Material.CorrodedMetal)

	if poi.lootTable then
		local crate = part(model, "SearchableCrate", Vector3.new(3, 2, 2), basePosition + Vector3.new(poi.position.X + poi.dimensions.X / 2 - 3, 2, poi.position.Z - poi.dimensions.Z / 2 + 3), Palette.Wood, Enum.Material.Wood)
		LootService.RegisterContainer(crate, poi.lootTable, poi.name .. "_crate")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Search"
		prompt.ObjectText = "Abandoned container"
		prompt.HoldDuration = 1.1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = crate
		prompt.Triggered:Connect(function(player)
			LootService.SearchContainer(player, crate)
		end)
	end
end

local function addGate(modelParent: Instance, regionConfig: any)
	local basePosition = regionConfig.spawnOffset
	local gatePosition = basePosition + regionConfig.entryGate.position

	local barrier = part(modelParent, regionConfig.entryGate.name, Vector3.new(16, 10, 2), gatePosition + Vector3.new(0, 5, 0), Palette.Metal, Enum.Material.CorrodedMetal)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Travel"
	prompt.ObjectText = ("To %s"):format(regionConfig.gatesTo)
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = barrier

	prompt.Triggered:Connect(function(player)
		-- Server-side unlock check; the client prompt is a request, not an order.
		if not CampaignService.IsRegionUnlocked(player, regionConfig.gatesTo) then
			if ReplicatedStorage:FindFirstChild("Remotes") then
				local remotes = ReplicatedStorage.Remotes
				local campaignRemote = remotes:FindFirstChild("CampaignRemote")
				if campaignRemote then
					campaignRemote:FireClient(player, "RegionLocked", {
						regionId = regionConfig.gatesTo,
						message = "This road is closed until the story opens it.",
					})
				end
			end
			return
		end

		local targetRegion = RegionDefinitions.Get(regionConfig.gatesTo)
		if not targetRegion then
			return
		end

		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(targetRegion.spawnOffset + Vector3.new(0, 6, 60)))
		end
		player:SetAttribute("CurrentRegion", regionConfig.gatesTo)
	end)

	return barrier
end

local function buildRegion(regionConfig: any)
	local world = Workspace:FindFirstChild("World")
	if not world then
		warn("AFTERZERO RegionService: world root missing; regions not built")
		return
	end

	local regionsFolder = world:FindFirstChild("Regions")
	if not regionsFolder then
		regionsFolder = Instance.new("Folder")
		regionsFolder.Name = "Regions"
		regionsFolder.Parent = world
	end

	local existing = regionsFolder:FindFirstChild(regionConfig.id)
	if existing then
		return -- already built this server session
	end

	local regionFolder = Instance.new("Folder")
	regionFolder.Name = regionConfig.id
	regionFolder.Parent = regionsFolder

	local basePosition = regionConfig.spawnOffset

	-- Ground plate and a spine road so each region is navigable.
	part(regionFolder, "Ground", Vector3.new(500, 6, 500), basePosition + Vector3.new(0, -3, 0), Palette.Ground, Enum.Material.Ground)
	part(regionFolder, "MainRoad", Vector3.new(20, 0.5, 300), basePosition + Vector3.new(0, 0, 0), Palette.Road, Enum.Material.Asphalt)

	for _, poi in ipairs(regionConfig.buildings) do
		addBuilding(regionFolder, poi, basePosition)
	end

	-- Register enemy spawns through EnemyService's public API.
	for _, spawnInfo in ipairs(regionConfig.enemySpawns) do
		EnemyService.RegisterSpawn(spawnInfo.enemyId, basePosition + spawnInfo.position, regionConfig.id)
	end

	-- Region detection zone so survival picks up the right environment.
	local zone = Instance.new("Part")
	zone.Name = "Region_" .. regionConfig.id
	zone.Size = Vector3.new(500, 120, 500)
	zone.CFrame = CFrame.new(basePosition + Vector3.new(0, 60, 0))
	zone.Anchored = true
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	zone:SetAttribute("RegionName", regionConfig.id)
	zone.Parent = regionFolder

	-- Entry gate back toward the previous region (teleport validated above).
	addGate(regionFolder, regionConfig)
end

function RegionService.Start()
	if started then
		return
	end
	started = true

	for _, regionConfig in pairs(RegionDefinitions.All()) do
		buildRegion(regionConfig)
	end

	print("AFTERZERO RegionService initialized.")
end

return RegionService
