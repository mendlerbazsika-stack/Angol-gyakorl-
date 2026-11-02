--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- HUD controller: survival bars, status effects, world clock/weather line,
-- and the current region banner. All data comes from player attributes and
-- workspace attributes replicated by the server; the client never writes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UIFactory = require(script.Parent.UIFactory)

local HUDController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local bars: {[string]: {track: Frame, fill: Frame, label: TextLabel}} = {}
local statusLabel: TextLabel
local regionLabel: TextLabel
local clockLabel: TextLabel
local regionBanner: Frame
local bannerLabel: TextLabel

local BAR_DEFS = {
	{ key = "Health", attribute = "Health", color = Theme.Colors.Health, icon = "HP" },
	{ key = "Hunger", attribute = "Hunger", color = Theme.Colors.Hunger, icon = "FOOD" },
	{ key = "Thirst", attribute = "Thirst", color = Theme.Colors.Thirst, icon = "H2O" },
	{ key = "Stamina", attribute = "Stamina", color = Theme.Colors.Stamina, icon = "SPD" },
	{ key = "BodyTemperature", attribute = "BodyTemperature", color = Theme.Colors.Temperature, icon = "TEMP" },
	{ key = "Radiation", attribute = "Radiation", color = Theme.Colors.Radiation, icon = "RAD" },
}

local function buildHud()
	gui = Instance.new("ScreenGui")
	gui.Name = "AFTERZERO_HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 220, 0, 200)
	container.Position = UDim2.new(0, 12, 0, 12)
	container.BackgroundTransparency = 1
	container.Parent = gui

	for index, def in ipairs(BAR_DEFS) do
		local track, fill = UIFactory.Bar(def.key, container, def.color, UDim2.new(1, 0, 0, Theme.Sizes.HudBarHeight), UDim2.new(0, 0, 0, (index - 1) * (Theme.Sizes.HudBarHeight + 20)))

		local label = UIFactory.Label(def.key .. "Label", container, def.icon, UDim2.new(0, 44, 0, 14), UDim2.new(0, 0, 0, (index - 1) * (Theme.Sizes.HudBarHeight + 20) + Theme.Sizes.HudBarHeight + 2), Theme.Colors.TextMuted, Theme.Fonts.Mono, 11)
		label.TextXAlignment = Enum.TextXAlignment.Left

		bars[def.key] = { track = track, fill = fill, label = label }
	end

	statusLabel = UIFactory.Label("StatusLabel", container, "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 148), Theme.Colors.Danger, Theme.Fonts.Body, 12)

	-- World line: region, clock, weather (top-center).
	local worldLine = Instance.new("Frame")
	worldLine.Name = "WorldLine"
	worldLine.Size = UDim2.new(0, 520, 0, 24)
	worldLine.Position = UDim2.new(0.5, -260, 0, 8)
	worldLine.BackgroundTransparency = 1
	worldLine.Parent = gui

	regionLabel = UIFactory.Label("RegionLabel", worldLine, "GREYWOOD COUNTY", UDim2.new(0, 240, 1, 0), UDim2.new(0, 0, 0, 0), Theme.Colors.Accent, Theme.Fonts.Header, 14)
	regionLabel.TextXAlignment = Enum.TextXAlignment.Left

	clockLabel = UIFactory.Label("ClockLabel", worldLine, "", UDim2.new(0, 240, 1, 0), UDim2.new(1, -240, 0, 0), Theme.Colors.TextSecondary, Theme.Fonts.Mono, 12)
	clockLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Region-change banner (center flash).
	regionBanner = UIFactory.Frame("RegionBanner", gui, UDim2.new(0, 420, 0, 64), UDim2.new(0.5, -210, 0, -80))
	regionBanner.BackgroundTransparency = 0.25
	bannerLabel = UIFactory.Label("BannerText", regionBanner, "", UDim2.new(1, -16, 1, -10), UDim2.new(0, 8, 0, 5), Theme.Colors.TextPrimary, Theme.Fonts.Header, 20)
	bannerLabel.TextXAlignment = Enum.TextXAlignment.Center
	bannerLabel.TextYAlignment = Enum.TextYAlignment.Center
end

local function updateBar(key: string, value: number, maximum: number)
	local bar = bars[key]
	if not bar then
		return
	end

	local fraction = math.clamp(value / maximum, 0, 1)
	local tween = TweenService:Create(bar.fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(fraction, 1),
	})
	tween:Play()
end

local function formatClock(clockTime: number): string
	local hour = math.floor(clockTime) % 24
	local minute = math.floor((clockTime % 1) * 60)
	return ("%02d:%02d"):format(hour, minute)
end

local function showBanner(text: string)
	bannerLabel.Text = text
	regionBanner.Visible = true
	task.delay(2.5, function()
		regionBanner.Visible = false
	end)
end

local function wireAttributes()
	local function onAttributeChanged()
		updateBar("Health", player:GetAttribute("Health") or 100, 100)
		updateBar("Hunger", player:GetAttribute("Hunger") or 100, 100)
		updateBar("Thirst", player:GetAttribute("Thirst") or 100, 100)
		updateBar("Stamina", player:GetAttribute("Stamina") or 100, 100)
		updateBar("BodyTemperature", player:GetAttribute("BodyTemperature") or 60, 100)
		updateBar("Radiation", player:GetAttribute("Radiation") or 0, 100)

		local effects = {}
		if player:GetAttribute("IsBleeding") == true then
			table.insert(effects, "BLEEDING")
		end
		if player:GetAttribute("IsInfected") == true then
			table.insert(effects, "INFECTED")
		end
		if player:GetAttribute("IsDowned") == true then
			table.insert(effects, "DOWNED — CALL FOR REVIVE")
		end
		statusLabel.Text = table.concat(effects, "  ")
	end

	player:GetAttributeChangedSignal("Health"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("Hunger"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("Thirst"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("Stamina"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("BodyTemperature"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("Radiation"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("IsBleeding"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("IsInfected"):Connect(onAttributeChanged)
	player:GetAttributeChangedSignal("IsDowned"):Connect(onAttributeChanged)
	onAttributeChanged()

	local function onRegionChanged()
		local region = player:GetAttribute("CurrentRegion")
		if typeof(region) == "string" then
			local display = (region:gsub("(%a+)", function(word)
				return word:sub(1, 1):upper() .. word:sub(2):lower()
			end):gsub("(%u%l+)(%u)", "%1 %2"))
			regionLabel.Text = string.upper(display)
			showBanner("ENTERING " .. string.upper(display))
		end
	end

	player:GetAttributeChangedSignal("CurrentRegion"):Connect(onRegionChanged)

	-- Clock and weather from server-driven Lighting/Workspace state.
	local Lighting = game:GetService("Lighting")
	local function onClockChanged()
		clockLabel.Text = ("%s  •  %s"):format(
			formatClock(Lighting.ClockTime),
			tostring(game:GetService("Workspace"):GetAttribute("CurrentWeather") or "Clear")
		)
	end
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(onClockChanged)
	game:GetService("Workspace"):GetAttributeChangedSignal("CurrentWeather"):Connect(onClockChanged)
	onClockChanged()
end

function HUDController.Start()
	buildHud()
	wireAttributes()
end

return HUDController
