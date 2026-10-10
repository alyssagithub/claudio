--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Stats = {
	sessions: number,
	messages: number,
	tokens: number,
	activeDays: number,
	peakHour: number?,
	favoriteModel: string?,
	models: {{name: string, tokens: number, messages: number}},
	grid: {number},
	counting: boolean,
	ready: boolean,
}

const Weeks = 26
const Shades = {0.85, 0.65, 0.4, 0.15}

const function Grouped(Value: number): string
	return (tostring(math.floor(Value)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

const function Hour(Value: number?): string
	if not Value then
		return "–"
	end

	return `{if Value % 12 == 0 then 12 else Value % 12} {if Value < 12 then "AM" else "PM"}`
end

return function()
	const Range = Vide.source("all")
	const Tab = Vide.source("Overview")
	const Found = Vide.source(nil :: Stats?)
	const Wide = Vide.source(0)
	local Asking = 0

	const function Load()
		Asking += 1

		const Mine = Asking

		task.spawn(function()
			while Mine == Asking do
				const Ok, Result = Client.GetStats(Range())

				if Mine ~= Asking then
					return
				end

				if Ok and typeof(Result) == "table" then
					Found(Result :: Stats)
				end

				if not (Ok and typeof(Result) == "table" and (Result.counting or not Result.ready)) then
					return
				end

				task.wait(3)
			end
		end)
	end

	Vide.effect(function()
		Range()

		if #Chat.Messages() == 0 then
			Vide.untrack(Load)
		end
	end)

	const function Toggle(Text: string, Order: number, Selected: () -> boolean, Pick: () -> ())
		const Hovered = Vide.source(false)

		return Create "TextButton" {
			Name = Text,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Theme.Colors.Button,
			BackgroundTransparency = function()
				return if Selected() then 0 elseif Hovered() then 0.5 else 1
			end,
			TextColor3 = function()
				return if Selected() then Theme.Colors.Text() else Theme.Colors.DimText()
			end,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			AutoButtonColor = false,
			LayoutOrder = Order,
			Text = Text,
			Vide.action(Covers.Hover(Hovered)),
			Activated = Pick,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			},
		}
	end

	const function Tile(Label: string, Order: number, Value: () -> string)
		return Create "Frame" {
			Name = "Tile",
			BackgroundColor3 = Theme.Colors.Button,
			BackgroundTransparency = 0.4,
			LayoutOrder = Order,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},
			Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
			Create "TextLabel" {
				Name = "Label",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 1,
				Text = Label,
			},
			Create "TextLabel" {
				Name = "Value",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 2,
				Text = Value,
			},
		}
	end

	const function Shade(Tokens: number): number
		const Held = Found()

		if not Held or Tokens <= 0 then
			return 1
		end

		local Busiest = 0

		for _, Day in Held.grid do
			Busiest = math.max(Busiest, Day)
		end

		return Shades[math.clamp(math.ceil(Tokens / math.max(Busiest, 1) * #Shades), 1, #Shades)]
	end

	const function Cell(): number
		return math.max(4, math.floor((Wide() - (Weeks - 1) * 3) / Weeks))
	end

	return Create "Frame" {
		Name = "Stats",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 3,
		Visible = function()
			return #Chat.Messages() == 0 and Found() ~= nil and (Found() :: Stats).ready
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 8)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 10),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 8),
		},
		Create "Frame" {
			Name = "Bar",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			},
			Toggle("Overview", 1, function()
				return Tab() == "Overview"
			end, function()
				Tab("Overview")
			end),
			Toggle("Models", 2, function()
				return Tab() == "Models"
			end, function()
				Tab("Models")
			end),
			Create "Frame" {
				Name = "Gap",
				Size = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Toggle("All", 4, function()
				return Range() == "all"
			end, function()
				Range("all")
			end),
			Toggle("30d", 5, function()
				return Range() == "30"
			end, function()
				Range("30")
			end),
			Toggle("7d", 6, function()
				return Range() == "7"
			end, function()
				Range("7")
			end),
		},
		Create "Frame" {
			Name = "Tiles",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Visible = function()
				return Tab() == "Overview"
			end,

			Create "UIGridLayout" {
				CellSize = function()
					return UDim2.new(1 / 3, -4, 0, Settings.SmallText() + Settings.TextSize() + 14)
				end,
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Tile("Sessions", 1, function()
				return Grouped(if Found() then (Found() :: Stats).sessions else 0)
			end),
			Tile("Messages", 2, function()
				return Grouped(if Found() then (Found() :: Stats).messages else 0)
			end),
			Tile("Total tokens", 3, function()
				return Format.Large(if Found() then (Found() :: Stats).tokens else 0)
			end),
			Tile("Active days", 4, function()
				return tostring(if Found() then (Found() :: Stats).activeDays else 0)
			end),
			Tile("Peak hour", 5, function()
				return Hour(if Found() then (Found() :: Stats).peakHour else nil)
			end),
			Tile("Favorite model", 6, function()
				return if Found() then (Found() :: Stats).favoriteModel or "–" else "–"
			end),
		},
		Create "Frame" {
			Name = "Activity",
			Size = function()
				return UDim2.new(1, 0, 0, Cell() * 7 + 3 * 6)
			end,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Visible = function()
				return Tab() == "Overview"
			end,
			Vide.action(function(Frame: Frame)
				Wide(Frame.AbsoluteSize.X)
				Vide.cleanup(Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					Wide(Frame.AbsoluteSize.X)
				end))
			end),

			Create "UIGridLayout" {
				CellSize = function()
					return UDim2.fromOffset(Cell(), Cell())
				end,
				CellPadding = UDim2.fromOffset(3, 3),
				FillDirection = Enum.FillDirection.Vertical,
				FillDirectionMaxCells = 7,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Vide.indexes(function()
				const Held = Found()

				return if Held then Held.grid else {}
			end, function(Tokens: () -> number, Index: number)
				return Create "Frame" {
					Name = "Day",
					BackgroundColor3 = function()
						return if Tokens() > 0 then Theme.Colors.Accent() else Theme.Colors.Button()
					end,
					BackgroundTransparency = function()
						return if Tokens() > 0 then Shade(Tokens()) - 0.15 else 0.3
					end,
					LayoutOrder = Index,

					Create "UICorner" {CornerRadius = UDim.new(0, 2)},
				}
			end),
		},
		Create "Frame" {
			Name = "Models",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Visible = function()
				return Tab() == "Models"
			end,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 6),
			},
			Vide.indexes(function()
				const Held = Found()

				return if Held then Held.models else {}
			end, function(Model: () -> {name: string, tokens: number, messages: number}, Index: number)
				const function Share(): number
					const Held = Found()

					return if Held and Held.tokens > 0 then Model().tokens / Held.tokens else 0
				end

				return Create "Frame" {
					Name = "Model",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = Index,

					Create "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						Padding = UDim.new(0, 3),
					},
					Create "Frame" {
						Name = "Line",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 1,

						Create "TextLabel" {
							Name = "Name",
							Size = UDim2.fromScale(0.5, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.Text,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = function()
								return Model().name
							end,
						},
						Create "TextLabel" {
							Name = "Used",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromScale(0.5, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.DimText,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							TextXAlignment = Enum.TextXAlignment.Right,
							Text = function()
								return `{Format.Large(Model().tokens)} tokens · {math.floor(Share() * 100 + 0.5)}%`
							end,
						},
					},
					Create "Frame" {
						Name = "Track",
						Size = UDim2.new(1, 0, 0, 4),
						BackgroundColor3 = Theme.Colors.Button,
						LayoutOrder = 2,

						Create "UICorner" {CornerRadius = UDim.new(1, 0)},
						Create "Frame" {
							Name = "Fill",
							Size = function()
								return UDim2.fromScale(Share(), 1)
							end,
							BackgroundColor3 = Theme.Colors.Accent,

							Create "UICorner" {CornerRadius = UDim.new(1, 0)},
						},
					},
				}
			end),
		},
	}
end
