--!strict
const TextService = game:GetService("TextService")

const Bounds = require(script.Parent.Parent.Bounds)

export type Block = {
	Box: TextBox,
	Range: ({number}?) -> {number},
	Native: () -> (),
}

const Selection = {}

const Blocks: {Block} = {}

local Origin: Block?
local Anchor = 0
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

const Layouts: {[TextBox]: {Key: string, Rows: {{number}}}} = setmetatable({}, {__mode = "k"}) :: any

const function Rows(Box: TextBox, Width: number, Measure: (string) -> number): {{number}}
	const Text = Box.Text
	const Key = `{Width}|{Box.TextSize}|{Box.Font.Name}|{Text}`
	const Known = Layouts[Box]

	if Known and Known.Key == Key then
		return Known.Rows
	end

	const Found = {}
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

				if #Word == 0 or (Measure((Text:sub(From, math.min(Ending, Stop) - 1):gsub(" +$", ""))) > Width and Fit > From) then
					break
				end

				Fit = math.min(Ending, Stop)
				Next = Ending
			end

			if Fit == From then
				Fit = Stop
			end

			table.insert(Found, {
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
		Rows = Found,
	}

	return Found
end

function Selection.IndexAt(Box: TextBox, Point: Vector2): number
	const Text = Box.Text
	const Padding = Box:FindFirstChildOfClass("UIPadding")
	const Left = if Padding then Padding.PaddingLeft.Offset else 0
	const Wide = Vector2.new(1e5, 1e5)
	const X = Point.X - Box.AbsolutePosition.X - Left

	const function Measure(Piece: string): number
		return TextService:GetTextSize(Piece, Box.TextSize, Box.Font, Wide).X
	end

	const Row = Rows(Box, Box.AbsoluteSize.X - Left - (if Padding then Padding.PaddingRight.Offset else 0), Measure)[math.max(0, math.floor((Point.Y - Box.AbsolutePosition.Y - (if Padding then Padding.PaddingTop.Offset else 0)) / TextService:GetTextSize("Ag", Box.TextSize, Box.Font, Wide).Y)) + 1]

	if not Row then
		return #Text + 1
	end

	const From, Fit = Row[1], Row[2]
	local Best = From

	for Index = From, Fit do
		if Measure(Text:sub(From, Index - 1)) > X then
			break
		end

		Best = Index
	end

	if Best >= Fit or Best <= From then
		return math.min(Best, #Text + 1)
	end

	const Before = Measure(Text:sub(From, Best - 1))
	const After = Measure(Text:sub(From, Best))

	return math.min(if X - Before > After - X then Best + 1 else Best, #Text + 1)
end

const function Extend(Point: Vector2)
	if not Origin then
		return
	end

	if Bounds.Contains(Origin.Box, Point) and not Crossed then
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

	const Reach = Selection.IndexAt(Target.Box, Point)

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

function Selection.Begin(Entry: Block, Widget: any)
	Clear()
	Origin = Entry
	Dragging += 1

	const Mine = Dragging

	task.defer(function()
		Anchor = Entry.Box.CursorPosition

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