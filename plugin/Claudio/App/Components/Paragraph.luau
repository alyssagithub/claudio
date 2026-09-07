--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Markdown = require(script.Parent.Parent.Parent.Markdown)
const Navigate = require(script.Parent.Parent.Parent.Navigate)
const Theme = require(script.Parent.Parent.Theme)

const TextService = game:GetService("TextService")

const Create = Vide.create

const Trailing = "[%.,;:%)%]]+$"
const Spaces: {[number]: number} = {}

const function SpaceWidth(): number
	const Size = Settings.TextSize()

	if not Spaces[Size] then
		const Room = Vector2.new(9999, 9999)

		Spaces[Size] = TextService:GetTextSize("a a", Size, Enum.Font.BuilderSans, Room).X - TextService:GetTextSize("aa", Size, Enum.Font.BuilderSans, Room).X
	end

	return Spaces[Size]
end

const function Bare(Token: string): string
	return (Token:gsub("<[^>]->", ""):gsub(Trailing, ""))
end

const function Pieces(Line: string): {string}
	const Found: {string} = {}
	local Current = ""
	local Index = 1

	while Index <= #Line do
		const Letter = Line:sub(Index, Index)

		if Letter == "<" then
			const Close = Line:find(">", Index, true)

			if not Close then
				Current ..= Letter
				Index += 1

				continue
			end

			Current ..= Line:sub(Index, Close)
			Index = Close + 1
		elseif Letter == "`" then
			const Close = Line:find("`", Index + 1, true)

			if not Close then
				Current ..= Letter
				Index += 1

				continue
			end

			Current ..= Line:sub(Index, Close)
			Index = Close + 1
		elseif Letter == " " then
			if Current ~= "" then
				table.insert(Found, Current)
				Current = ""
			end

			Index += 1
		else
			Current ..= Letter
			Index += 1
		end
	end

	if Current ~= "" then
		table.insert(Found, Current)
	end

	return Found
end

const function Split(Line: string): {string}
	const Tokens: {string} = {}
	const Open: {string} = {}

	for _, Piece in Pieces(Line) do
		const Prefix = table.concat(Open)

		for Tag in Piece:gmatch("<(/?[^>]+)>") do
			if Tag:sub(1, 1) == "/" then
				table.remove(Open)
			else
				table.insert(Open, `<{Tag}>`)
			end
		end

		const Suffix: {string} = {}

		for Index = #Open, 1, -1 do
			table.insert(Suffix, `</{Open[Index]:match("<(%a+)")}>`)
		end

		table.insert(Tokens, `{Prefix}{Piece}{table.concat(Suffix)}`)
	end

	return Tokens
end

const function Word(Text: string, Link: string?, LayoutOrder: number)
	if not Link then
		return Create "TextLabel" {
			Name = "Word",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			RichText = true,
			LayoutOrder = LayoutOrder,
			Text = Text,
		}
	end

	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Link",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = function()
			return if Hovered() then Theme.Colors.Accent() else Theme.Colors.Button()
		end,
		TextColor3 = function()
			return if Hovered() then Theme.Colors.AccentText() else Theme.Colors.ButtonText()
		end,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.Code),
		AutoButtonColor = false,
		LayoutOrder = LayoutOrder,
		Text = Text,
		Activated = function()
			task.spawn(Navigate.Go, {Path = Link})
		end,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		},
	}
end

const function Snippet(Text: string, LayoutOrder: number)
	return Create "TextLabel" {
		Name = "Snippet",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.Colors.Code,
		TextColor3 = Theme.Colors.CodeText,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.Code),
		LayoutOrder = LayoutOrder,
		Text = Text,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		},
	}
end

const function Plain(Line: string, LayoutOrder: number)
	return Create "TextLabel" {
		Name = "Text",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Text,
		TextSize = Settings.TextSize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = LayoutOrder,
		Text = Markdown.Rich(Line),
	}
end

const function Mentions(Line: string, Links: {[string]: string}): boolean
	for Path in Links do
		if Line:find(Path, 1, true) then
			return true
		end
	end

	return false
end

const function Row(Line: string, LayoutOrder: number, Links: {[string]: string})
	if not Mentions(Line, Links) and not Line:find("`", 1, true) then
		return Plain(Line, LayoutOrder)
	end

	const Words: {Instance} = {}

	for Index, Token in Split(Markdown.Rich(Line)) do
		const Body, Tail = Token:match("^`(.-)`(.*)$")

		if Body then
			table.insert(Words, (Create "Frame" {
				Name = "Inline",
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = Index,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Snippet(Body, 1),
				Word(Tail or "", nil, 2),
			}))

			continue
		end

		const Path = Bare(Token)
		const Link = Links[Path]

		if not Link then
			table.insert(Words, (Word(Token, nil, Index)))

			continue
		end

		const Ending = Token:match(Trailing) or ""

		table.insert(Words, (Create "Frame" {
			Name = "Mention",
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = Index,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Word(Path, Link, 1),
			Word(Ending, nil, 2),
		}))
	end

	return Create "Frame" {
		Name = "Line",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = LayoutOrder,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = function()
				return UDim.new(0, SpaceWidth())
			end,
		},
		Words,
	}
end

return function(Text: () -> string, LayoutOrder: number, Live: boolean?)
	return Create "Frame" {
		Name = "Paragraph",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = LayoutOrder,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 2),
		},
		Vide.indexes(function()
			const Body = Text()
			const Links: {[string]: string} = {}

			for _, Reference in if Live then {} else Navigate.FindReferences(Body) do
				Links[(Reference.Path:gsub("^game%.", ""))] = Reference.Path
			end

			const Rows: {[string]: {Line: string, Links: {[string]: string}, Order: number}} = {}

			for Order, Line in string.split(Body, "\n") do
				Rows[`{Order}|{Line}`] = {
					Line = Line,
					Links = Links,
					Order = Order,
				}
			end

			return Rows
		end, function(Entry)
			const Found = Entry()

			return Row(Found.Line, Found.Order, Found.Links)
		end),
	}
end