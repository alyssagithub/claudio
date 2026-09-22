--!strict
const TextService = game:GetService("TextService")

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

const function Inside(Box: GuiObject, Point: Vector2): boolean
	const Corner = Box.AbsolutePosition
	const Size = Box.AbsoluteSize

	return Point.X >= Corner.X and Point.X <= Corner.X + Size.X and Point.Y >= Corner.Y and Point.Y <= Corner.Y + Size.Y
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

function Selection.IndexAt(Box: TextBox, Point: Vector2): number
	const Text = Box.Text
	const Padding = Box:FindFirstChildOfClass("UIPadding")
	const Left = if Padding then Padding.PaddingLeft.Offset else 0
	const Top = if Padding then Padding.PaddingTop.Offset else 0
	const Width = Box.AbsoluteSize.X - Left - (if Padding then Padding.PaddingRight.Offset else 0)
	const Size = Box.TextSize
	const Face = Box.Font
	const Wide = Vector2.new(1e5, 1e5)
	const Height = TextService:GetTextSize("Ag", Size, Face, Wide).Y
	const Row = math.max(0, math.floor((Point.Y - Box.AbsolutePosition.Y - Top) / Height))
	const X = Point.X - Box.AbsolutePosition.X - Left

	const function Measure(Piece: string): number
		return TextService:GetTextSize(Piece, Size, Face, Wide).X
	end

	local Line = 0
	local Start = 1

	while Start <= #Text + 1 do
		local Stop = Text:find("\n", Start, true) or #Text + 1
		local From = Start

		while true do
			local Fit = From
			local Next = From

			while Next <= Stop do
				const Word = Text:match("^[^ \n]* *", Next)
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

			if Line == Row then
				local Best = From

				for Index = From, Fit do
					if Measure(Text:sub(From, Index - 1)) <= X then
						Best = Index
					else
						break
					end
				end

				if Best < Fit and Best > From then
					const Before = Measure(Text:sub(From, Best - 1))
					const After = Measure(Text:sub(From, Best))

					if X - Before > After - X then
						Best += 1
					end
				end

				return math.min(Best, #Text + 1)
			end

			Line += 1

			if Fit >= Stop then
				break
			end

			From = Fit
		end

		Start = Stop + 1
	end

	return #Text + 1
end

const function Extend(Point: Vector2)
	if not Origin then
		return
	end

	if Inside(Origin.Box, Point) then
		if Crossed then
			Crossed = false

			for _, Entry in Blocks do
				if Entry ~= Origin then
					Entry.Range({0, 0})
				end
			end

			Origin.Native()
		end

		return
	end

	const Sorted = Ordered()
	local Target: Block?

	for _, Entry in Sorted do
		if Entry ~= Origin and Inside(Entry.Box, Point) then
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
			Entry.Range(if Finish > Start then {Anchor, Length} else {1, Anchor})
		elseif Entry == Target then
			Entry.Range(if Finish > Start then {1, Reach} else {Reach, Length})
		elseif Index > math.min(Start, Finish) and Index < math.max(Start, Finish) then
			Entry.Range({1, Length})
		else
			Entry.Range({0, 0})
		end
	end
end

function Selection.Begin(Entry: Block, Widget: any)
	Selection.Clear()
	Origin = Entry
	Dragging += 1

	const Mine = Dragging

	task.defer(function()
		Anchor = Entry.Box.CursorPosition

		if not Widget then
			return
		end

		while task.wait() and Dragging == Mine do
			const Ok, Where = pcall(Widget.GetRelativeMousePosition, Widget)

			if Ok then
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

function Selection.Drop(Entry: Block)
	if Origin == Entry then
		Selection.Clear()
	end
end

function Selection.Clear()
	Dragging += 1

	if not Crossed then
		Origin = nil

		return
	end

	Crossed = false
	Origin = nil

	for _, Entry in Blocks do
		Entry.Range({0, 0})
	end
end

return Selection