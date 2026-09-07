--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)

const Create = Vide.create

const function Undoing(): {string}
	const Index = Chat.Rewinding()

	return if Index then Chat.Undoing(Index) else {}
end

return function()
	return Create "Frame" {
		Name = "RewindDialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.5,
		ZIndex = 200,
		Visible = function()
			return Chat.Rewinding() ~= nil
		end,

		Create "TextButton" {
			Name = "Catcher",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 200,
			Activated = function()
				Chat.Rewinding(nil)
			end,
		},
		Create "Frame" {
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -32, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			ZIndex = 201,

			Create "UISizeConstraint" {MaxSize = Vector2.new(360, math.huge)},
			Create "UICorner" {CornerRadius = UDim.new(0, 10)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 8),
			},
			Create "TextLabel" {
				Name = "Heading",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Text = "Rewind to here?",
			},
			Create "TextLabel" {
				Name = "Body",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				Text = function()
					const Lines = Undoing()

					if #Lines == 0 then
						return "Studio will undo everything Claude did from this message onwards. Nothing was recorded as changed, so there may be nothing to undo."
					end

					return `Studio will undo everything from this message onwards, including {#Lines} recorded change{if #Lines == 1 then "" else "s"}:`
				end,
			},
			Vide.indexes(Undoing, function(Text: () -> string, Index: number)
				return Create "TextLabel" {
					Name = "Change",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2 + Index,
					Text = function()
						return `• {Text()}`
					end,
				}
			end),
			Create "Frame" {
				Name = "Actions",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1000,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				},
				Button {
					Text = "Cancel",
					LayoutOrder = 1,
					OnClick = function()
						Chat.Rewinding(nil)
					end,
				},
				Button {
					Text = "Rewind",
					Danger = true,
					LayoutOrder = 2,
					OnClick = function()
						const Index = Chat.Rewinding()

						Chat.Rewinding(nil)

						if not Index then
							return
						end

						task.spawn(Chat.Restore, Index)
					end,
				},
			},
		},
	}
end