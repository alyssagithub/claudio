--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Error = require(script.Parent.Parent.Parent.Client.Error)
const Connection = require(script.Parent.Parent.Parent.Store.Connection)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Parent.Components.Button)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "ErrorPage",
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
			TextColor3 = Theme.Colors.Error,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			Text = function()
				return Error.Describe(Connection.ErrorKind() or "Unknown")
			end,
		},
		Button {
			Text = "Retry",
			Primary = true,
			OnClick = function()
				task.spawn(Client.Connect)
			end,
		},
	}
end