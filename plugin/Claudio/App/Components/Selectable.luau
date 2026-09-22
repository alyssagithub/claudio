--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Keys = require(script.Parent.Parent.Parent.Store.Keys)
const Selection = require(script.Parent.Parent.Parent.Store.Selection)
const Navigate = require(script.Parent.Parent.Parent.Navigate)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

export type Props = {
	Name: string,
	Text: () -> string,
	Size: (() -> number)?,
	Font: Enum.Font?,
	Colour: (() -> Color3)?,
	LayoutOrder: any,
	Links: (() -> {[string]: string})?,
	Urls: (() -> {[string]: string})?,
	Children: {Instance}?,
}

const Entities = {
	["&lt;"] = true,
	["&gt;"] = true,
	["&amp;"] = true,
	["&quot;"] = true,
	["&apos;"] = true,
}

const function Spanning(Text: string, Needle: string, At: number): boolean
	if Needle == "" then
		return false
	end

	local From = 1

	while true do
		const Start, Stop = Text:find(Needle, From, true)

		if not Start or not Stop then
			return false
		end

		if At >= Start and At <= Stop then
			return true
		end

		From = Stop + 1
	end
end

const function Marked(Rich: string, From: number, To: number, Colour: string): string
	if From >= To then
		return Rich
	end

	const Pieces = {}
	local At = 1
	local Position = 1
	local Open = false

	while At <= #Rich do
		const Tag = Rich:match("^<[^>]->", At)

		if Tag then
			if Open then
				table.insert(Pieces, "</mark>")
				Open = false
			end

			table.insert(Pieces, Tag)
			At += #Tag

			continue
		end

		const Entity = Rich:match("^&%a+;", At)
		const Known = Entity ~= nil and Entities[Entity] == true
		const Piece = if Known then Entity :: string else Rich:match("^[%z\1-\127\194-\244][\128-\191]*", At) or Rich:sub(At, At)
		const Chosen = Position >= From and Position < To

		if Chosen and not Open then
			table.insert(Pieces, `<mark color="#{Colour}" transparency="0.55">`)
			Open = true
		elseif not Chosen and Open then
			table.insert(Pieces, "</mark>")
			Open = false
		end

		table.insert(Pieces, Piece)
		At += #Piece
		Position += if Known then 1 else #Piece
	end

	if Open then
		table.insert(Pieces, "</mark>")
	end

	return table.concat(Pieces)
end

return function(Props: Props)
	local Box: TextBox
	local Copies = 0
	local Focused = 0
	local Holding = false

	const Range = Vide.source({
		0,
		0,
	})

	const function Track()
		if Selection.Crossing() then
			return
		end

		if not Box:IsFocused() or Box.SelectionStart == -1 then
			Range({
				0,
				0,
			})

			return
		end

		Range({
			math.min(Box.CursorPosition, Box.SelectionStart),
			math.max(Box.CursorPosition, Box.SelectionStart),
		})
	end

	const Entry: Selection.Block = {
		Box = nil :: any,
		Range = Range,
		Native = Track,
	}

	Box = Create "TextBox" {
		Name = Props.Name,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = Props.Colour or Theme.Colors.Text,
		TextSize = Props.Size or Settings.TextSize,
		FontFace = Font.fromEnum(Props.Font or Enum.Font.BuilderSans),
		TextWrapped = true,
		TextTransparency = 1,
		MultiLine = true,
		TextEditable = false,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = Props.LayoutOrder,
		Text = function()
			return Keys.Clean(Props.Text())
		end,
		Focused = function()
			Focused += 1

			const Mine = Focused

			if not Holding then
				Holding = true
				Keys.Hold()
			end

			task.spawn(function()
				while task.wait(0.15) and Focused == Mine do
					Copies = Keys.CopySelection(Box, Copies, Selection.Text())
				end
			end)
		end,
		FocusLost = function()
			Focused += 1
			Range({
				0,
				0,
			})
			Selection.Drop(Entry)

			if not Holding then
				return
			end

			Holding = false
			Keys.Release()
		end,
		InputBegan = function(Input: InputObject)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			Selection.Begin(Entry, Box:FindFirstAncestorWhichIsA("PluginGui"))
		end,
		InputEnded = function(Input: InputObject)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			Selection.Finish(Vector2.new(Input.Position.X, Input.Position.Y))

			if not Box:IsFocused() then
				return
			end

			task.defer(function()
				if Selection.Crossing() or (Box.SelectionStart ~= -1 and Box.SelectionStart ~= Box.CursorPosition) then
					return
				end

				const At = Box.CursorPosition - 1

				for Path, Full in (if Props.Links then Props.Links() else {}) :: {[string]: string} do
					if Spanning(Box.Text, Path, At) then
						task.spawn(Navigate.Go, {Path = Full})

						return
					end
				end

				for Label, Url in (if Props.Urls then Props.Urls() else {}) :: {[string]: string} do
					if Spanning(Box.Text, Label, At) then
						task.spawn(Chat.Copy, Url)

						return
					end
				end
			end)
		end,

		Vide.action(function(Object: TextBox)
			Entry.Box = Object
			Vide.cleanup(Selection.Add(Entry))
			Vide.cleanup(Object:GetPropertyChangedSignal("CursorPosition"):Connect(Track))
			Vide.cleanup(Object:GetPropertyChangedSignal("SelectionStart"):Connect(Track))
		end),

		Create "TextLabel" {
			Name = "Shown",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Props.Colour or Theme.Colors.Text,
			TextSize = Props.Size or Settings.TextSize,
			FontFace = Font.fromEnum(Props.Font or Enum.Font.BuilderSans),
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = function()
				const Chosen = Range()

				return Marked(Props.Text(), Chosen[1], Chosen[2], Theme.Colors.Accent():ToHex())
			end,
		},

		Props.Children,
	}

	Vide.cleanup(function()
		Focused += 1

		if not Holding then
			return
		end

		Holding = false
		Keys.Release()
	end)

	return Box
end