--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "PermissionCard",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 1500000,
		Visible = function()
			return Chat.Permission() ~= nil
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 8)},
		Create "UIStroke" {
			Color = Theme.Colors.Accent,
			Thickness = 1.5,
		},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Create "TextLabel" {
			Name = "Title",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Text = function()
				const Permission = Chat.Permission()

				return if Permission then `Claude wants to use {Permission.tool:gsub("^mcp__.-__", "")}` else ""
			end,
		},
		Create "TextLabel" {
			Name = "Input",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Code,
			TextColor3 = Theme.Colors.CodeText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextWrapped = true,
			RichText = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Text = function()
				const Permission = Chat.Permission()

				return if Permission then Permission.input else ""
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},
		},
		Create "Frame" {
			Name = "Buttons",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 3,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Button {
				Text = "Allow",
				Primary = true,
				LayoutOrder = 1,
				OnClick = function()
					Chat.Answer(true, false)
				end,
			},
			Button {
				Text = "Allow for this chat",
				LayoutOrder = 2,
				OnClick = function()
					Chat.Answer(true, true)
				end,
			},
			Button {
				Text = "Deny",
				LayoutOrder = 3,
				OnClick = function()
					Chat.Answer(false, false)
				end,
			},
		},
	}
end