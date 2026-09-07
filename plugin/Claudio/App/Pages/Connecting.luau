--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

return function()
	return Vide.create "TextLabel" {
		Name = "ConnectingPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		TextColor3 = Theme.Colors.DimText,
		TextSize = Settings.TextSize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		Text = "Connecting to the bridge…",
	}
end