--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Combat controller: mouse/touch attack input that raycasts for a target
-- part and reports INTENT ONLY to the server. The server re-validates
-- range, weapon, cooldown, ammo, and the target's membership in the live
-- enemy list. The raycast here is a convenience, never an authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatRemote")

local camera = workspace.CurrentCamera

local function findTargetPart(): BasePart?
	-- Raycast from the camera through the crosshair; stop at the first
	-- enemy or character geometry. Anything else is a miss.
	local mouse = player:GetMouse()
	local origin = camera.CFrame.Position
	local direction = (mouse.Hit.Position - origin)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	if character then
		raycastParams.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(origin, direction.Unit * 300, raycastParams)
	if result and result.Instance then
		return result.Instance
	end
	return nil
end

local function attack(isRanged: boolean)
	local targetPart = findTargetPart()
	if not targetPart then
		return
	end

	local action = if isRanged then "RangedAttack" else "MeleeAttack"
	combatRemote:FireServer(action, { targetPart = targetPart })
end

local function equippedWeaponIsRanged(): boolean
	-- Read-only check of replicated equipment state to pick the input mode.
	local EquipmentService = nil -- client cannot require server services
	local equipment = player:GetAttribute("MainHandItem")
	return typeof(equipment) == "string" and equipment == "ScrapPistol"
end

local lastAttackAt = 0

local function tryAttack(isRanged: boolean)
	-- Local pre-throttle for responsiveness; the server enforces the real
	-- cooldown independently.
	local now = os.clock()
	if now - lastAttackAt < 0.45 then
		return
	end
	lastAttackAt = now
	attack(isRanged)
end

function CombatController.Start()
	-- Keyboard/mouse: left click = attack (auto melee/ranged by weapon).
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryAttack(equippedWeaponIsRanged())
		elseif input.KeyCode == Enum.KeyCode.F then
			-- Force melee swing (pistol-whip equivalent when ranged equipped).
			tryAttack(false)
		end
	end)

	-- Touch: a floating attack button near the thumb zone.
	local gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_Combat"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local Theme = require(script.Parent.Theme)
	local UIFactory = require(script.Parent.UIFactory)

	local attackButton = UIFactory.Button("AttackButton", gui, "ATTACK", UDim2.new(0, 84, 0, 84), UDim2.new(1, -100, 1, -110))
	attackButton.TextSize = 12
	attackButton.BackgroundColor3 = Theme.Colors.AccentDark
	attackButton.Text = "⚔"
	attackButton.Activated:Connect(function()
		tryAttack(equippedWeaponIsRanged())
	end)

	-- Damage feedback flashes.
	combatRemote.OnClientEvent:Connect(function(action, payload)
		if action == "Damaged" and type(payload) == "table" then
			local flash = Instance.new("Frame")
			flash.Name = "DamageFlash"
			flash.Size = UDim2.new(1, 0, 1, 0)
			flash.BackgroundColor3 = Color3.fromRGB(178, 76, 60)
			flash.BackgroundTransparency = 0.75
			flash.BorderSizePixel = 0
			flash.ZIndex = 50
			flash.Parent = gui

			local TweenService = game:GetService("TweenService")
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			task.delay(0.4, function()
				flash:Destroy()
			end)
		end
	end)
end

return CombatController
