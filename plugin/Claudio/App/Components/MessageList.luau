--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Types = require(script.Parent.Parent.Parent.Types)
const Theme = require(script.Parent.Parent.Theme)
const Format = require(script.Parent.Parent.Parent.Format)
const IconButton = require(script.Parent.IconButton)
const Working = require(script.Parent.Working)
const MessageBubble = require(script.Parent.MessageBubble)
const PermissionCard = require(script.Parent.PermissionCard)

const Tips = {
	"Send another message while Claude is working and it waits its turn.",
	"Hover a reply and choose Rewind to undo what it changed.",
	"Object paths in a reply are links. Click one to select it.",
	"Chats can be pinned, renamed, forked or archived from the list.",
	"Copy an image anywhere and paste it straight into the box.",
	"The usage panel shows what this chat has cost so far.",
	"Ctrl+Z takes back a whole reply, not one change at a time.",
	"Switch on the playtest picker in settings to grab objects mid-game.",
}

type Windowed = {Index: number, Message: Types.Message}

const Create = Vide.create

const function Describe(Model: string?, Effort: string?, Auto: boolean?): string?
	if not Model or not Auto then
		return nil
	end

	const Named = Format.Model(Model)

	return if Effort and Effort ~= "none" then `Auto mode picked {Named} at {Effort} effort for this message` else `Auto mode picked {Named} for this message`
end

