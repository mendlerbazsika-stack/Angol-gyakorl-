--!strict
-- AFTERZERO: THE LAST CIVILIZATION
-- UIFactory: small helpers that build styled UI elements consistently.

local Theme = require(script.Parent.Theme)

local UIFactory = {}

function UIFactory.Frame(name: string, parent: Instance, size: UDim2, position: UDim2, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or Theme.Colors.BackgroundRaised
	frame.BorderSizePixel = 0
	frame.Parent = parent
	frame:AddChild(Theme.UICorner())
	frame:AddChild(Theme.UIStroke())
	return frame
end

function UIFactory.Label(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, textColor: Color3?, font: Enum.Font?, textSize: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor or Theme.Colors.TextPrimary
	label.Font = font or Theme.Fonts.Body
	label.TextSize = textSize or 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function UIFactory.Button(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, onActivated: (() -> ())?): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Theme.Colors.BackgroundPanel
	button.TextColor3 = Theme.Colors.TextPrimary
	button.Font = Theme.Fonts.Body
	button.TextSize = 14
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Parent = parent
	button:AddChild(Theme.UICorner())

	if onActivated then
		button.Activated:Connect(onActivated)
	end

	return button
end

function UIFactory.Bar(name: string, parent: Instance, fillColor: Color3, size: UDim2, position: UDim2): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = name .. "_Track"
	track.Size = size
	track.Position = position
	track.BackgroundColor3 = Theme.Colors.Background
	track.BorderSizePixel = 0
	track.Parent = parent
	track:AddChild(Theme.UICorner(3))
	track:AddChild(Theme.UIStroke(nil, 1))

	local fill = Instance.new("Frame")
	fill.Name = name .. "_Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = track
	fill:AddChild(Theme.UICorner(3))

	return track, fill
end

function UIFactory.Window(name: string, parent: Instance, title: string, size: UDim2, position: UDim2, onClose: (() -> ())?): Frame
	local window = UIFactory.Frame(name, parent, size, position, Theme.Colors.BackgroundRaised)
	window.Visible = false

	UIFactory.Label("Title", window, title, UDim2.new(1, -48, 0, 32), UDim2.new(0, 12, 0, 0), Theme.Colors.Accent, Theme.Fonts.Header, 16)

	local closeButton = UIFactory.Button("CloseButton", window, "X", UDim2.new(0, 32, 0, 32), UDim2.new(1, -40, 0, 0), function()
		if onClose then
			onClose()
		else
			window.Visible = false
		end
	end)
	closeButton.TextColor3 = Theme.Colors.Danger

	return window
end

return UIFactory
