--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Markdown = require(script.Parent.Parent.Parent.Markdown)
const Theme = require(script.Parent.Parent.Theme)
const Selectable = require(script.Parent.Selectable)

const Create = Vide.create

const function Cell(Text: string, Columns: number, Header: boolean, LayoutOrder: number)
	const Box = Selectable {
		Name = if Header then "Heading" else "Cell",
		Font = if Header then Enum.Font.BuilderSansBold else Enum.Font.BuilderSans,
		Size = Settings.SmallText,
		LayoutOrder = LayoutOrder,
		Text = function()
			return Markdown.Cell(Text)
		end,
		Children = {
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			},
		},
	}

	Box.Size = UDim2.fromScale(1 / Columns, 0)

	return Box
end

const function Line(Row: {string}, Columns: number, Index: number)
	const Cells = {}

	for Column = 1, Columns do
		table.insert(Cells, Cell(Row[Column] or "", Columns, Index == 1, Column))
	end

	return Create "Frame" {
		Name = "Row",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = if Index == 1 then 0 elseif Index % 2 == 0 then 1 else 0.6,
		LayoutOrder = Index,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		Cells,
	}
end

return function(Rows: () -> {{string}}, LayoutOrder: number)
	return Create "Frame" {
		Name = "Table",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,
		LayoutOrder = LayoutOrder,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Vide.indexes(function()
			const Found = Rows()
			local Columns = 0

			for _, Row in Found do
				Columns = math.max(Columns, #Row)
			end

			const Keyed: {[string]: {Row: {string}, Columns: number, Index: number}} = {}

			for Index, Row in Found do
				Keyed[`{Columns}|{Index}|{table.concat(Row, "|")}`] = {
					Row = Row,
					Columns = Columns,
					Index = Index,
				}
			end

			return Keyed
		end, function(Entry)
			const Found = Entry()

			return Line(Found.Row, Found.Columns, Found.Index)
		end),
	}
end