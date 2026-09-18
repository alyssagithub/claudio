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
	const Room = Vide.source(0)

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
				Visible = Hovered,
				OnClick = function()
					Chat.RemoveQueued(Index)
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
					return Hovered() or Index == 1
				end,
				Activated = function()
					Chat.InterruptWith(Index)
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
	local Holding = false

	const Loading = Vide.source(false)

	const function More(): boolean
		return #Chat.Messages() > Chat.Shown() or Chat.Earlier() > 0 or Chat.Partial()
	end

	const Ready = Vide.source(1)
	local Filling = 0

	Vide.effect(function()
		const Wanted = Chat.Shown()

		Chat.ConversationId()

		if Vide.untrack(Ready) >= Wanted then
			return
		end

		Filling += 1

		const Mine = Filling

		task.spawn(function()
			while Vide.untrack(Ready) < Wanted and Filling == Mine do
				task.wait()
				Ready(math.min(Wanted, Vide.untrack(Ready) + 2))
			end
		end)
	end)

	Vide.effect(function()
		Chat.ConversationId()
		Ready(1)
	end)

	const First = Vide.derive(function()
		return math.max(1, #Chat.Messages() - math.min(Chat.Shown(), Ready()) + 1)
	end)

	const Windowed = Vide.derive(function()
		const Messages = Chat.Messages()
		const Window: {Types.Message} = {}

		for Index = First(), #Messages do
			table.insert(Window, Messages[Index])
		end

		return Window
	end)

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
				const Anchor = Chat.Anchors[Index] :: any

				if not Anchor or not Anchor.Parent then
					return false
				end

				NearBottom = false
				List.CanvasPosition = Vector2.new(0, math.max(0, Anchor.AbsolutePosition.Y - List.AbsolutePosition.Y + List.CanvasPosition.Y - 8))

				return true
			end

			Chat.ScrollTo = function(Absolute: number)
				while Absolute <= Chat.Earlier() and Chat.Earlier() > 0 do
					const Was = Chat.Earlier()

					Chat.LoadEarlier()

					if Chat.Earlier() == Was then
						break
					end
				end

				const Index = Absolute - Chat.Earlier()
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

			local Measured = 0
			local Check: () -> ()

			const function LoadMore()
				if Loading() or not More() then
					return
				end

				Loading(true)
				Holding = true
				Measured = List.AbsoluteCanvasSize.Y

				task.spawn(function()
					if #Chat.Messages() > Chat.Shown() then
						Chat.Shown(Chat.Shown() + Chat.Fits(Chat.Messages(), #Chat.Messages() - Chat.Shown()))
					else
						Chat.LoadEarlier()
					end

					while Ready() < Chat.Shown() do
						task.wait()
					end

					task.wait(0.1)
					Holding = false
					Loading(false)
					task.defer(Check)
				end)
			end

			Check = function()
				const Overflowing = List.AbsoluteCanvasSize.Y > List.AbsoluteWindowSize.Y

				if Holding or List.CanvasPosition.Y >= 150 or (Overflowing and NearBottom) then
					return
				end

				LoadMore()
			end

			Vide.cleanup(List:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				NearBottom = List.AbsoluteCanvasSize.Y - (List.CanvasPosition.Y + List.AbsoluteWindowSize.Y) < 40
				RequestVisible()
				Check()
			end))
			Vide.cleanup(List:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(RequestVisible))
			task.defer(RequestVisible)
			Vide.cleanup(List:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
				if Holding then
					const Grown = List.AbsoluteCanvasSize.Y - Measured

					Measured = List.AbsoluteCanvasSize.Y
					List.CanvasPosition = Vector2.new(0, math.max(0, List.CanvasPosition.Y + Grown))

					return
				end

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
		Create "TextLabel" {
			Name = "Earlier",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			LayoutOrder = 0,
			Visible = Loading,
			Text = "Loading earlier messages…",
		},
		Vide.values(Windowed, function(Message: Types.Message, IndexSource: () -> number)
			const function Position(): number
				return First() + IndexSource() - 1
			end

			const Bubble = MessageBubble {
				Role = function()
					return Message.Role
				end,
				Text = function()
					return Message.Text
				end,
				Activity = function()
					return Message.Activity or {}
				end,
				Thinking = function()
					return Message.Thinking
				end,
				Parts = function()
					return Message.Parts
				end,
				Attachments = function()
					return Message.Attachments or {}
				end,
				Images = function()
					return Message.Images or {}
				end,
				Model = function()
					return Describe(Message.Model, Message.Effort, Message.Auto)
				end,
				Calls = function()
					return Message.Calls or {}
				end,
				Edits = function()
					return Message.Edits
				end,
				Tokens = function()
					return Message.Tokens
				end,
				Milliseconds = function()
					return Message.Milliseconds
				end,
				Failed = function()
					return Message.Failed == true
				end,
				Error = function()
					return Message.Error
				end,
				Cost = function()
					return Message.Cost
				end,
				Estimated = function()
					return Message.Estimated
				end,
				Prompt = function()
					return Message.Prompt
				end,
				At = function()
					return Message.At
				end,
				Checkpoint = function()
					return Message.Checkpoint
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
				Parts = Chat.StreamingParts,
				Calls = Chat.Calls,
				Images = Chat.StreamingImages,
				Model = function()
					const Pick = Chat.StreamingPick()

					return if Pick then Describe(Pick.Model, Pick.Effort, true) else nil
				end,
				Live = true,
				LayoutOrder = 1,
			},
			Working(),
		},
		PermissionCard(),
		Vide.indexes(Chat.Queue, Queued),
	}
end