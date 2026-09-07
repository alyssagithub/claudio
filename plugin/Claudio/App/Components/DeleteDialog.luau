--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)

const Create = Vide.create

const function Title(): string
	const Id = Chat.Confirming()

	for _, Summary in Chat.Conversations() do
		if Summary.id == Id then
			return Summary.title
		end
	end

	return "This chat"
end

return function()
	return Create "Frame" {
		Name = "DeleteDialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.5,
		ZIndex = 200,
		Visible = function()
			return Chat.Confirming() ~= nil
		end,

		Create "TextButton" {
			Name = "Catcher",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 200,
			Activated = function()
				Chat.Confirming(nil)
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
				Text = "Delete chat?",
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
					return `"{Title()}" will be permanently deleted. This can't be undone.`
				end,
			},
			Create "Frame" {
				Name = "Actions",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 3,

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
						Chat.Confirming(nil)
					end,
				},
				Button {
					Text = "Delete",
					Danger = true,
					LayoutOrder = 2,
					OnClick = function()
						const Id = Chat.Confirming()

						Chat.Confirming(nil)

						if not Id then
							return
						end

						task.spawn(Chat.Delete, Id)
					end,
				},
			},
		},
	}
end