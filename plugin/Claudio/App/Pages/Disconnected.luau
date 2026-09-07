--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Parent.Components.Button)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "DisconnectedPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,

		Create "UIListLayout" {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
		},
		Create "TextLabel" {
			Size = UDim2.fromScale(0.8, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			Text = "Not connected to the bridge.",
		},
		Button {
			Text = "Connect",
			Primary = true,
			OnClick = function()
				task.spawn(Client.Connect)
			end,
		},
	}
end