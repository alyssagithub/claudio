--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

const function Row(IconName: string, Label: string, LayoutOrder: number, Add: () -> string?, Insert: (string) -> (), Close: () -> ())
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Option",
		Size = UDim2.new(1, 0, 0, 21),
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() then 0.2 else 1
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
		Vide.action(Covers.Hover(Hovered)),

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Icon {
			Name = IconName,
			Size = Settings.SmallText,
			Colour = Theme.Colors.Text,
			LayoutOrder = 1,
		},
		Create "TextLabel" {
			Name = "Label",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
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
		Vide.action(Covers.Add),
		-- Sits at the add button with no size, so the menu floats over the message box without moving anything.
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 20,
		Visible = Open,

		Create "Frame" {
			Name = "Options",
			AnchorPoint = Vector2.new(0, 1),
			Position = function()
				return UDim2.fromOffset(0, -6)
			end,
			ZIndex = 20,
			Size = UDim2.fromOffset(165, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Input,

			Create "UICorner" {CornerRadius = UDim.new(0, 8)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 0),
			},
			Row(Config.Icons.File, "Add files or photos", 1, Context.ImportFiles, Insert, Close),
			Row(Config.Icons.Script, "Add editor script", 2, Context.AddOpenScript, Insert, Close),
			Row(Config.Icons.Selection, "Add selected objects", 3, Context.AddSelection, Insert, Close),
			Row(Config.Icons.Output, "Add output", 4, Context.AddOutput, Insert, Close),
		},
	}
end