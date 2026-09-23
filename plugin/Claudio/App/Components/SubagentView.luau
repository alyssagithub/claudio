--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const MessageBubble = require(script.Parent.MessageBubble)

const Create = Vide.create

return function()
	return Create "ScrollingFrame" {
		Name = "SubagentView",
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Colors.Border,
		LayoutOrder = 1,
		Visible = function()
			return Chat.Viewing() ~= nil
		end,

		Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 10),
		},
		Create "TextLabel" {
			Name = "Waiting",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
			Visible = function()
				return #Chat.Watched() == 0
			end,
			Text = "Waiting for this subagent to write anything",
		},
		Vide.indexes(Chat.Watched, function(Message: () -> Types.Message, Index: number)
			return MessageBubble {
				Role = function()
					return Message().Role
				end,
				Text = function()
					return Message().Text or ""
				end,
				Activity = function()
					return Message().Activity or {}
				end,
				Parts = function()
					return Message().Parts
				end,
				Calls = function()
					return Message().Calls or {}
				end,
				LayoutOrder = Index,
			}
		end),
	}
end