const function Queued(Entry: () -> Types.QueuedMessage, Index: number)
	const Hovered = Vide.source(false)

	return Create "Frame" {
		Name = "Queued",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 900000 + Index,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 2),
		},
		Create "TextButton" {
			Name = "Bubble",
			Size = UDim2.fromScale(0.85, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.35,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = 1,

			Create "UICorner" {CornerRadius = UDim.new(0, 8)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			Create "TextBox" {
				Name = "Text",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				Text = function()
					return Entry().Display
				end,

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
				Padding = UDim.new(0, 4),
			},
			IconButton {
				Icon = Config.Icons.Up,
				LayoutOrder = 1,
				Size = Settings.SmallText,
				Visible = function()
					return Hovered() and #Chat.Queue() > 1
				end,
				OnClick = function()
					Chat.MoveQueued(Index, -1)
				end,
			},
			IconButton {
				Icon = Config.Icons.Down,
				LayoutOrder = 2,
				Size = Settings.SmallText,
				Visible = function()
					return Hovered() and #Chat.Queue() > 1
				end,
				OnClick = function()
					Chat.MoveQueued(Index, 1)
				end,
			},
			Create "TextButton" {
				Name = "Interrupt",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				AutoButtonColor = false,
				LayoutOrder = 3,
				Visible = Hovered,
				Text = "Interrupt",
				Activated = function()
					Chat.InterruptWith(Index)
				end,
			},
			IconButton {
				Icon = Config.Icons.Close,
				LayoutOrder = 4,
				Size = Settings.SmallText,
				Visible = Hovered,
				OnClick = function()
					Chat.RemoveQueued(Index)
				end,
			},
		},
	}
end

const function Another(Last: string): string
	if #Tips < 2 then
		return Tips[1]
	end

	local Picked = Tips[math.random(#Tips)]

	while Picked == Last do
		Picked = Tips[math.random(#Tips)]
	end

	return Picked
end

return function()
	const Shown = Vide.source(Another(""))

	Vide.effect(function()
		Chat.ConversationId()

		if #Chat.Messages() == 0 then
			Shown(Another(Vide.untrack(Shown)))
		end
	end)

	local NearBottom = true

	return Create "ScrollingFrame" {
		Name = "MessageList",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Border,
		LayoutOrder = 2,

		Vide.action(function(List: ScrollingFrame)
			const function Reveal(Index: number)
				const Anchor = Chat.Anchors[Index] :: GuiObject?

				if not Anchor or not Anchor.Parent then
					return false
				end

				NearBottom = false
				List.CanvasPosition = Vector2.new(0, math.max(0, Anchor.AbsolutePosition.Y - List.AbsolutePosition.Y + List.CanvasPosition.Y - 8))

				return true
			end

			Chat.ScrollTo = function(Index: number)
				const Needed = #Chat.Messages() - Index + 1

				if Needed > Chat.Shown() then
					Chat.Shown(Needed + 5)
				end

				if Reveal(Index) then
					return
				end

				task.spawn(function()
					for _ = 1, 30 do
						task.wait()

						if Reveal(Index) then
							return
						end
					end
				end)
			end

			Vide.cleanup(function()
				Chat.ScrollTo = nil
			end)
			const function RequestVisible()
				for Index, Anchor in Chat.Anchors do
					const Object = Anchor :: GuiObject

					if not Object.Parent then
						continue
					end

					const Top = Object.AbsolutePosition.Y - List.AbsolutePosition.Y

					if Top > -600 and Top < List.AbsoluteWindowSize.Y + 600 then
						Chat.RequestImages(Index)
					end
				end
			end

			Vide.cleanup(List:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				NearBottom = List.AbsoluteCanvasSize.Y - (List.CanvasPosition.Y + List.AbsoluteWindowSize.Y) < 40
				RequestVisible()
			end))
			Vide.cleanup(List:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(RequestVisible))
			task.defer(RequestVisible)
			Vide.cleanup(List:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
				if not NearBottom then
					return
				end

				List.CanvasPosition = Vector2.new(0, List.AbsoluteCanvasSize.Y)
			end))
		end),
		Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		},
		Create "TextLabel" {
			Name = "Empty",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			Text = "Describe a task or ask a question to Claude",
			Visible = function()
				return #Chat.Messages() == 0
			end,
		},
		Create "TextLabel" {
			Name = "EmptyTip",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextTransparency = 0.25,
			Text = function()
				return `Tip: {Shown()}`
			end,
			Visible = function()
				return #Chat.Messages() == 0
			end,
		},
		Create "TextButton" {
			Name = "Earlier",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Button,
			TextColor3 = Theme.Colors.ButtonText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			AutoButtonColor = true,
			LayoutOrder = 0,
			Visible = function()
				return #Chat.Messages() > Chat.Shown()
			end,
			Text = function()
				return `Show earlier messages ({#Chat.Messages() - Chat.Shown()} more)`
			end,
			Activated = function()
				Chat.Shown(Chat.Shown() + 40)
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			},
		},
		Vide.indexes(function()
			const Messages = Chat.Messages()
			const First = math.max(1, #Messages - Chat.Shown() + 1)
			const Window: {Windowed} = {}

			for Index = First, #Messages do
				table.insert(Window, {
					Index = Index,
					Message = Messages[Index],
				})
			end

			return Window
		end, function(Entry: () -> Windowed, _)
			const function Message()
				return Entry().Message
			end

			const function Position(): number
				return Entry().Index
			end

			const Bubble = MessageBubble {
				Role = function()
					return Message().Role
				end,
				Text = function()
					return Message().Text
				end,
				Activity = function()
					return Message().Activity or {}
				end,
				Thinking = function()
					return Message().Thinking
				end,
				Attachments = function()
					return Message().Attachments or {}
				end,
				Images = function()
					return Message().Images or {}
				end,
				Model = function()
					return Describe(Message().Model, Message().Effort, Message().Auto)
				end,
				Calls = function()
					return Message().Calls or {}
				end,
				Edits = function()
					return Message().Edits
				end,
				Tokens = function()
					return Message().Tokens
				end,
				Milliseconds = function()
					return Message().Milliseconds
				end,
				Failed = function()
					return Message().Failed == true
				end,
				Cost = function()
					return Message().Cost
				end,
				Estimated = function()
					return Message().Estimated
				end,
				Prompt = function()
					return Message().Prompt
				end,
				At = function()
					return Message().At
				end,
				Checkpoint = function()
					return Message().Checkpoint
				end,
				Index = Position,
				LayoutOrder = function()
					return Position()
				end,
			}

			Vide.effect(function()
				const At = Position()

				Chat.Anchors[At] = Bubble
				Vide.cleanup(function()
					if Chat.Anchors[At] == Bubble then
						Chat.Anchors[At] = nil
					end
				end)
			end)

			return Bubble
		end),
		Create "Frame" {
			Name = "Streaming",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1000000,
			Visible = Chat.Sending,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 6),
			},
			MessageBubble {
				Role = function()
					return "assistant"
				end,
				Text = Chat.StreamingText,
				Activity = function()
					return {}
				end,
				Thinking = Chat.StreamingThinking,
				Calls = Chat.Calls,
				Images = Chat.StreamingImages,
				LayoutOrder = 1,
			},
			Working(),
		},
		PermissionCard(),
		Vide.indexes(Chat.Queue, Queued),
	}
end