local UI = {}
UI.Colors = {Panel = Color3.fromRGB(16, 29, 42), Raised = Color3.fromRGB(27, 44, 58), Text = Color3.fromRGB(236, 232, 216),
	Muted = Color3.fromRGB(157, 180, 189), Gold = Color3.fromRGB(222, 181, 101), Teal = Color3.fromRGB(79, 184, 182), Red = Color3.fromRGB(206, 103, 89)}
function UI.frame(parent, name, x, y, width, height, color)
	local frame = Instance.new("Frame")
	frame.Name, frame.Position, frame.Size = name, UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
	frame.BorderSizePixel, frame.BackgroundColor3 = 0, color or UI.Colors.Panel
	frame.Parent = parent
	return frame
end
function UI.round(frame, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, radius or 10), frame
	return frame
end
function UI.stroke(frame, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color, stroke.Transparency, stroke.Parent = 1, color or UI.Colors.Gold, 0.7, frame
	return stroke
end
function UI.text(parent, value, x, y, width, height, size, color, bold)
	local label = Instance.new("TextLabel")
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
	label.BackgroundTransparency, label.BorderSizePixel = 1, 0
	label.Text, label.TextSize, label.TextColor3 = value, size or 16, color or UI.Colors.Text
	label.TextWrapped, label.TextXAlignment, label.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
	label.Font, label.Parent = bold and Enum.Font.GothamBold or Enum.Font.Gotham, parent
	return label
end
function UI.button(parent, value, x, y, width, height, callback, color)
	local button = Instance.new("TextButton")
	button.Position, button.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
	button.Text, button.TextSize, button.Font = value, 15, Enum.Font.GothamBold
	button.TextColor3, button.BackgroundColor3, button.BorderSizePixel = UI.Colors.Text, color or UI.Colors.Raised, 0
	button.AutoButtonColor, button.Parent = true, parent
	UI.round(button, 8)
	button.Activated:Connect(callback)
	return button
end
function UI.bar(parent, x, y, width, height, color)
	local back = UI.round(UI.frame(parent, "Track", x, y, width, height, UI.Colors.Raised), 5)
	local fill = UI.round(UI.frame(back, "Fill", 0, 0, width, height, color), 5)
	back.ClipsDescendants = true
	return function(ratio) fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0) end
end
return UI
