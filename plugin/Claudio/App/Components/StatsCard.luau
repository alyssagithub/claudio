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
	models: {{name: string, tokens: number, input: number, output: number, messages: number}},
	grid: {number},
	bars: {{date: string, models: {[string]: number}}},
	counting: boolean,
	ready: boolean,
}

const Weeks = 26
const Shades = {0.85, 0.65, 0.4, 0.15}
const ChartHeight = 120
const Palette = {
	Color3.fromRGB(66, 120, 222),
	Color3.fromRGB(92, 146, 236),
	Color3.fromRGB(124, 170, 244),
	Color3.fromRGB(160, 196, 250),
	Color3.fromRGB(196, 220, 253),
	Color3.fromRGB(56, 96, 180),
	Color3.fromRGB(110, 130, 200),
	Color3.fromRGB(150, 160, 220),
}
const Months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

const function DayLabel(Date: string): string
	const _, Month, Day = Date:match("^(%d+)-(%d+)-(%d+)$")

	return `{Months[tonumber(Month) or 1]} {tonumber(Day)}`
end

const function Step(Biggest: number): number
	const Rough = math.max(Biggest, 1) / 4
	const Power = 10 ^ math.floor(math.log10(Rough))

	for _, Nice in {1, 2, 2.5, 5, 10} do
		if Nice * Power >= Rough then
			return Nice * Power
		end
	end

	return 10 * Power
