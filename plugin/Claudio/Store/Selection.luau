--!strict
const TextService = game:GetService("TextService")

const Bounds = require(script.Parent.Parent.Bounds)

export type Block = {
	Box: TextBox,
	Range: ({number}?) -> {number},
	Native: () -> (),
	Rich: (() -> string)?,
}

type Style = {Font: Enum.Font, Size: number}

const Selection = {}

const Blocks: {Block} = {}

local Origin: Block?
local Anchor = 0
local Words = false
local LastBox: TextBox?
local LastClick = 0

const function Place(Box: TextBox, From: number, To: number)
	if From == To then
		Box.SelectionStart = -1
		Box.CursorPosition = To

		return
	end

	Box.SelectionStart = From
	Box.CursorPosition = To
end
local Crossed = false
local Dragging = 0

const function Nothing(): {number}
	return {
		0,
		0,
	}
end

const function Clear()
	Dragging += 1
	Origin = nil

	if not Crossed then
		return
	end

	Crossed = false

	for _, Entry in Blocks do
		Entry.Range(Nothing())
	end
end

function Selection.Drop(Entry: Block)
	if Origin ~= Entry then
		return
	end

	Clear()
end

function Selection.Add(Entry: Block): () -> ()
	table.insert(Blocks, Entry)

	return function()
		const Index = table.find(Blocks, Entry)

		if Index then
			table.remove(Blocks, Index)
		end

		Selection.Drop(Entry)
	end
end

const function Ordered(): {Block}
	const Sorted = {}

	for _, Entry in Blocks do
		if Entry.Box.Parent and Entry.Box.AbsoluteSize.Y > 0 then
			table.insert(Sorted, Entry)
		end
	end

	table.sort(Sorted, function(Left, Right)
		const LeftCorner = Left.Box.AbsolutePosition
		const RightCorner = Right.Box.AbsolutePosition

		if math.abs(LeftCorner.Y - RightCorner.Y) > 2 then
			return LeftCorner.Y < RightCorner.Y
		end

		return LeftCorner.X < RightCorner.X
	end)

	return Sorted
end

const Entities: {[string]: string} = {
	["&lt;"] = "<",
	["&gt;"] = ">",
	["&amp;"] = "&",
	["&quot;"] = "\"",
	["&apos;"] = "'",
}

const Bolder: {[Enum.Font]: Enum.Font} = {
	[Enum.Font.BuilderSans] = Enum.Font.BuilderSansBold,
	[Enum.Font.BuilderSansMedium] = Enum.Font.BuilderSansBold,
	[Enum.Font.SourceSans] = Enum.Font.SourceSansBold,
	[Enum.Font.Gotham] = Enum.Font.GothamBold,
}

const function Styles(Box: TextBox, Rich: string?): {Style}
	const Base: Style = {Font = Box.Font, Size = Box.TextSize}
	const Found: {Style} = {}

	if not Rich then
		return Found
	end

	const Fonts: {{Mono: boolean, Size: number?}} = {}
	local Bold = 0
	local At = 1

	while At <= #Rich do
		const Tag = Rich:match("^<[^>]->", At)

		if Tag then
			if Tag == "<b>" then
				Bold += 1
			elseif Tag == "</b>" then
				Bold = math.max(0, Bold - 1)
			elseif Tag:match("^<font") then
				table.insert(Fonts, {
					Mono = Tag:find("Mono", 1, true) ~= nil,
					Size = tonumber(Tag:match('size="(%d+)"')),
				})
			elseif Tag == "</font>" then
				table.remove(Fonts)
			end

			At += #Tag

			continue
		end

		local Mono = false
		local Size = Base.Size

		for _, Entry in Fonts do
			Mono = Mono or Entry.Mono
			Size = Entry.Size or Size
		end

		const Font = if Mono then Enum.Font.RobotoMono elseif Bold > 0 then Bolder[Base.Font] or Base.Font else Base.Font
		const Style = if Font == Base.Font and Size == Base.Size then Base else {Font = Font, Size = Size}
		const Entity = Rich:match("^&%a+;", At)
		const Piece = if Entity and Entities[Entity] then Entities[Entity] else (Rich:match("^[%z\1-\127\194-\244][\128-\191]*", At) or Rich:sub(At, At))

		for _ = 1, #Piece do
			table.insert(Found, Style)
		end

		At += if Entity and Entities[Entity] then #Entity else #Piece
	end

	return if #Found == #Box.Text then Found else {}
