--!strict
const RunService = game:GetService("RunService")

const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Config = require(script.Parent.Parent.Parent.Config)
const Covers = require(script.Parent.Parent.Covers)
const ModelPicker = require(script.Parent.ModelPicker)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

const Edge = 18
const Kinds = {
	["5-hour usage"] = "five_hour",
	["Weekly usage"] = "seven_day",
}

return function()
	const Pulse = Vide.source(0)

	const function Loading(): boolean
		return Chat.ContextLoading() and #Chat.ContextParts() == 0
	end

	const function GetChosenLimit(): Types.Limit?
		const Chosen = Settings.Get("RingStat")()

		for _, Limit in Chat.Limits() do
			if Limit.kind == Kinds[Chosen] then
				return Limit
			end

			if Chosen == "Weekly Fable usage" and Limit.label and Limit.label:find("Fable") then
				return Limit
			end
		end

		return nil
	end

	const function GetUsedShare(): number
		if Settings.Get("RingStat")() == "Context" then
			const Total = Chat.ContextWindow()

			return if Total > 0 then math.clamp(Chat.ContextUsed() / Total, 0, 1) else 0
		end

		const Limit = GetChosenLimit()

		return if Limit and Limit.utilization then math.clamp(Limit.utilization, 0, 1) else 0
	end

	const function Colour(): Color3
		const Used = GetUsedShare()

		if Used >= 0.85 then
			return Theme.Colors.Error()
		end

		if Used >= 0.6 then
			return Color3.fromRGB(214, 158, 46)
		end

		return Theme.Colors.Accent()
	end

	const function Half(Side: string, Order: number)
		const function Portion(): number
			return math.clamp((GetUsedShare() - (Order - 1) * 0.5) / 0.5, 0, 1)
		end

		return Create "Frame" {
			Name = Side,
			Size = UDim2.fromOffset(Edge / 2, Edge),
			Position = UDim2.fromOffset(if Side == "Right" then Edge / 2 else 0, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,

			Create "Frame" {
				Name = "Wedge",
				Size = UDim2.fromOffset(Edge, Edge),
				Position = UDim2.fromOffset(if Side == "Right" then -Edge / 2 else 0, 0),
				BackgroundColor3 = Colour,
				BackgroundTransparency = function()
					return if Loading() and Settings.Get("RingStat")() == "Context" then 0.3 + 0.3 * math.sin(Pulse() * 4) else 0
				end,
				BorderSizePixel = 0,
				Visible = function()
					return Portion() > 0
				end,

				Create "UICorner" {CornerRadius = UDim.new(1, 0)},
				Create "UIGradient" {
					Rotation = function()
						return (Order - 1) * 180 + 180 * Portion()
					end,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.4999, 0),
						NumberSequenceKeypoint.new(0.5, 1),
						NumberSequenceKeypoint.new(1, 1),
					}),
				},
			},
		}
	end

	const Hovered = Vide.source(false)
	const Shown = Vide.source(false)
	const Shift = Vide.source(0)
	const Rightmost = Vide.source(0)
	const Room = Vide.source(220)
	const Below = Vide.source(0)
	const Waited = Vide.source(false)
	local Waiting = 0

	const function UpdatePosition(Object: GuiObject)
		const Row = Object.Parent :: GuiObject

		if not Row then
			return
		end

		Shift(Row.AbsolutePosition.X - Object.AbsolutePosition.X)
		Rightmost(Row.AbsolutePosition.X + Row.AbsoluteSize.X - Object.AbsolutePosition.X)
		Room(math.max(160, Row.AbsoluteSize.X))

		const Bar = Object:FindFirstAncestor("InputBar") :: GuiObject?

		if not Bar then
			return
		end

		Below(Bar.AbsolutePosition.Y + Bar.AbsoluteSize.Y - Object.AbsolutePosition.Y)
	end

	const function OnHover(Over: boolean)
		if Over == Vide.untrack(Hovered) then
			return
		end

		Waiting += 1
		Hovered(Over)

		if not Over then
			Waited(false)

			return
		end

		const Token = Waiting

		task.delay(1, function()
			if Waiting ~= Token then
				return
			end

			Waited(true)
		end)
	end

	const Expanded = Vide.source(false)

	const Shades = {
		Messages = Color3.fromRGB(51, 95, 255),
		["System tools"] = Color3.fromRGB(232, 106, 51),
		["MCP tools"] = Color3.fromRGB(64, 176, 108),
		Skills = Color3.fromRGB(214, 158, 46),
		["System prompt"] = Color3.fromRGB(140, 146, 168),
		["Memory files"] = Color3.fromRGB(198, 132, 244),
		["Autocompact buffer"] = Color3.fromRGB(96, 100, 118),
	}

	const function GetPartColour(Part: Types.Part): Color3
		return Shades[Part.name] or Color3.fromRGB(70, 74, 90)
	end

	const function GetFilledParts(): {Types.Part}
		if Loading() and Chat.ContextUsed() > 0 then
			return {
				{
					name = "Messages",
					tokens = Chat.ContextUsed(),
					colour = "",
					deferred = false,
				},
			}
		end

		const Found = {}

		for _, Part in Chat.ContextParts() do
			if Part.name ~= "Free space" and not Part.deferred and Part.tokens > 0 then
				table.insert(Found, Part)
			end
		end

		return Found
	end

	const function GetChatCost(): (number, boolean, boolean)
		local Total = 0
		local Guessed = false
		local Known = false

		for _, Message in Chat.Messages() do
			if not Message.Cost then
				continue
			end

			Total += Message.Cost

			if Message.Estimated then
				Guessed = true
			else
				Known = true
			end
		end

		return Total, Guessed, Known
	end

	const function GetContextText(): string
		const ContextSize = Chat.ContextWindow()

		return `{Format.Large(Chat.ContextUsed())} / {Format.Large(ContextSize)} ({math.round(Chat.ContextUsed() / ContextSize * 100)}%)`
	end

	const function GetRoomBeforeCompact(): number?
		local Free: number?
		local Buffered = false

		for _, Part in Chat.ContextParts() do
			if Part.name == "Free space" then
				Free = Part.tokens
			elseif Part.name == "Autocompact buffer" and Part.tokens > 0 then
				Buffered = true
			end
		end

		return if Buffered then Free else nil
	end

	const function Line(Left: () -> string, Right: () -> string, Strong: boolean, LayoutOrder: number, Arrow: (() -> boolean)?)
		return Create "Frame" {
			Name = "Line",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = LayoutOrder,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Create "TextLabel" {
				Name = "Left",
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = if Strong then Theme.Colors.Text else Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(if Strong then Enum.Font.BuilderSansMedium else Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Text = Left,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Create "TextLabel" {
				Name = "Right",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Right,
				LayoutOrder = 2,
				Text = Right,
			},
			Icon {
				Name = Config.Icons.Down,
				Size = Settings.SmallText,
				LayoutOrder = 3,
				Visible = function()
					return Arrow ~= nil
				end,
				Rotation = function()
					return if Arrow and Arrow() then 0 else -90
				end,
			},
		}
	end

	return Create "TextButton" {
		Name = "Usage",
		Size = UDim2.fromOffset(Edge, Edge),
		BackgroundColor3 = Theme.Colors.DimText,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 6,
		Activated = function()
			Waiting += 1
			Waited(false)
			Shown(not Shown())
		end,
		MouseEnter = function()
			OnHover(true)
		end,
		MouseLeave = function()
			OnHover(false)
		end,

		Vide.action(function(Object: GuiObject)
			Vide.cleanup(Object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				UpdatePosition(Object)
			end))
			task.defer(UpdatePosition, Object)
			Vide.cleanup(RunService.Heartbeat:Connect(function()
				if not Vide.untrack(Loading) then
					return
				end

				Pulse(os.clock())
			end))
		end),
		Create "UICorner" {CornerRadius = UDim.new(1, 0)},
		Half("Right", 1),
		Half("Left", 2),
		Create "Frame" {
			Name = "Hole",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(Edge - 6, Edge - 6),
			BackgroundColor3 = Theme.Colors.Panel,
			BorderSizePixel = 0,
			ZIndex = 5,

			Create "UICorner" {CornerRadius = UDim.new(1, 0)},
		},
		Create "Frame" {
			Name = "Tip",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = function()
				return UDim2.fromOffset(math.min(Room() - 16, 236), 0)
			end,
			AnchorPoint = Vector2.new(1, 1),
			Position = function()
				return UDim2.new(0, Rightmost(), 0, -10)
			end,
			BackgroundColor3 = Theme.Colors.Panel,
			ZIndex = 20,
			Visible = function()
				return Waited() and Hovered() and not Shown()
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
			Create "UIStroke" {
				Color = Theme.Colors.DimText,
				Transparency = 0.6,
			},
			Create "UISizeConstraint" {
				MaxSize = function()
					return Vector2.new(math.min(Room(), 240), math.huge)
				end,
			},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			},
			Create "TextLabel" {
				Name = "Headline",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 20,
				LayoutOrder = 1,
				Text = function()
					const ContextSize = Chat.ContextWindow()

					if ContextSize == 0 then
						return if Chat.ContextLoading() then "Loading context" else "Context fills in after the first reply"
					end

					return `Context {GetContextText()}`
				end,
			},
			Create "TextLabel" {
				Name = "Detail",
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				ZIndex = 20,
				LayoutOrder = 2,
				Text = function()
					const Limit = GetChosenLimit() or Chat.Limits()[1]
					const Parts: {string} = {}

					if Limit then
						const Name = (Limit.label or "5-hour limit"):gsub(" %- ", " · ")

						table.insert(Parts, if Limit.utilization then `{math.round(Limit.utilization * 100)}% of {Name:lower()}` else Name)
					end

					if Limit and Limit.resetsAt then
						table.insert(Parts, Format.Until(Limit.resetsAt))
					end

					return if #Parts == 0 then "No limit reported yet" else table.concat(Parts, " · ")
				end,
			},
		},
		Create "Frame" {
			Name = "Panel",
			Vide.action(Covers.Add),
			Size = function()
				return UDim2.fromOffset(Room(), 0)
			end,
			AutomaticSize = Enum.AutomaticSize.Y,
			AnchorPoint = Vector2.new(0, 1),
			Position = function()
				return UDim2.new(0, Shift(), 0, Below() - ModelPicker.BarHeight() - 6)
			end,
			BackgroundColor3 = Theme.Colors.Background,
			ZIndex = 30,
			Visible = Shown,

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
			Create "TextButton" {
				Name = "ContextRow",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = 1,
				Activated = function()
					Expanded(not Expanded())
				end,

				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
				},
				Line(function()
					return "Context window"
				end, function()
					const ContextSize = Chat.ContextWindow()

					if ContextSize == 0 then
						return if Chat.ContextLoading() then "" else "0"
					end

					return `{GetContextText()} `
				end, true, 1, Expanded),
			},
			Create "TextLabel" {
				Name = "UntilCompact",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 3,
				Visible = function()
					return not Loading() and GetRoomBeforeCompact() ~= nil
				end,
				Text = function()
					return `{Format.Large(GetRoomBeforeCompact() or 0)} until auto-compact`
				end,
			},
			Create "TextLabel" {
				Name = "Loading",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 3,
				Visible = Loading,
				Text = function()
					return `Loading breakdown{string.rep(".", math.floor(Pulse() * 2.5) % 3 + 1)}`
				end,
			},
			Create "Frame" {
				Name = "Segments",
				Size = UDim2.new(1, 0, 0, 6),
				BackgroundColor3 = Theme.Colors.Input,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				LayoutOrder = 2,

				Create "UICorner" {CornerRadius = UDim.new(1, 0)},
				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Vide.indexes(GetFilledParts, function(Part: () -> Types.Part, Index: number)
					return Create "Frame" {
						Name = "Segment",
						Size = function()
							const ContextSize = Chat.ContextWindow()

							return UDim2.fromScale(if ContextSize == 0 then 0 else Part().tokens / ContextSize, 1)
						end,
						BackgroundColor3 = function()
							return GetPartColour(Part())
						end,
						BorderSizePixel = 0,
						LayoutOrder = Index,
					}
				end),
			},
			Vide.indexes(function()
				return if Expanded() then Chat.ContextParts() else {}
			end, function(Part: () -> Types.Part, Index: number)
				return Create "Frame" {
					Name = "Part",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 3 + Index,

					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					},
					Create "Frame" {
						Name = "Swatch",
						Size = UDim2.fromOffset(8, 8),
						BackgroundColor3 = function()
							return GetPartColour(Part())
						end,
						BorderSizePixel = 0,
						LayoutOrder = 1,

						Create "UICorner" {CornerRadius = UDim.new(0, 2)},
					},
					Create "TextLabel" {
						Name = "Title",
						Size = UDim2.fromScale(0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = function()
							return if Part().deferred then Theme.Colors.DimText() else Theme.Colors.Text()
						end,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
						Text = function()
							return Part().name
						end,

						Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
					},
					Create "TextLabel" {
						Name = "Tokens",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Right,
						LayoutOrder = 3,
						Text = function()
							const ContextSize = Chat.ContextWindow()

							return `{Format.Large(Part().tokens)}{if ContextSize == 0 or Part().deferred then "" else `   {string.format("%.1f", Part().tokens / ContextSize * 100)}%`}`
						end,
					},
				}
			end),
			Create "Frame" {
				Name = "Divider",
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.Colors.DimText,
				BackgroundTransparency = 0.7,
				BorderSizePixel = 0,
				LayoutOrder = 100,
			},
			Line(function()
				return "Plan usage limits"
			end, function()
				return ""
			end, false, 101),
			Vide.indexes(Chat.Limits, function(Limit: () -> Types.Limit, Index: number)
				return Create "Frame" {
					Name = "Limit",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 101 + Index,

					Create "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						Padding = UDim.new(0, 3),
					},
					Line(function()
						return ((Limit().label or Limit().kind):gsub(" %- ", " · "))
					end, function()
						const Entry = Limit()

						return `{if Entry.resetsAt then Format.Until(Entry.resetsAt) else ""}{if Entry.utilization then `   {math.floor(Entry.utilization * 100)}%` else ""}`
					end, true, 1),
					Create "Frame" {
						Name = "Meter",
						Size = UDim2.new(1, 0, 0, 4),
						BackgroundColor3 = Theme.Colors.Input,
						BorderSizePixel = 0,
						LayoutOrder = 2,

						Create "UICorner" {CornerRadius = UDim.new(1, 0)},
						Create "Frame" {
							Name = "Fill",
							Size = function()
								return UDim2.fromScale(math.clamp(Limit().utilization or 0, 0, 1), 1)
							end,
							BackgroundColor3 = Theme.Colors.Accent,
							BorderSizePixel = 0,

							Create "UICorner" {CornerRadius = UDim.new(1, 0)},
						},
					},
				}
			end),
			Create "Frame" {
				Name = "Divider",
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.Colors.DimText,
				BackgroundTransparency = 0.7,
				BorderSizePixel = 0,
				LayoutOrder = 200,
				Visible = function()
					return select(1, GetChatCost()) > 0
				end,
			},
			Line(function()
				return "Cost of this chat"
			end, function()
				const Total, Guessed = GetChatCost()

				return Format.Cost(Total, Guessed)
			end, true, 201),
			Line(function()
				const Total, Guessed, Known = GetChatCost()

				if Total == 0 then
					return ""
				end

				if Guessed and Known then
					return "Part reported by Claude, part estimated from tokens"
				end

				return if Guessed then "Estimated from tokens and model prices" else "Reported by Claude"
			end, function()
				return ""
			end, false, 202),
			Create "TextLabel" {
				Name = "Empty",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 900,
				Visible = function()
					return #Chat.Limits() == 0
				end,
				Text = "No limit reported yet. Send a message and it fills in.",
			},
		},
	}
end