end

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
	const ChartWide = Vide.source(0)
	const Pointed = Vide.source(0)
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

	const function Colour(Name: string): Color3
		const Held = Found()

		if Held then
			for Index, Model in Held.models do
				if Model.name == Name then
					return Palette[(Index - 1) % #Palette + 1]
				end
			end
		end

		return Palette[1]
	end

	const function Top(): number
		const Held = Found()
		local Biggest = 0

		for _, Bar in (if Held then Held.bars else {}) do
			local Sum = 0

			for _, Used in Bar.models do
				Sum += Used
			end

			Biggest = math.max(Biggest, Sum)
		end

		return Step(Biggest) * 4
	end

	const function Bars(): number
		const Held = Found()

		return if Held then math.max(1, #Held.bars) else 1
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
			Name = "Chart",
			Size = UDim2.new(1, 0, 0, ChartHeight + Settings.SmallText() + 10),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Visible = function()
				return Tab() == "Models"
			end,

			Vide.indexes(function()
				return {4, 3, 2, 1, 0}
			end, function(Tick: () -> number)
				return Create "Frame" {
					Name = "Tick",
					Position = function()
						return UDim2.fromOffset(0, ChartHeight - Tick() / 4 * ChartHeight)
					end,
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Theme.Colors.Border,
					BackgroundTransparency = 0.6,
					BorderSizePixel = 0,

					Create "TextLabel" {
						Name = "Label",
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromOffset(34, Settings.SmallText()),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = function()
							return Format.Large(Top() * Tick() / 4)
						end,
					},
				}
			end),
			Create "Frame" {
				Name = "Plot",
				Position = UDim2.fromOffset(38, 0),
				Size = UDim2.new(1, -38, 0, ChartHeight),
				BackgroundTransparency = 1,
				Vide.action(function(Plot: Frame)
					ChartWide(Plot.AbsoluteSize.X)
					Vide.cleanup(Plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
						ChartWide(Plot.AbsoluteSize.X)
					end))
				end),

				Vide.indexes(function()
					const Held = Found()

					return if Held then Held.bars else {}
				end, function(Bar: () -> {date: string, models: {[string]: number}}, Index: number)
					const Hovered = Vide.source(false)

					Vide.effect(function()
						if Hovered() then
							Vide.untrack(function()
								Pointed(Index)
							end)
						elseif Vide.untrack(Pointed) == Index then
							Vide.untrack(function()
								Pointed(0)
							end)
						end
					end)

					return Create "Frame" {
						Name = "Bar",
						Position = function()
							return UDim2.fromOffset((Index - 1) * ChartWide() / Bars(), 0)
						end,
						Size = function()
							return UDim2.fromOffset(math.max(1, ChartWide() / Bars() - math.min(4, ChartWide() / Bars() * 0.25)), ChartHeight)
						end,
						BackgroundTransparency = 1,
						Vide.action(Covers.Hover(Hovered)),

						Create "UIListLayout" {
							VerticalAlignment = Enum.VerticalAlignment.Bottom,
							SortOrder = Enum.SortOrder.LayoutOrder,
						},
						Vide.indexes(function()
							const Held = Found()
							const Pieces = {}

							for Order, Model in (if Held then Held.models else {}) do
								const Used = Bar().models[Model.name]

								if Used and Used > 0 then
									table.insert(Pieces, {name = Model.name, used = Used, order = Order})
								end
							end

							return Pieces
						end, function(Piece: () -> {name: string, used: number, order: number})
							return Create "Frame" {
								Name = "Piece",
								Size = function()
									return UDim2.new(1, 0, 0, math.max(1, Piece().used / math.max(Top(), 1) * ChartHeight))
								end,
								BackgroundColor3 = function()
									return Colour(Piece().name)
								end,
								BorderSizePixel = 0,
								LayoutOrder = function()
									return -Piece().order
								end,
							}
						end),
					}
				end),
				Create "Frame" {
					Name = "Tip",
					AutomaticSize = Enum.AutomaticSize.XY,
					Position = function()
						const At = (Pointed() - 0.5) * ChartWide() / Bars()

						return UDim2.fromOffset(math.clamp(At - 60, 0, math.max(0, ChartWide() - 140)), 0)
					end,
					BackgroundColor3 = Theme.Colors.Background,
					ZIndex = 5,
					Visible = function()
						return Pointed() > 0
					end,

					Create "UICorner" {CornerRadius = UDim.new(0, 4)},
					Create "UIStroke" {Color = Theme.Colors.Border},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
					},
					Create "TextLabel" {
						Name = "Text",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						RichText = true,
						ZIndex = 6,
						Text = function()
							const Held = Found()
							const Bar = if Held then Held.bars[Pointed()] else nil

							if not Held or not Bar then
								return ""
							end

							const Lines = {`<b>{DayLabel(Bar.date)}</b>`}

							for _, Model in Held.models do
								const Used = Bar.models[Model.name]

								if Used and Used > 0 then
									table.insert(Lines, `<font color="#{Colour(Model.name):ToHex()}">●</font> {Model.name}: {Format.Large(Used)}`)
								end
							end

							if #Lines == 1 then
								table.insert(Lines, "No usage")
							end

							return table.concat(Lines, "\n")
						end,
					},
				},
			},
			Vide.indexes(function()
				const Held = Found()
				const Count = if Held then #Held.bars else 0
				const Every = math.max(1, math.ceil(Count / 6))
				const Marks = {}

				for Index = 1, Count, Every do
					table.insert(Marks, Index)
				end

				return Marks
			end, function(Mark: () -> number)
				return Create "TextLabel" {
					Name = "Date",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = function()
						return UDim2.fromOffset(38 + (Mark() - 0.5) * ChartWide() / Bars(), ChartHeight + 4)
					end,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					Text = function()
						const Held = Found()
						const Bar = if Held then Held.bars[Mark()] else nil

						return if Bar then DayLabel(Bar.date) else ""
					end,
				}
			end),
		},
		Create "Frame" {
			Name = "Legend",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 5,
			Visible = function()
				return Tab() == "Models"
			end,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 4),
			},
			Vide.indexes(function()
				const Held = Found()

				return if Held then {table.unpack(Held.models, 1, math.min(5, #Held.models))} else {}
			end, function(Model: () -> {name: string, tokens: number, input: number, output: number, messages: number}, Index: number)
				return Create "Frame" {
					Name = "Model",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = Index,

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
							return Colour(Model().name)
						end,
						LayoutOrder = 1,

						Create "UICorner" {CornerRadius = UDim.new(0, 2)},
					},
					Create "TextLabel" {
						Name = "Name",
						Size = UDim2.fromScale(0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						LayoutOrder = 2,
						Text = function()
							return Model().name
						end,

						Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
					},
					Create "TextLabel" {
						Name = "Used",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						LayoutOrder = 3,
						Text = function()
							return `{Format.Large(Model().input)} in · {Format.Large(Model().output)} out`
						end,
					},
					Create "TextLabel" {
						Name = "Share",
						Size = UDim2.fromOffset(42, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
						TextXAlignment = Enum.TextXAlignment.Right,
						LayoutOrder = 4,
						Text = function()
							const Held = Found()

							return `{string.format("%.1f", if Held and Held.tokens > 0 then Model().tokens / Held.tokens * 100 else 0)}%`
						end,
					},
				}
			end),
		},
	}
end
