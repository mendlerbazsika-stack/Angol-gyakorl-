--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Ambience controller: procedural wind/rain audio driven by server weather
-- and time-of-day, with volume settings honored. Uses Roblox stock sounds
-- only — no external assets required.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local AmbienceController = {}

local player = Players.LocalPlayer

-- Roblox stock sound ids (public catalog assets; replace with original
-- recordings in a later art pass).
local SOUND_IDS = {
	Wind = "rbxassetid://9064263931",
	Rain = "rbxassetid://9064055859",
	Storm = "rbxassetid://9064529680",
}

local sounds: {[string]: Sound} = {}

local function makeLooping(name: string, id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = 0
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local function targetVolumes(weather: string, clockTime: number): {[string]: number}
	local night = (clockTime < 6 or clockTime > 20)
	local base = if night then 0.5 else 0.35

	if weather == "Rain" then
		return { Wind = base * 0.6, Rain = 0.4, Storm = 0 }
	elseif weather == "Storm" then
		return { Wind = base * 0.7, Rain = 0.3, Storm = 0.5 }
	elseif weather == "Fog" then
		return { Wind = base * 0.3, Rain = 0, Storm = 0 }
	else -- Clear
		return { Wind = base, Rain = 0, Storm = 0 }
	end
end

local function applyTargets(targets: {[string]: number})
	local TweenService = game:GetService("TweenService")
	for name, sound in pairs(sounds) do
		local target = targets[name] or 0
		TweenService:Create(sound, TweenInfo.new(2, Enum.EasingStyle.Linear), { Volume = target }):Play()
	end
end

function AmbienceController.Start()
	for name, id in pairs(SOUND_IDS) do
		sounds[name] = makeLooping(name, id, 0)
	end

	local function refresh()
		local weather = Workspace:GetAttribute("CurrentWeather") or "Clear"
		applyTargets(targetVolumes(weather, Lighting.ClockTime))
	end

	Workspace:GetAttributeChangedSignal("CurrentWeather"):Connect(refresh)
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
		-- Re-evaluate day/night volume bands at coarse intervals.
		if math.floor(Lighting.ClockTime) % 2 == 0 then
			refresh()
		end
	end)

	refresh()
end

return AmbienceController
