--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Config = require(script.Parent.Parent.Parent.Config)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)
const Button = require(script.Parent.Button)

const Create = Vide.create

const Limits = {}

function Limits.Card(Error: () -> string, Retry: () -> (), LayoutOrder: number)
	const Detailed = Vide.source(false)

	const function When(): string?
		return Format.ResetsAt(Error())
	end

	const function Auto(): boolean
		return Settings.Get("AutoContinue")() == true
	end

	return Create "Frame" {
		Name = "LimitCard",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Background,
		LayoutOrder = LayoutOrder,

		Create "UICorner" {CornerRadius = UDim.new(0, 8)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 6),
		},
		Create "Frame" {
			Name = "Heading",
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Icon {
				Name = Config.Icons.Limit,
				Size = Settings.TextSize,
				Colour = Theme.Colors.Error,
				LayoutOrder = 1,
			},
			Create "TextLabel" {
				Name = "Title",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				Text = "Out of usage credits",
			},
		},
		Create "TextLabel" {
			Name = "Detail",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Text = function()
				const Clock = When()

				if Auto() then
					return if Clock then `Auto-resuming at {Clock}` else "Auto-resuming when the limit resets"
				end

				return if Clock then `Buy credits to keep working. Your session limit resets at {Clock}.` else "Buy credits to keep working, or wait for the limit to reset."
			end,
		},
		Create "TextButton" {
			Name = "AutoContinue",
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = 3,
			Activated = function()
				Settings.Set("AutoContinue", not Auto())
			end,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Create "Frame" {
				Name = "Box",
				Size = UDim2.fromOffset(13, 13),
				BackgroundColor3 = function()
					return if Auto() then Theme.Colors.Accent() else Theme.Colors.Input()
				end,
				LayoutOrder = 1,

				Create "UICorner" {CornerRadius = UDim.new(0, 3)},
				Create "UIStroke" {
					Color = function()
						return if Auto() then Theme.Colors.Accent() else Theme.Colors.Border()
					end,
				},
				Icon {
					Name = Config.Icons.Chosen,
					Size = Settings.SmallText,
					Colour = Theme.Colors.AccentText,
					Visible = Auto,
				},
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
				Text = "Auto-continue when limits reset",
			},
		},
		Create "TextLabel" {
			Name = "Said",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Code,
			TextColor3 = Theme.Colors.CodeText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 4,
			Visible = Detailed,
			Text = Error,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},
		},
		Create "Frame" {
			Name = "Actions",
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			LayoutOrder = 5,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Button {
				Text = function()
					return if Detailed() then "Hide details" else "View details"
				end,
				LayoutOrder = 1,
				OnClick = function()
					Detailed(not Detailed())
				end,
			},
			Create "Frame" {
				Name = "Spacer",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Button {
				Text = "Try again",
				LayoutOrder = 3,
				OnClick = Retry,
			},
		},
	}
end

return Limits