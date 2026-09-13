--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

const function Row(IconName: string, Label: string, LayoutOrder: number, Add: () -> string?, Insert: (string) -> (), Close: () -> ())
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Option",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() then 0 else 1
		end,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = LayoutOrder,
		Activated = function()
			Close()

			const Token = Add()

			if not Token then
				return
			end

			Insert(Token)
		end,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		},
		Icon {
			Name = IconName,
			Size = Settings.TextSize,
			Colour = Theme.Colors.DimText,
			LayoutOrder = 1,
		},
		Create "TextLabel" {
			Name = "Label",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Text = Label,
		},
	}
end

return function(Open: (boolean?) -> boolean, Insert: (string) -> ())
	const function Close()
		Open(false)
	end

	return Create "Frame" {
		Name = "AddMenu",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Visible = Open,

		Create "Frame" {
			Name = "Options",
			Size = UDim2.fromOffset(220, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,

			Create "UICorner" {CornerRadius = UDim.new(0, 8)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 2),
			},
			Row(Config.Icons.Script, "Editor script", 1, Context.AddOpenScript, Insert, Close),
			Row(Config.Icons.Output, "Output", 2, Context.AddOutput, Insert, Close),
			Row(Config.Icons.Picture, "Image file", 3, Context.ImportImage, Insert, Close),
			Row(Config.Icons.Selection, "Selected objects", 4, Context.AddSelection, Insert, Close),
		},
	}
end