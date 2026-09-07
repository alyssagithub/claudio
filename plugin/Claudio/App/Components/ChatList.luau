--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

const function When(Stamp: number): string
	if Stamp <= 0 then
		return "unknown"
	end

	const Ok, Text = pcall(function()
		return (os.date("%b %d", Stamp // 1000):gsub(" 0", " ", 1))
	end)

	return if Ok then Text else "unknown"
end

-- Counting whole calendar days rather than elapsed seconds, so a clock that
-- crosses a daylight saving change does not shift what counts as yesterday.
const function DayNumber(Stamp: number): number
	const Ok, Text = pcall(function()
		return os.date("%Y-%m-%d", Stamp // 1000)
	end)

	const Stamped = if Ok then Text else ""
	const Year = tonumber(Stamped:sub(1, 4))
	const Months = tonumber(Stamped:sub(6, 7))
	const Day = tonumber(Stamped:sub(9, 10))

	if not Year or not Months or not Day then
		return 0
	end

	const Shifted = Year - (if Months <= 2 then 1 else 0)
	const Era = math.floor(Shifted / 400)
	const YearOfEra = Shifted - Era * 400
	const DayOfYear = math.floor((153 * (Months + (if Months > 2 then -3 else 9)) + 2) / 5) + Day - 1

	return Era * 146097 + YearOfEra * 365 + math.floor(YearOfEra / 4) - math.floor(YearOfEra / 100) + DayOfYear - 719468
end

const function Named(Stamp: number): string
	const Gap = DayNumber(os.time() * 1000) - DayNumber(Stamp)

	if Gap == 0 then
		return "Today"
	end

	if Gap == 1 then
		return "Yesterday"
	end

	return When(Stamp)
end

const function Spanned(Began: number, Ended: number): string
	const Gap = DayNumber(os.time() * 1000) - DayNumber(Ended)
	const Ago = if Gap > 1 then ` ({Gap} days ago)` else ""

	if DayNumber(Began) == DayNumber(Ended) then
		return `{Named(Ended)}{Ago}`
	end

	return `{Named(Began)} - {Named(Ended)}{Ago}`
end

const function Choice(Label: () -> string, LayoutOrder: number, OnClick: () -> ())
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Choice",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() then 0 else 1
		end,
		TextColor3 = Theme.Colors.Text,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		LayoutOrder = LayoutOrder,
		Text = Label,
		Activated = OnClick,
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
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
	}
end

const function GroupOf(Summary: Types.ConversationSummary): string
	return if Summary.project ~= "" then Summary.project else "Other"
end

const function Ordered(): {Types.ConversationSummary}
	const Folder = Settings.Get("WorkingFolder")()
	const Here = Folder:match("[^\/]+$") or Folder
	const Sorted = table.clone(Chat.Conversations())

	table.sort(Sorted, function(Left, Right)
		const LeftGroup = GroupOf(Left)
		const RightGroup = GroupOf(Right)

		if LeftGroup ~= RightGroup then
			if LeftGroup == Here or RightGroup == Here then
				return LeftGroup == Here
			end

			if LeftGroup == "Other" or RightGroup == "Other" then
				return RightGroup == "Other"
			end

			return LeftGroup < RightGroup
		end

		if Left.starred ~= Right.starred then
			return Left.starred == true
		end

		return Left.updatedAt > Right.updatedAt
	end)

	return Sorted
end

const function Row(Summary: () -> Types.ConversationSummary, Index: number)
	const function IsCurrent(): boolean
		return Chat.ConversationId() == Summary().id
	end

	const Button = Create "TextButton" {
		Name = "Row",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = function()
			return if IsCurrent() then Theme.Colors.Accent() else Theme.Colors.Panel()
		end,
		BackgroundTransparency = function()
			return if IsCurrent() then 0.7 else 0
		end,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = Index,
		Visible = function()
			return Chat.ShowArchived() or not Summary().archived
		end,
		Activated = function()
			if Chat.MenuFor() then
				Chat.MenuFor(nil)

				return
			end

			task.spawn(Chat.Open, Summary().id)
		end,

		Vide.action(function(Object: TextButton)
			Vide.cleanup(Object.MouseButton2Click:Connect(function()
				Chat.Renaming(nil)

				if Chat.Window then
					const Where = Chat.Window:GetRelativeMousePosition()
					const Room = Chat.Window.AbsoluteSize

					Chat.MenuPosition(Vector2.new(math.min(Where.X, math.max(0, Room.X - 160)), math.min(Where.Y, math.max(0, Room.Y - 120))))
				end

				Chat.MenuFor(Summary().id)
			end))
		end),
		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 4),
		},
		Create "Frame" {
			Name = "Labels",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 2),
			},
			Create "Frame" {
				Name = "Heading",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				},
				Icon {
					Name = Config.Icons.Pin,
					Size = Settings.SmallText,
					Colour = Theme.Colors.DimText,
					LayoutOrder = 1,
					Visible = function()
						return Summary().starred == true
					end,
				},
				Create "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 2,
					Visible = function()
						return Chat.Renaming() ~= Summary().id
					end,
					Text = function()
						return Summary().title
					end,

					Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				},
				Create "TextBox" {
					Name = "Rename",
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Colors.Input,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					LayoutOrder = 3,
					Visible = function()
						return Chat.Renaming() == Summary().id
					end,
					Text = function()
						return Summary().title
					end,

					Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
					Create "UICorner" {CornerRadius = UDim.new(0, 4)},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					},
					Vide.action(function(Box: TextBox)
						Vide.cleanup(Box.FocusLost:Connect(function(Entered: boolean)
							const Editing = Chat.Renaming()

							if not Entered or Box.Text == "" or not Editing then
								Chat.Renaming(nil)

								return
							end

							task.spawn(Chat.Rename, Editing, Box.Text)
						end))
						Vide.cleanup(Box:GetPropertyChangedSignal("Visible"):Connect(function()
							if not Box.Visible then
								return
							end

							Box:CaptureFocus()
							Box.CursorPosition = #Box.Text + 1
						end))
					end),
				},
			},
			Create "TextLabel" {
				Name = "When",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 2,
				Text = function()
					const Mark = if Summary().archived then " · Archived" else ""

					return `{Spanned(Summary().createdAt, Summary().updatedAt)}{Mark}`
				end,
			},
		},
	}

	return Create "Frame" {
		Name = "Group",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Index,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		},
		Create "TextLabel" {
			Name = "Heading",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
			Visible = function()
				const List = Ordered()
				const Mine = List[Index]

				if not Mine then
					return false
				end

				return List[Index - 1] == nil or GroupOf(List[Index - 1]) ~= GroupOf(Mine)
			end,
			Text = function()
				const Mine = Ordered()[Index]

				return if Mine then GroupOf(Mine) else ""
			end,

			Create "UIPadding" {PaddingTop = UDim.new(0, 6)},
		},
		Button,
	}
end

return function()
	return Create "ScrollingFrame" {
		Name = "ChatList",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Border,
		LayoutOrder = 2,

		Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
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
			Text = function()
				return Chat.Notice() or "No chats yet. Press New to start one, or open one in the Claude desktop app."
			end,
			Visible = function()
				return #Chat.Conversations() == 0
			end,
		},
		Vide.indexes(Ordered, Row),
		Choice(function()
			return if Chat.ShowArchived() then "Hide archived chats" else "Show archived chats"
		end, 1000000, function()
			Chat.ShowArchived(not Chat.ShowArchived())
		end),
	}
end