end

const Layouts: {[TextBox]: {Key: string, Rows: {{number}}, Styles: {Style}}} = setmetatable({}, {__mode = "k"}) :: any

const function Measurer(Box: TextBox, Found: {Style}): (number, number) -> number
	const Text = Box.Text
	const Wide = Vector2.new(1e5, 1e5)

	return function(From: number, To: number): number
		if To < From then
			return 0
		end

		if #Found == 0 then
			return TextService:GetTextSize(Text:sub(From, To), Box.TextSize, Box.Font, Wide).X
		end

		local Width = 0
		local Start = From

		while Start <= To do
			const Style = Found[Start]
			local Stop = Start

			while Stop < To and Found[Stop + 1] == Style do
				Stop += 1
			end

			Width += TextService:GetTextSize(Text:sub(Start, Stop), Style.Size, Style.Font, Wide).X
			Start = Stop + 1
		end

		return Width
	end
end

const function Layout(Box: TextBox, Width: number, Rich: string?): ({{number}}, (number, number) -> number, {Style})
	const Text = Box.Text
	const Key = `{Width}|{Box.TextSize}|{Box.Font.Name}|{Rich or Text}`
	const Known = Layouts[Box]

	if Known and Known.Key == Key then
		return Known.Rows, Measurer(Box, Known.Styles), Known.Styles
	end

	const Found = Styles(Box, Rich)
	const Measure = Measurer(Box, Found)
	const Rows = {}
	local Start = 1

	while Start <= #Text + 1 do
		const Stop = Text:find("\n", Start, true) or #Text + 1
		local From = Start

		while true do
			local Fit = From
			local Next = From

			while Next <= Stop do
				const Word = Text:match("^[^ \n]* *", Next) :: string
				const Ending = Next + #Word
				local Last = math.min(Ending, Stop) - 1

				while Last >= From and Text:sub(Last, Last) == " " do
					Last -= 1
				end

				if #Word == 0 or (Measure(From, Last) > Width and Fit > From) then
					break
				end

				Fit = math.min(Ending, Stop)
				Next = Ending
			end

			if Fit == From then
				Fit = Stop
			end

			table.insert(Rows, {
				From,
				Fit,
			})

			if Fit >= Stop then
				break
			end

			From = Fit
		end

		Start = Stop + 1
	end

	Layouts[Box] = {
		Key = Key,
		Rows = Rows,
		Styles = Found,
	}

	return Rows, Measure, Found
end

const function Height(Box: TextBox, Found: {Style}, Row: {number}): number
	const Wide = Vector2.new(1e5, 1e5)
	local Tallest = TextService:GetTextSize("Ag", Box.TextSize, Box.Font, Wide).Y

	for Index = Row[1], Row[2] - 1 do
		const Style = Found[Index]

		if Style and Style.Size ~= Box.TextSize then
			Tallest = math.max(Tallest, TextService:GetTextSize("Ag", Style.Size, Style.Font, Wide).Y)
		end
	end

	return Tallest
end

