--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Generated Greywood County playable blockout. Creates simple geometry, loot
-- and resource interaction prompts, region detection, a day/night cycle, and
-- weather transitions. Replace blockout geometry with authored assets later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Services = ServerScriptService:WaitForChild("Services")
local LootService = require(Services:WaitForChild("LootService"))
local GatheringService = require(Services:WaitForChild("GatheringService"))

local WorldService = {}
local started = false
local regionZones: {BasePart} = {}
local currentWeather = "Clear"
local clock = 7.5

local COLORS = {
	Ground = Color3.fromRGB(69, 78, 59), Road = Color3.fromRGB(43, 45, 43),
	Concrete = Color3.fromRGB(94, 91, 82), Wood = Color3.fromRGB(91, 66, 48),
	Metal = Color3.fromRGB(74, 79, 78), Water = Color3.fromRGB(45, 78, 87),
	Leaf = Color3.fromRGB(47, 70, 46),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material, p.Anchored = color, material, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function prompt(target: BasePart, action: string, object: string, hold: number, callback: (Player) -> ())
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText = action, object
	p.HoldDuration, p.MaxActivationDistance = hold, 10
	p.RequiresLineOfSight = false
	p.Parent = target
	p.Triggered:Connect(callback)
end

local function addBuilding(parent: Instance, name: string, pos: Vector3, dimensions: Vector3, lootTable: string?)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	part(model, "Foundation", Vector3.new(dimensions.X + 2, 1, dimensions.Z + 2), CFrame.new(pos.X, 0.5, pos.Z), COLORS.Concrete, Enum.Material.Concrete)
	part(model, "Shell", Vector3.new(dimensions.X, dimensions.Y, dimensions.Z), CFrame.new(pos.X, dimensions.Y / 2 + 1, pos.Z), Color3.fromRGB(103, 91, 74), Enum.Material.WoodPlanks)
	part(model, "Roof", Vector3.new(dimensions.X + 1, 1, dimensions.Z + 1), CFrame.new(pos.X, dimensions.Y + 1.5, pos.Z), COLORS.Metal, Enum.Material.CorrodedMetal)
	local door = part(model, "Door", Vector3.new(3, 6, 0.4), CFrame.new(pos.X, 4, pos.Z + dimensions.Z / 2 + 0.3), COLORS.Wood, Enum.Material.Wood)
	if lootTable then
		local crate = part(model, "SearchableCrate", Vector3.new(3, 2, 2), CFrame.new(pos.X + dimensions.X / 2 - 3, 2, pos.Z - dimensions.Z / 2 + 3), COLORS.Wood, Enum.Material.Wood)
		LootService.RegisterContainer(crate, lootTable, name .. "_crate")
		prompt(crate, "Search", "Abandoned crate", 1.1, function(player)
			LootService.SearchContainer(player, crate)
		end)
	end
	return model, door
end

local function addNode(parent: Instance, name: string, kind: string, pos: Vector3, color: Color3, material: Enum.Material)
	local node = part(parent, name, Vector3.new(4, 3, 4), CFrame.new(pos.X, 1.5, pos.Z), color, material)
	GatheringService.RegisterNode(node, kind)
	prompt(node, "Gather", name, 1.25, function(player)
		GatheringService.Harvest(player, node)
	end)
	return node
end

local function addRegionZone(parent: Instance, regionName: string, center: Vector3, size: Vector3)
	local zone = Instance.new("Part")
	zone.Name, zone.Size, zone.CFrame = "Region_" .. regionName, size, CFrame.new(center)
	zone.Anchored, zone.Transparency = true, 1
	zone.CanCollide, zone.CanTouch, zone.CanQuery = false, false, false
	zone:SetAttribute("RegionName", regionName)
	zone.Parent = parent
	table.insert(regionZones, zone)
end

local function buildGreywood()
	local world = Workspace:FindFirstChild("World")
	if not world then
		world = Instance.new("Folder")
		world.Name, world.Parent = "World", Workspace
	end
	local regions = world:FindFirstChild("Regions")
	if not regions then
		regions = Instance.new("Folder")
		regions.Name, regions.Parent = "Regions", world
	end
	if regions:FindFirstChild("GreywoodCounty") then return end

	local greywood = Instance.new("Folder")
	greywood.Name, greywood.Parent = "GreywoodCounty", regions
	local poi = Instance.new("Folder")
	poi.Name, poi.Parent = "PointsOfInterest", greywood
	local resources = Instance.new("Folder")
	resources.Name, resources.Parent = "ResourceNodes", greywood

	part(greywood, "CountyGround", Vector3.new(900, 6, 900), CFrame.new(0, -3, 0), COLORS.Ground, Enum.Material.Ground)
	part(greywood, "CountyRoad", Vector3.new(26, 0.5, 760), CFrame.new(0, 0, 15), COLORS.Road, Enum.Material.Asphalt)
	part(greywood, "NorthRoad", Vector3.new(300, 0.5, 20), CFrame.new(110, 0, -190), COLORS.Road, Enum.Material.Asphalt)
	part(greywood, "SouthRoad", Vector3.new(280, 0.5, 20), CFrame.new(-120, 0, 190), COLORS.Road, Enum.Material.Asphalt)
	part(greywood, "GreywoodRiver", Vector3.new(90, 1, 700), CFrame.new(285, -0.3, 0), COLORS.Water, Enum.Material.Water)
	part(greywood, "BridgeDeck", Vector3.new(140, 2, 30), CFrame.new(285, 2, 5), COLORS.Concrete, Enum.Material.Concrete)
	part(greywood, "BridgeRailNorth", Vector3.new(140, 3, 1), CFrame.new(285, 4.5, -10), COLORS.Metal, Enum.Material.CorrodedMetal)
	part(greywood, "BridgeRailSouth", Vector3.new(140, 3, 1), CFrame.new(285, 4.5, 20), COLORS.Metal, Enum.Material.CorrodedMetal)

	addBuilding(poi, "AbandonedGasStation", Vector3.new(45, 0, 40), Vector3.new(34, 10, 28), "GasStationCache")
	addBuilding(poi, "GreywoodDiner", Vector3.new(-58, 0, -120), Vector3.new(36, 9, 26), "ResidentialCabinet")
	addBuilding(poi, "TownHouse01", Vector3.new(-110, 0, -150), Vector3.new(24, 8, 20), "ResidentialCabinet")
	addBuilding(poi, "TownHouse02", Vector3.new(-15, 0, -175), Vector3.new(24, 8, 20), "ResidentialCabinet")
	addBuilding(poi, "AbandonedFarm", Vector3.new(-130, 0, 175), Vector3.new(42, 9, 32), "IndustrialCrate")
	addBuilding(poi, "RangerStation", Vector3.new(120, 0, 110), Vector3.new(32, 9, 26), "RareMedicalLocker")
	addBuilding(poi, "GreywoodSettlement", Vector3.new(80, 0, -35), Vector3.new(48, 11, 34), "GasStationCache")
	addBuilding(poi, "StormShelterEntrance", Vector3.new(-185, 0, -45), Vector3.new(20, 5, 16), "HiddenCache")
	addBuilding(poi, "IndustrialWarehouse", Vector3.new(170, 0, 235), Vector3.new(52, 13, 42), "IndustrialCrate")

	local treePositions = {
		Vector3.new(-290,0,-260), Vector3.new(-245,0,-300), Vector3.new(-330,0,-190), Vector3.new(-265,0,-110),
		Vector3.new(-330,0,30), Vector3.new(-280,0,90), Vector3.new(-310,0,250), Vector3.new(-225,0,300),
		Vector3.new(20,0,300), Vector3.new(75,0,315), Vector3.new(260,0,-270), Vector3.new(330,0,-250),
		Vector3.new(350,0,190), Vector3.new(330,0,300), Vector3.new(215,0,-300), Vector3.new(-190,0,-300),
	}
	for index, pos in ipairs(treePositions) do
		local tree = Instance.new("Model")
		tree.Name, tree.Parent = "GreywoodPine_" .. index, greywood
		part(tree, "Trunk", Vector3.new(2, 14, 2), CFrame.new(pos.X, 7, pos.Z), COLORS.Wood, Enum.Material.Wood)
		local crown = part(tree, "Crown", Vector3.new(10, 14, 10), CFrame.new(pos.X, 16, pos.Z), COLORS.Leaf, Enum.Material.Grass)
		crown.Shape = Enum.PartType.Ball
		local node = part(resources, "TreeNode_" .. index, Vector3.new(3, 3, 3), CFrame.new(pos.X, 1.5, pos.Z), COLORS.Wood, Enum.Material.Wood)
		node.Transparency, node.CanCollide = 1, false
		GatheringService.RegisterNode(node, "Tree")
		prompt(node, "Chop", "Pine tree", 2, function(player)
			GatheringService.Harvest(player, node)
		end)
	end

	addNode(resources, "ScrapPile_GasStation", "ScrapPile", Vector3.new(75,0,75), COLORS.Metal, Enum.Material.CorrodedMetal)
	addNode(resources, "BerryBush_River", "BerryBush", Vector3.new(220,0,-110), COLORS.Leaf, Enum.Material.Grass)
	addNode(resources, "ClothPile_Ranger", "ClothPile", Vector3.new(145,0,125), COLORS.Wood, Enum.Material.Fabric)
	addNode(resources, "RuinCar_Warehouse", "RuinCar", Vector3.new(220,0,250), Color3.fromRGB(60,66,63), Enum.Material.Metal)

	addRegionZone(greywood, "GreywoodCounty", Vector3.new(0, 30, 0), Vector3.new(860, 240, 860))

	local gates = {
		{ name = "RoadToAshford", pos = Vector3.new(0, 1, -390), target = "AshfordCity" },
		{ name = "RoadToIronworks", pos = Vector3.new(390, 1, 250), target = "Ironworks" },
		{ name = "MountainPassToFrostline", pos = Vector3.new(-390, 1, 320), target = "Frostline" },
	}
	for _, gate in ipairs(gates) do
		local barrier = part(poi, gate.name, Vector3.new(26, 10, 2), CFrame.new(gate.pos), COLORS.Metal, Enum.Material.CorrodedMetal)
		barrier:SetAttribute("DestinationRegion", gate.target)
	end
end

local function inside(zone: BasePart, worldPosition: Vector3): boolean
	local localPosition = zone.CFrame:PointToObjectSpace(worldPosition)
	local half = zone.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function updateRegions()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then continue end
		local nextRegion = "Wilderness"
		for _, zone in ipairs(regionZones) do
			if zone.Parent and inside(zone, root.Position) then
				nextRegion = zone:GetAttribute("RegionName") or "Wilderness"
				break
			end
		end
		if player:GetAttribute("CurrentRegion") ~= nextRegion then
			player:SetAttribute("CurrentRegion", nextRegion)
		end
	end
end

local function setWeather(kind: string)
	currentWeather = kind
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Parent = Workspace.Terrain

	if kind == "Rain" then
		atmosphere.Density, atmosphere.Haze, clouds.Cover, clouds.Density = 0.38, 2.1, 0.85, 0.8
	elseif kind == "Fog" then
		atmosphere.Density, atmosphere.Haze, clouds.Cover, clouds.Density = 0.52, 4, 0.7, 0.65
	elseif kind == "Storm" then
		atmosphere.Density, atmosphere.Haze, clouds.Cover, clouds.Density = 0.48, 3.5, 1, 1
	else
		atmosphere.Density, atmosphere.Haze, clouds.Cover, clouds.Density = 0.28, 0.8, 0.3, 0.3
	end
	Workspace:SetAttribute("CurrentWeather", kind)
end

function WorldService.GetWeather(): string
	return currentWeather
end

function WorldService.Start()
	if started then return end
	started = true
	Lighting.ClockTime = clock
	Lighting.Ambient = Color3.fromRGB(93, 101, 95)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 121, 112)
	Lighting.FogStart, Lighting.FogEnd = 0, 1100
	buildGreywood()
	setWeather("Clear")

	task.spawn(function()
		local last = os.clock()
		local weatherKinds = { "Clear", "Rain", "Fog", "Storm" }
		local nextWeatherAt = last + 210
		while started do
			task.wait(1)
			local now = os.clock()
			clock = (clock + 24 * (now - last) / 900) % 24
			last = now
			Lighting.ClockTime = clock
			updateRegions()
			if now >= nextWeatherAt then
				setWeather(weatherKinds[math.random(1, #weatherKinds)])
				nextWeatherAt = now + 210
			end
		end
	end)
	print("AFTERZERO Greywood County blockout initialized.")
end

return WorldService
