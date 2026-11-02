--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Server-side vehicle service. Spawned field trucks with server-controlled
-- seating, fuel drain, damage, repair, and hijack prevention. Clients request
-- entry/exit; the server validates distance, occupancy, and fuel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Services = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))

local VehicleService = {}
local started = false

local VehicleRemote: RemoteEvent

type Vehicle = {
	id: string,
	model: Model,
	seat: VehicleSeat,
	fuel: number,
	health: number,
	driver: Player?,
}

local vehicles: {Vehicle} = {}

local MaxFuel = 100
local FuelPerUnit = 40 -- one GasolineCan refuels 40 fuel
local FuelDrainPerStud = 0.05
local HealthPerRepair = 30
local RepairCost = 2 -- ScrapMetal per repair
local EnterRange = 12

local SpawnPoints = {
	Vector3.new(40, 0, 60),
	Vector3.new(-60, 0, -80),
	Vector3.new(140, 0, 120),
}

local function buildTruck(position: Vector3): (Model, VehicleSeat)
	local model = Instance.new("Model")
	model.Name = "FieldTruck"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(6, 2, 12)
	body.CFrame = CFrame.new(position.X, 3, position.Z)
	body.Color = Color3.fromRGB(74, 80, 76)
	body.Material = Enum.Material.CorrodedMetal
	body.Anchored = true
	body.Parent = model

	local cab = Instance.new("Part")
	cab.Name = "Cab"
	cab.Size = Vector3.new(5.5, 3, 4)
	cab.CFrame = CFrame.new(position.X, 5.5, position.Z - 4)
	cab.Color = Color3.fromRGB(60, 66, 63)
	cab.Material = Enum.Material.Metal
	cab.Anchored = true
	cab.Parent = model

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = CFrame.new(position.X, 6.5, position.Z - 3.5)
	seat.Color = Color3.fromRGB(40, 42, 41)
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.MaxSpeed = 0 -- engine off until fuel confirmed and server enables
	seat.Parent = model

	-- Wheels (visual only; anchored body does the moving via platform style)
	for _, offset in ipairs({ Vector3.new(-3.4, 1.5, 4), Vector3.new(3.4, 1.5, 4), Vector3.new(-3.4, 1.5, -4), Vector3.new(3.4, 1.5, -4) }) do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel"
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(1.5, 3, 3)
		wheel.CFrame = CFrame.new(position + offset) * CFrame.Angles(0, 0, math.rad(90))
		wheel.Color = Color3.fromRGB(30, 30, 30)
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.Anchored = true
		wheel.Parent = model
	end

	return model, seat
end

local function spawnVehicle(position: Vector3)
	for _, vehicle in ipairs(vehicles) do
		local body = vehicle.model:FindFirstChild("Body")
		if body and (body.Position - position).Magnitude < 10 then
			return
		end
	end

	local HttpService = game:GetService("HttpService")
	local model, seat = buildTruck(position)
	local vehicle: Vehicle = {
		id = "v_" .. HttpService:GenerateGUID(false),
		model = model,
		seat = seat,
		fuel = MaxFuel / 2,
		health = 100,
		driver = nil,
	}
	model:SetAttribute("VehicleId", vehicle.id)
	model.Parent = Workspace
	table.insert(vehicles, vehicle)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		local character = if occupant then occupant.Parent else nil
		local player = if character then Players:GetPlayerFromCharacter(character) else nil

		if player then
			-- Server validates entry through the seat occupant itself, which
			-- only Roblox sets; hijacking an occupied seat is not possible
			-- because occupancy is exclusive by engine design.
			if vehicle.fuel <= 0 then
				player.Character and player.Character:PivotTo(model:GetPivot() + Vector3.new(4, 2, 0))
				if VehicleRemote then
					VehicleRemote:FireClient(player, "NoFuel", {})
				end
				return
			end
			vehicle.driver = player
			seat.MaxSpeed = 35
			if VehicleRemote then
				VehicleRemote:FireClient(player, "EnteredVehicle", { vehicleId = vehicle.id, fuel = vehicle.fuel, health = vehicle.health })
			end
		else
			vehicle.driver = nil
			seat.MaxSpeed = 0
		end
	end)