function Selection.IndexAt(Box: TextBox, Point: Vector2, Rich: string?): number
	const Text = Box.Text
	const Padding = Box:FindFirstChildOfClass("UIPadding")
	const Left = if Padding then Padding.PaddingLeft.Offset else 0
	const X = Point.X - Box.AbsolutePosition.X - Left
	const Rows, Measure, Found = Layout(Box, Box.AbsoluteSize.X - Left - (if Padding then Padding.PaddingRight.Offset else 0), Rich)
	local Y = Point.Y - Box.AbsolutePosition.Y - (if Padding then Padding.PaddingTop.Offset else 0)
	local Row = Rows[#Rows]

	for _, Candidate in Rows do
		const Tall = Height(Box, Found, Candidate)

		if Y < Tall then
			Row = Candidate

			break
		end

		Y -= Tall
	end

	if not Row or Y < 0 and Row == Rows[1] and Point.Y < Box.AbsolutePosition.Y then
		return 1
	end

	const From, Fit = Row[1], Row[2]
	local Best = From

	for Index = From, Fit do
		if Measure(From, Index - 1) > X then
			break
		end

		Best = Index
	end

	if Best >= Fit or Best <= From then
		return math.min(Best, #Text + 1)
	end

	const Before = Measure(From, Best - 1)
	const After = Measure(From, Best)

	return math.min(if X - Before > After - X then Best + 1 else Best, #Text + 1)
end

function Selection.Word(Box: TextBox, At: number): (number, number)
	const Text = Box.Text
	local Start = At
	local Finish = At

	while Start > 1 and Text:sub(Start - 1, Start - 1):match("[%w_]") do
		Start -= 1
	end

	while Finish <= #Text and Text:sub(Finish, Finish):match("[%w_]") do
		Finish += 1
	end

	return Start, Finish
end

const function Extend(Point: Vector2)
	if not Origin then
		return
	end

	if Bounds.Contains(Origin.Box, Point) and not Crossed then
		const Reach = Selection.IndexAt(Origin.Box, Point, if Origin.Rich then Origin.Rich() else nil)

		if Words then
			const Start = math.min(Anchor, (Selection.Word(Origin.Box, Reach)))
			const _, Finish = Selection.Word(Origin.Box, math.max(Reach, Anchor))

			Place(Origin.Box, Start, math.max(Finish, Anchor))

			return
		end

		Place(Origin.Box, Anchor, Reach)

		return
	end

	if Bounds.Contains(Origin.Box, Point) then
		Crossed = false

		for _, Entry in Blocks do
			if Entry ~= Origin then
				Entry.Range(Nothing())
			end
		end

		Origin.Native()

		return
	end

	const Sorted = Ordered()
	local Target: Block?

	for _, Entry in Sorted do
		if Entry ~= Origin and Bounds.Contains(Entry.Box, Point) then
			Target = Entry
		end
	end

	if not Target then
		const First, Last = Sorted[1], Sorted[#Sorted]

		if First and Point.Y < First.Box.AbsolutePosition.Y then
			Target = First
		elseif Last and Point.Y > Last.Box.AbsolutePosition.Y + Last.Box.AbsoluteSize.Y then
			Target = Last
		else
			for _, Entry in Sorted do
				if Point.Y >= Entry.Box.AbsolutePosition.Y then
					Target = Entry
				end
			end
		end
	end

	if not Target or Target == Origin then
		return
	end

	const Start = table.find(Sorted, Origin)
	const Finish = table.find(Sorted, Target)

	if not Start or not Finish then
		return
	end

	const Reach = Selection.IndexAt(Target.Box, Point, if Target.Rich then Target.Rich() else nil)

	Crossed = true

	for Index, Entry in Sorted do
		const Length = #Entry.Box.Text + 1

		if Entry == Origin then
			Entry.Range({
				if Finish > Start then Anchor else 1,
				if Finish > Start then Length else Anchor,
			})
		elseif Entry == Target then
			Entry.Range({
				if Finish > Start then 1 else Reach,
				if Finish > Start then Reach else Length,
			})
		elseif Index > math.min(Start, Finish) and Index < math.max(Start, Finish) then
			Entry.Range({
				1,
				Length,
			})
		else
			Entry.Range(Nothing())
		end
	end
end

function Selection.Begin(Entry: Block, Widget: any, Point: Vector2)
	const Again = LastBox == Entry.Box and os.clock() - LastClick < 0.4

	Clear()
	Origin = Entry
	Dragging += 1
	LastBox = Entry.Box
	LastClick = if Again then 0 else os.clock()
	Anchor = Selection.IndexAt(Entry.Box, Point, if Entry.Rich then Entry.Rich() else nil)
	Words = Again

	if Again then
		Anchor = (Selection.Word(Entry.Box, Anchor))
	end

	const Mine = Dragging

	task.defer(function()
		Extend(Point)

		if not Widget then
			return
		end

		local Last: Vector2?

		while task.wait() and Dragging == Mine do
			const Ok, Where = pcall(Widget.GetRelativeMousePosition, Widget)

			if Ok and Where ~= Last then
				Last = Where
				Extend(Where)
			end
		end
	end)
end

function Selection.Finish(Point: Vector2)
	Dragging += 1
	Extend(Point)
end

function Selection.Crossing(): boolean
	return Crossed
end

function Selection.Text(): string?
	if not Crossed then
		return nil
	end

	const Pieces = {}

	for _, Entry in Ordered() do
		const Range = Entry.Range()

		if Range[2] > Range[1] then
			table.insert(Pieces, Entry.Box.Text:sub(Range[1], Range[2] - 1))
		end
	end

	return table.concat(Pieces, "\n")
end

return Selection