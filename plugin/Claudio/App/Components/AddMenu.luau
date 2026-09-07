--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

const function Row(IconName: string, Label: string, Detail: string, LayoutOrder: number, Add: () -> string?, Insert: (string) -> (), Close: () -> ())
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Option",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
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

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		},
		Icon {
			Name = IconName,
			Size = Settings.TextSize,
		},
		Create "Frame" {
			Name = "Labels",
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},
			Create "TextLabel" {
				Name = "Label",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Text = Label,
			},
			Create "TextLabel" {
				Name = "Detail",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				Text = Detail,
			},
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
		BackgroundColor3 = Theme.Colors.Background,
		LayoutOrder = 1,
		Visible = Open,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
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
		Create "TextLabel" {
			Name = "DragHint",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Text = "For objects, drag them here from the Explorer.",

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 6),
			},
		},
		Row(Config.Icons.Script, "Editor script", "The script you have open in the editor, with its source", 2, Context.AddOpenScript, Insert, Close),
		Row(Config.Icons.Output, "Output", "The last 50 lines of the Output window", 3, Context.AddOutput, Insert, Close),
		Row(Config.Icons.Picture, "Image file", "Pick a picture file from your computer", 4, Context.ImportImage, Insert, Close),
	}
end