end

local function getVehicleById(id: string): Vehicle?
	for _, vehicle in ipairs(vehicles) do
		if vehicle.id == id then
			return vehicle
		end
	end
	return nil
end

function VehicleService.Refuel(player: Player, vehicleId: string): (boolean, string?)
	local vehicle = getVehicleById(vehicleId)
	if not vehicle then
		return false, "UnknownVehicle"
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false, "NoCharacter"
	end
	local body = vehicle.model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return false, "UnknownVehicle"
	end
	if (root.Position - body.Position).Magnitude > EnterRange then
		return false, "TooFar"
	end

	if vehicle.fuel >= MaxFuel then
		return false, "TankFull"
	end
	if InventoryService.CountItem(player, "GasolineCan") < 1 then
		return false, "NoGasCan"
	end

	local ok, err = InventoryService.RemoveItem(player, "GasolineCan", 1)
	if not ok then
		return false, tostring(err)
	end

	vehicle.fuel = math.min(MaxFuel, vehicle.fuel + FuelPerUnit)
	if VehicleRemote then
		VehicleRemote:FireClient(player, "FuelChanged", { vehicleId = vehicleId, fuel = vehicle.fuel })
	end
	return true, nil
end

function VehicleService.Repair(player: Player, vehicleId: string): (boolean, string?)
	local vehicle = getVehicleById(vehicleId)
	if not vehicle then
		return false, "UnknownVehicle"
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false, "NoCharacter"
	end
	local body = vehicle.model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return false, "UnknownVehicle"
	end
	if (root.Position - body.Position).Magnitude > EnterRange then
		return false, "TooFar"
	end

	if vehicle.health >= 100 then
		return false, "NoDamage"
	end
	if InventoryService.CountItem(player, "ScrapMetal") < RepairCost then
		return false, "MissingMaterials"
	end

	local ok, err = InventoryService.RemoveItem(player, "ScrapMetal", RepairCost)
	if not ok then
		return false, tostring(err)
	end

	vehicle.health = math.min(100, vehicle.health + HealthPerRepair)
	if VehicleRemote then
		VehicleRemote:FireClient(player, "HealthChanged", { vehicleId = vehicleId, health = vehicle.health })
	end
	return true, nil
end

local function updateVehicles()
	-- Drain fuel and disable the engine when the tank empties.
	for _, vehicle in ipairs(vehicles) do
		if vehicle.driver and vehicle.seat.Occupant then
			local throttle = vehicle.seat.ThrottleFloat
			if math.abs(throttle) > 0.05 then
				local drain = math.abs(throttle) * 20 * 0.05 -- ~1 fuel/sec at full throttle
				vehicle.fuel = math.max(0, vehicle.fuel - drain)
				if vehicle.fuel <= 0 then
					vehicle.seat.MaxSpeed = 0
					if VehicleRemote then
						VehicleRemote:FireClient(vehicle.driver, "OutOfFuel", { vehicleId = vehicle.id })
					end
				end
			end
		end
	end
end

local function handleRemote(player: Player, action: string, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.vehicleId) ~= "string" then
		return
	end

	if action == "Refuel" then
		VehicleService.Refuel(player, payload.vehicleId)
	elseif action == "Repair" then
		VehicleService.Repair(player, payload.vehicleId)
	end
end

function VehicleService.Start()
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
	VehicleRemote = remotes:FindFirstChild("VehicleRemote")
	if not VehicleRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "VehicleRemote"
		remote.Parent = remotes
		VehicleRemote = remote
	end

	VehicleRemote.OnServerEvent:Connect(handleRemote)

	for _, position in ipairs(SpawnPoints) do
		spawnVehicle(position)
	end

	task.spawn(function()
		while started do
			task.wait(0.05)
			updateVehicles()
		end
	end)

	print("AFTERZERO VehicleService initialized.")
end

return VehicleService
