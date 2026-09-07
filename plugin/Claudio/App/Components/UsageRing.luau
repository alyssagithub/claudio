--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Config = require(script.Parent.Parent.Parent.Config)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

const Edge = 18
const Kinds = {
	["5-hour usage"] = "five_hour",
	["Weekly usage"] = "seven_day",
}

return function()
	const function Window(): Types.Limit?
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

	const function Share(): number
		if Settings.Get("RingStat")() == "Context" then
			const Total = Chat.ContextWindow()

			return if Total > 0 then math.clamp(Chat.ContextUsed() / Total, 0, 1) else 0
		end

		const Limit = Window()

		return if Limit and Limit.utilization then math.clamp(Limit.utilization, 0, 1) else 0
	end

	const function Colour(): Color3
		const Used = Share()

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
			return math.clamp((Share() - (Order - 1) * 0.5) / 0.5, 0, 1)
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
	const Room = Vide.source(220)

	const function Follow(Object: GuiObject)
		const Row = Object.Parent :: GuiObject

		if not Row then
			return
		end

		Shift(Row.AbsolutePosition.X - Object.AbsolutePosition.X)
		Room(math.max(160, Row.AbsoluteSize.X))
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

	const function Shade(Part: Types.Part): Color3
		return Shades[Part.name] or Color3.fromRGB(70, 74, 90)
	end

	const function Filled(): {Types.Part}
		const Found = {}

		for _, Part in Chat.ContextParts() do
			if Part.name ~= "Free space" and not Part.deferred and Part.tokens > 0 then
				table.insert(Found, Part)
			end
		end

		return Found
	end

	const function Spent(): (number, boolean, boolean)
		local Total = 0
		local Guessed = false
		local Known = false

		for _, Message in Chat.Messages() do
			if Message.Cost then
				Total += Message.Cost

				if Message.Estimated then
					Guessed = true
				else
					Known = true
				end
			end
		end

		return Total, Guessed, Known
	end

	const function Meter(Share: () -> number, Colour: () -> Color3, LayoutOrder: number)
		return Create "Frame" {
			Name = "Meter",
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = Theme.Colors.Input,
			BorderSizePixel = 0,
			LayoutOrder = LayoutOrder,

			Create "UICorner" {CornerRadius = UDim.new(1, 0)},
			Create "Frame" {
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(math.clamp(Share(), 0, 1), 1)
				end,
				BackgroundColor3 = Colour,
				BorderSizePixel = 0,

				Create "UICorner" {CornerRadius = UDim.new(1, 0)},
			},
		}
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
			Shown(not Shown())
		end,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Vide.action(function(Object: GuiObject)
			const Connection = Object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				Follow(Object)
			end)

			Vide.cleanup(function()
				Connection:Disconnect()
			end)
			task.defer(Follow, Object)
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
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			AnchorPoint = Vector2.new(0, 1),
			Position = function()
				return UDim2.new(0, Shift(), 0, -8)
			end,
			BackgroundColor3 = Theme.Colors.Panel,
			ZIndex = 20,
			Visible = function()
				return Hovered() and not Shown()
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
			Create "UIStroke" {Color = Theme.Colors.Border},
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
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 20,
				LayoutOrder = 1,
				Text = function()
					const Limit = Window()

					if not Limit then
						return "5-hour limit"
					end

					const Name = (Limit.label or "5-hour limit"):gsub(" %- ", " · ")

					return if Limit.utilization then `{Name}: {math.round(Limit.utilization * 100)}%` else Name
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
					const Limit = Window()
					const Parts: {string} = {}

					if Limit and Limit.resetsAt then
						table.insert(Parts, `{Format.Until(Limit.resetsAt)}`)
					end

					const Room = Chat.ContextWindow()

					if Room > 0 then
						table.insert(Parts, `Context {Format.Large(Chat.ContextUsed())} / {Format.Large(Room)} ({math.round(Chat.ContextUsed() / Room * 100)}%)`)
					end

					return if #Parts == 0 then "Fills in after the first reply" else table.concat(Parts, " · ")
				end,
			},
		},
		Create "Frame" {
			Name = "Panel",
			Size = function()
				return UDim2.fromOffset(Room(), 0)
			end,
			AutomaticSize = Enum.AutomaticSize.Y,
			AnchorPoint = Vector2.new(0, 1),
			Position = function()
				return UDim2.new(0, Shift(), 0, -8)
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
					const Named = Chat.ContextModel()

					if Named == "" then
						return "Context window"
					end

					return `Context window · {Format.Model(Named)}`
				end, function()
					const Room = Chat.ContextWindow()

					if Room == 0 then
						return "0"
					end

					return `{Format.Large(Chat.ContextUsed())} / {Format.Large(Room)} ({math.round(Chat.ContextUsed() / Room * 100)}%) `
				end, true, 1, Expanded),
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
				Vide.indexes(Filled, function(Part: () -> Types.Part, Index: number)
					return Create "Frame" {
						Name = "Segment",
						Size = function()
							const Room = Chat.ContextWindow()

							return UDim2.fromScale(if Room == 0 then 0 else Part().tokens / Room, 1)
						end,
						BackgroundColor3 = function()
							return Shade(Part())
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
					LayoutOrder = 2 + Index,

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
							return Shade(Part())
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
							const Room = Chat.ContextWindow()
							const Share = if Room == 0 or Part().deferred then "" else `   {string.format("%.1f", Part().tokens / Room * 100)}%`

							return `{Format.Large(Part().tokens)}{Share}`
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
						const Reset = if Entry.resetsAt then `{Format.Until(Entry.resetsAt)}` else ""
						const Share = if Entry.utilization then `   {math.floor(Entry.utilization * 100)}%` else ""

						return `{Reset}{Share}`
					end, true, 1),
					Meter(function()
						return Limit().utilization or 0
					end, Theme.Colors.Accent, 2),
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
					return select(1, Spent()) > 0
				end,
			},
			Line(function()
				return "Cost of this chat"
			end, function()
				const Total, Guessed = Spent()

				if Total < 1 then
					return `{if Guessed then "~" else ""}${string.format("%.3f", Total)}`
				end

				return `{if Guessed then "~" else ""}${string.format("%.2f", Total)}`
			end, true, 201),
			Line(function()
				const Total, Guessed, Known = Spent()

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