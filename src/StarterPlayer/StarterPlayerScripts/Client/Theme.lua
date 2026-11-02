--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- Client UI theme: post-apocalyptic palette, fonts, and layout constants
-- shared by every UI controller.

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(24, 26, 24),
	BackgroundRaised = Color3.fromRGB(34, 37, 34),
	BackgroundPanel = Color3.fromRGB(44, 48, 44),
	Border = Color3.fromRGB(74, 78, 72),
	TextPrimary = Color3.fromRGB(224, 216, 200),
	TextSecondary = Color3.fromRGB(168, 164, 152),
	TextMuted = Color3.fromRGB(120, 118, 108),
	Accent = Color3.fromRGB(191, 148, 92),
	AccentDark = Color3.fromRGB(140, 105, 60),
	Danger = Color3.fromRGB(178, 76, 60),
	Health = Color3.fromRGB(160, 76, 60),
	Hunger = Color3.fromRGB(158, 122, 64),
	Thirst = Color3.fromRGB(86, 132, 158),
	Stamina = Color3.fromRGB(132, 158, 86),
	Temperature = Color3.fromRGB(140, 176, 198),
	Radiation = Color3.fromRGB(158, 196, 92),
	Success = Color3.fromRGB(112, 158, 92),
}

Theme.Fonts = {
	Header = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Mono = Enum.Font.RobotoMono,
}

Theme.Sizes = {
	Border = 1,
	Corner = 4,
	Padding = 8,
	PaddingLarge = 12,
	ButtonHeight = 32,
	HudBarWidth = 180,
	HudBarHeight = 12,
}

Theme.UICorner = function(radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Sizes.Corner)
	return corner
end

Theme.UIStroke = function(color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.Border
	stroke.Thickness = thickness or Theme.Sizes.Border
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

return Theme
