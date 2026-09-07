--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "UpdateBanner",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 0,
		Visible = function()
			return Chat.UpdateWanted()
		end,

		Create "UIStroke" {Color = Theme.Colors.Accent},
		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 6),
		},
		Create "TextLabel" {
			Name = "Message",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Text = function()
				const Found = Chat.Versions()

				return if Found and Found.latest then `Claudio {Found.latest} is available. You have {Chat.Installed()}.` else ""
			end,
		},
		Create "Frame" {
			Name = "Actions",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Button {
				Text = "Not now",
				LayoutOrder = 1,
				OnClick = function()
					Chat.DeclineUpdate()
				end,
			},
			Button {
				Text = "Update",
				Primary = true,
				LayoutOrder = 2,
				OnClick = function()
					const Found = Chat.Versions()

					if not Found or not Found.latest then
						return
					end

					task.spawn(Chat.InstallVersion, Found.latest)
				end,
			},
		},
	}
end