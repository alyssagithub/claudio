--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Types = require(script.Parent.Parent.Parent.Types)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)
const IconButton = require(script.Parent.IconButton)

const Create = Vide.create

const function Queued(Entry: () -> Types.QueuedMessage, Index: number)
	const Hovered = Vide.source(false)
	const Room = Vide.source(0)

	return Create "Frame" {
		Name = "Queued",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Index,
		Vide.action(Covers.Hover(Hovered)),

		Vide.action(function(Frame: Frame)
			Room(Frame.AbsoluteSize.X)
			Vide.cleanup(Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				Room(Frame.AbsoluteSize.X)
			end))
		end),
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
		},
		Create "TextButton" {
			Name = "Bubble",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Theme.Colors.Panel,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = 1,

			Create "UISizeConstraint" {
				MaxSize = function()
					return Vector2.new(math.max(40, math.floor(Room() * 0.85)), math.huge)
				end,
			},
			Create "UICorner" {CornerRadius = UDim.new(0, 8)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			Create "TextBox" {
				Name = "Text",
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				Text = function()
					return Entry().Display
				end,

				Create "UISizeConstraint" {
					MaxSize = function()
						return Vector2.new(math.max(20, math.floor(Room() * 0.85) - 20), math.huge)
					end,
				},
				Vide.action(function(Box: TextBox)
					Vide.cleanup(Box.FocusLost:Connect(function()
						Chat.EditQueued(Index, Box.Text)
					end))
				end),
			},
		},
		Create "Frame" {
			Name = "Actions",
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			LayoutOrder = 2,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			},
			Create "TextLabel" {
				Name = "Unread",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				LayoutOrder = 0,
				Visible = Hovered,
				Text = "Unread",
			},
			IconButton {
				Icon = Config.Icons.Copy,
				LayoutOrder = 1,
				Size = Settings.SmallText,
				Visible = Hovered,
				OnClick = function()
					task.spawn(Chat.Copy, Entry().Display)
				end,
			},
			IconButton {
				Icon = Config.Icons.Up,
				LayoutOrder = 2,
				Size = Settings.SmallText,
				Visible = function()
					return Hovered() and Index > 1
				end,
				OnClick = function()
					Chat.MoveQueued(Index, -1)
				end,
			},
			IconButton {
				Icon = Config.Icons.Down,
				LayoutOrder = 3,
				Size = Settings.SmallText,
				Visible = function()
					return Hovered() and Index < #Chat.Queue()
				end,
				OnClick = function()
					Chat.MoveQueued(Index, 1)
				end,
			},
			IconButton {
				Icon = Config.Icons.Close,
				LayoutOrder = 4,
				Size = Settings.SmallText,
				Visible = function()
					return Hovered() or Index == 1 or Entry().Sent == true
				end,
				OnClick = function()
					task.spawn(Chat.RemoveQueued, Index)
				end,
			},
			Create "TextButton" {
				Name = "SendNow",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = function()
					return if Hovered() then Theme.Colors.Text() else Theme.Colors.DimText()
				end,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				AutoButtonColor = false,
				LayoutOrder = 5,
				Text = "Send now",
				Visible = function()
					return Hovered() or Index == 1 or Entry().Sent == true
				end,
				Activated = function()
					Chat.InterruptWith(Index)
				end,
			},
		},
	}
end

return function()
	return Create "Frame" {
		Name = "QueueBar",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = function()
			return #Chat.Queue() > 0
		end,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Vide.indexes(Chat.Queue, Queued),
	}
end