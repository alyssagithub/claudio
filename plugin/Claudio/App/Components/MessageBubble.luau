--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Config = require(script.Parent.Parent.Parent.Config)
const Markdown = require(script.Parent.Parent.Parent.Markdown)
const Format = require(script.Parent.Parent.Parent.Format)
const Changes = require(script.Parent.Parent.Parent.Changes)
const Syntax = require(script.Parent.Parent.Parent.Syntax)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Navigate = require(script.Parent.Parent.Parent.Navigate)
const Theme = require(script.Parent.Parent.Theme)
const ImageView = require(script.Parent.ImageView)
const Paragraph = require(script.Parent.Paragraph)
const Icon = require(script.Parent.Icon)
const IconButton = require(script.Parent.IconButton)
const Button = require(script.Parent.Button)
const Limits = require(script.Parent.LimitCard)

const TextService = game:GetService("TextService")

const Create = Vide.create

type Props = {
	Role: () -> string,
	Text: () -> string,
	Activity: () -> {string},
	Thinking: (() -> string?)?,
	Parts: (() -> {Types.Piece}?)?,
	Calls: (() -> {Types.ToolCall})?,
	Edits: (() -> {Types.Change}?)?,
	Tokens: (() -> Types.Tokens?)?,
	Milliseconds: (() -> number?)?,
	Failed: (() -> boolean)?,
	Error: (() -> string?)?,
	Cost: (() -> number?)?,
	Estimated: (() -> boolean?)?,
	Prompt: (() -> string?)?,
	At: (() -> number?)?,
	Index: (() -> number)?,
	Attachments: (() -> {string})?,
	Images: (() -> {EditableImage})?,
	Model: (() -> string?)?,
	Live: boolean?,
	Checkpoint: (() -> number?)?,
	LayoutOrder: any,
}

const function IsCommand(Name: string): boolean
	return Name == "Bash" or Name == "PowerShell"
end

const function Counted(Added: number, Removed: number): string
	return ` <font color="#{Theme.Colors.AddedText():ToHex()}">+{Added}</font> <font color="#{Theme.Colors.Error():ToHex()}">-{Removed}</font>`
end

const function FileWork(Entry: Types.ToolCall, Running: boolean): string?
	if Entry.name ~= "Write" and Entry.name ~= "Edit" and Entry.name ~= "MultiEdit" then
		return nil
	end

	const File = (Entry.input:match("file_path: ([^\n]+)") or ""):match("[^/\\]+$") or "a file"
	const Lines = Entry.lines
	const Verb = if Entry.name ~= "Write" then (if Running then "Editing" else "Edited")
		elseif Lines and Lines.removed == 0 then (if Running then "Creating" else "Created")
		else (if Running then "Rewriting" else "Rewrote")

	return `{Verb} {File}{if Lines then Counted(Lines.added, Lines.removed) else ""}`
end

const function Describe(Entry: Types.ToolCall, Running: boolean): string
	const Wrote = FileWork(Entry, Running)

	if Wrote then
		return Wrote
	end

	if Entry.delegate then
		const Sent = Entry.delegate :: {name: string, model: string}

		return `{if Running then "Delegating" else "Delegated"} to the {Sent.name} on {Format.Model(Sent.model)}`
	end

	const Name = Entry.name

	if IsCommand(Name) then
		return if Running then "Running a command" else "Ran a command"
	end

	const Server, Tool = Name:match("^mcp__(.-)__(.+)$")
	const Verb = if Running then "Using" else "Used"

	if not Server or not Tool then
		return `{Verb} {Name}`
	end

	const Words = (Tool:gsub("_", " "))

	return `{Verb} {Server}: {Words:sub(1, 1):upper()}{Words:sub(2)}`
end

const function Note(Name: string, LayoutOrder: any, Text: () -> string, Visible: () -> boolean)
	return Create "TextLabel" {
		Name = Name,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.DimText,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = LayoutOrder,
		Visible = Visible,
		Text = Text,
	}
end

return function(Props: Props)
	const Hovered = Vide.source(false)

	const function IsUser(): boolean
		return Props.Role() == "user"
	end

	const function Hug(): number
		if not IsUser() or (Props.Images ~= nil and #Props.Images() > 0) then
			return math.huge
		end

		return TextService:GetTextSize(Props.Text(), Settings.TextSize(), Enum.Font.BuilderSans, Vector2.new(9999, 9999)).X + 21
	end

	const function Segment(Value: () -> Markdown.Segment)
		const function IsCode(): boolean
			return Value().Kind == "code"
		end

		if not IsCode() then
			return Paragraph(function()
				return Value().Text
			end, 1000 + Value().Order, Props.Index == nil)
		end

		const function CodePadding(): UDim
			return UDim.new(0, if IsCode() then 8 else 0)
		end

		return Create "TextLabel" {
			Name = function()
				return if IsCode() then "Code" else "Text"
			end,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Code,
			BackgroundTransparency = function()
				return if IsCode() then 0 else 1
			end,
			TextColor3 = function()
				return if IsCode() then Theme.Colors.CodeText() else Theme.Colors.Text()
			end,
			TextSize = Settings.TextSize,
			FontFace = function()
				return Font.fromEnum(if IsCode() then Enum.Font.Code else Enum.Font.BuilderSans)
			end,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = function()
				const Body = Value().Text

				return if IsCode() then Syntax.Highlight(Body, Syntax.Language(Value().Language) or Syntax.Guess(Body)) else Markdown.Rich(Body, Settings.TextSize())
			end,
			LayoutOrder = 1000 + Value().Order,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = CodePadding,
				PaddingRight = CodePadding,
				PaddingTop = function()
					return UDim.new(0, if IsCode() then 6 else 0)
				end,
				PaddingBottom = function()
					return UDim.new(0, if IsCode() then 6 else 0)
				end,
			},
		}
	end

	const function Spend(): string
		const At = if Props.At then Props.At() else nil
		const Tokens = if Props.Tokens then Props.Tokens() else nil
		const Cost = if Props.Cost then Props.Cost() else nil
		const Parts: {string} = {}

		if At then
			table.insert(Parts, (Format.Ago(At)))
		end

		if Tokens then
			const Counted = if IsUser() then Tokens.input else Tokens.output

			if Counted > 0 then
				table.insert(Parts, `{Format.Amount(Counted)} tokens`)
			end
		end

		if Cost and Cost > 0 then
			table.insert(Parts, `{if Props.Estimated and Props.Estimated() then "~" else ""}${string.format("%.3f", Cost)}`)
		end

		return table.concat(Parts, " · ")
	end

	const function Written(): {Types.Change}
		return Changes.For({
			Edits = if Props.Edits then Props.Edits() else nil,
			Calls = if Props.Calls then Props.Calls() else nil,
		} :: any)
	end

	const Shown = Vide.source(false)

	const function Broke(): string
		return if Props.Error then Props.Error() or "" else ""
	end

	const function Empty(): boolean
		return Props.Text() == ""
			and (if Props.Thinking then Props.Thinking() or "" else "") == ""
			and #(if Props.Calls then Props.Calls() else {}) == 0
			and #(if Props.Images then Props.Images() else {}) == 0
			and #(if Props.Attachments then Props.Attachments() else {}) == 0
			and Broke() == ""
			and #Written() == 0
	end

	const Expanded = Vide.source(false)

	const function Trimmed(): {Types.Change}
		const All = Written()

		if Expanded() or #All <= 5 then
			return All
		end

		const Some = {}

		for Index = 1, 5 do
			table.insert(Some, All[Index])
		end

		return Some
	end

	const function Asked(Entry: Types.ToolCall): {{Question: string, Given: string}}
		const Pairs = {}

		if Entry.name ~= Config.AskTool then
			return Pairs
		end

		for Question, Given in Entry.output:gmatch('"([^"]+)"="([^"]*)"') do
			table.insert(Pairs, {Question = Question, Given = Given or ""})
		end

		return Pairs
	end

	const function Headline(Entry: Types.ToolCall, Running: boolean): string
		return Describe(Entry, Running)
	end

	const function Shortened(Text: string): string
		const Lines = string.split(Text, "\n")

		if #Lines <= 40 then
			return Text
		end

		const Kept = table.move(Lines, 1, 40, 1, {})

		table.insert(Kept, `… {#Lines - 40} more lines`)

		return table.concat(Kept, "\n")
	end

	const function Fields(Input: string): {{Key: string, Value: string}}
		const Found = {}

		for _, Line in string.split(Input, "\n") do
			const Key, Value = Line:match("^([%w_]+): (.*)$")

			if Key and Value then
				table.insert(Found, {Key = Key, Value = Value})
			elseif #Found > 0 then
				Found[#Found].Value ..= `\n{Line}`
			end
		end

		return Found
	end

	const function CodeBlock(Name: string, Text: () -> string, Language: () -> string?, LayoutOrder: number, Small: boolean?)
		return Create "TextLabel" {
			Name = Name,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Code,
			TextColor3 = Theme.Colors.CodeText,
			TextSize = if Small then Settings.SmallText else Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = LayoutOrder,
			Visible = function()
				return Text() ~= ""
			end,
			Text = function()
				const Body = Text()

				return Syntax.Highlight(Body, Language() or Syntax.Guess(Body))
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},
		}
	end

	const CodeFields: {[string]: boolean} = {code = true, text = true, source = true, command = true, content = true, old_string = true, new_string = true, prompt = true}

	const function Call(Value: () -> Types.ToolCall, Index: number)
		const Open = Vide.source(false)

		const function Title(): string
			const Name = Value().name
			const Server, Tool = Name:match("^mcp__(.-)__(.+)$")

			if not Server or not Tool then
				return Name
			end

			const Words = (Tool:gsub("_", " "))

			return `{Words:sub(1, 1):upper()}{Words:sub(2)}`
		end

		return Create "Frame" {
			Name = "ToolCall",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = Index,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 4),
			},
			Create "Frame" {
				Name = "Answered",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				LayoutOrder = 0,
				Visible = function()
					return #Asked(Value()) > 0
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 6)},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				},
				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 8),
				},
				Vide.indexes(function()
					return Asked(Value())
				end, function(Pair: () -> {Question: string, Given: string}, Order: number)
					return Create "Frame" {
						Name = "Line",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = Order,

						Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
						Create "TextLabel" {
							Name = "Question",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.DimText,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextWrapped = true,
							LayoutOrder = 1,
							Text = function()
								return Pair().Question
							end,
						},
						Create "TextLabel" {
							Name = "Given",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.Text,
							TextSize = Settings.TextSize,
							FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextWrapped = true,
							LayoutOrder = 2,
							Text = function()
								return (Pair().Given:gsub(",", ", "))
							end,
						},
					}
				end),
			},
			Create "Frame" {
				Name = "Box",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Background,
				LayoutOrder = 1,
				Visible = function()
					return #Asked(Value()) == 0
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 8)},
				Create "UIStroke" {Color = Theme.Colors.Border},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				},
				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 6),
				},
				Create "TextButton" {
					Name = "Header",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = 1,
					Activated = function()
						Open(not Open())
					end,

					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					},
					Create "TextLabel" {
						Name = "Summary",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = function()
							return if Value().status == "error" then Theme.Colors.Error() else Theme.Colors.Text()
						end,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						RichText = true,
						LayoutOrder = 1,
						Text = function()
							const Entry = Value()

							if Entry.status == "running" then
								return Headline(Entry, true)
							end

							return `{Headline(Entry, false)}{if Entry.status == "error" then " · failed" else ""}`
						end,
					},
					Icon {
						Name = function()
							return if Open() then Config.Icons.Down else Config.Icons.Right
						end,
						Size = Settings.SmallText,
						Colour = function()
							return if Value().status == "error" then Theme.Colors.Error() else Theme.Colors.DimText()
						end,
						LayoutOrder = 2,
					},
				},
				Create "TextLabel" {
					Name = "Title",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
					Visible = function()
						return Open() and Title() ~= Headline(Value(), false)
					end,
					Text = Title,
				},
				Vide.indexes(function()
					return if Open() then Fields(Value().input) else {}
				end, function(Pair: () -> {Key: string, Value: string}, Order: number)
					const function IsCode(): boolean
						return CodeFields[Pair().Key] == true or Pair().Value:find("\n") ~= nil
					end

					return Create "Frame" {
						Name = "Field",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 2 + Order,
						Visible = function()
							return Pair().Key ~= "label" and Pair().Key ~= "description"
						end,

						Create "UIListLayout" {
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalFlex = Enum.UIFlexAlignment.Fill,
							Padding = UDim.new(0, 2),
						},
						Create "TextLabel" {
							Name = "Line",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.Text,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.Code),
							TextWrapped = true,
							RichText = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							LayoutOrder = 1,
							Text = function()
								const Shown = if IsCode() then "" else ` {Pair().Value:gsub("&", "&amp;"):gsub("<", "&lt;")}`

								return `<font color="#{Theme.Colors.DimText():ToHex()}">{Pair().Key}:</font>{Shown}`
							end,
						},
						CodeBlock("Code", function()
							return if IsCode() then Shortened(Pair().Value) else ""
						end, function()
							return if Pair().Key == "command" then "sh" else nil
						end, 2, true),
					}
				end),
				Create "TextLabel" {
					Name = "Output",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = function()
						return if Value().status == "error" then Theme.Colors.Error() else Theme.Colors.DimText()
					end,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.Code),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					LayoutOrder = 1000,
					Visible = function()
						return Open() and Value().output ~= ""
					end,
					Text = function()
						return if Open() then Shortened(Value().output) else ""
					end,

					Create "UIPadding" {PaddingTop = UDim.new(0, 2)},
				},
				Vide.show(function()
					const Slot = Value().image

					return Open() and Slot ~= nil and Props.Images ~= nil and (Props.Images() :: {EditableImage?})[Slot] ~= nil
				end, function()
					const Picture = (Props.Images :: () -> {EditableImage})()[Value().image :: number]

					return ImageView(function()
						return Picture
					end, 1001)
				end),
				Vide.indexes(function()
					return if Open() then Value().steps or {} else {}
				end, function(Step: () -> string, Order: number)
					return Create "TextLabel" {
						Name = "Step",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2000 + Order,
						Text = function()
							return `· {Step()}`
						end,
					}
				end),
			},
		}
	end

	type Block = {
		Kind: "thinking" | "text" | "calls" | "user",
		Text: string?,
		Calls: {number}?,
	}

	const function Blocks(): {Block}
		const Found: {Block} = {}
		const Parts = if Props.Parts then Props.Parts() else nil
		const Calls: {Types.ToolCall} = if Props.Calls then Props.Calls() else {}

		if not Parts or #Parts == 0 then
			const Thinking = if Props.Thinking then Props.Thinking() or "" else ""

			if Thinking:match("%S") then
				table.insert(Found, {Kind = "thinking", Text = Thinking})
			end

			if #Calls > 0 then
				const All = {}

				for Index in Calls do
					table.insert(All, Index)
				end

				table.insert(Found, {Kind = "calls", Calls = All})
			end

			if Props.Text() ~= "" then
				table.insert(Found, {Kind = "text", Text = Props.Text()})
			end

			return Found
		end

		for _, Piece in Parts do
			if Piece.Kind == "thinking" and not Chat.Thinking() then
				continue
			end

			const Last = Found[#Found]

			if Piece.Kind == "call" and Piece.Call and Calls[Piece.Call] then
				if Last and Last.Kind == "calls" and Last.Calls then
					table.insert(Last.Calls, Piece.Call)
				else
					table.insert(Found, {Kind = "calls", Calls = {Piece.Call}})
				end
			elseif Piece.Kind == "thinking" or Piece.Kind == "text" or Piece.Kind == "user" then
				if Last and Last.Kind == Piece.Kind and Piece.Kind ~= "user" then
					Last.Text = `{Last.Text or ""}{if Piece.Kind == "text" then "\n\n" else "\n"}{Piece.Text or ""}`
				else
					table.insert(Found, {Kind = Piece.Kind, Text = Piece.Text or ""})
				end
			end
		end

		return Found
	end

	const function Summarize(Chosen: {number}): string
		const Calls: {Types.ToolCall} = if Props.Calls then Props.Calls() else {}
		local Commands = 0
		local Questions = 0
		local Sent = 0
		local Added = 0
		local Removed = 0
		const Files = {}

		for _, Index in Chosen do
			const Entry = Calls[Index]

			if not Entry then
				continue
			end

			if Entry.name == Config.AskTool then
				Questions += 1

				continue
			end

			if Entry.status == "running" then
				return Headline(Entry, true)
			end

			if Entry.delegate then
				Sent += 1

				continue
			end

			if IsCommand(Entry.name) then
				Commands += 1
			end

			const Wrote = FileWork(Entry, false)

			if Wrote and Entry.status ~= "error" then
				table.insert(Files, (Wrote:gsub(" <font.*$", "")))
				Added += if Entry.lines then Entry.lines.added else 0
				Removed += if Entry.lines then Entry.lines.removed else 0
			end
		end

		const Tools = #Chosen - Commands - Questions - Sent - #Files
		const Parts = {}

		if #Files > 0 and #Files <= 2 then
			table.insert(Parts, table.concat(Files, ", "))
		elseif #Files > 2 then
			table.insert(Parts, `edited {#Files} files`)
		end

		if Sent > 0 then
			table.insert(Parts, if Sent == 1 then "delegated a read" else `delegated {Sent} reads`)
		end

		if Commands > 0 then
			table.insert(Parts, if Commands == 1 then "ran a command" else `ran {Commands} commands`)
		end

		if Tools > 0 or #Parts == 0 then
			table.insert(Parts, `used {Tools} tool{if Tools == 1 then "" else "s"}`)
		end

		const Line = table.concat(Parts, ", ")

		return `{Line:sub(1, 1):upper()}{Line:sub(2)}{if #Files > 0 then Counted(Added, Removed) else ""}`
	end

	const Blank: Types.ToolCall = {name = "", input = "", output = "", status = "done", milliseconds = 0}

	const function Group(Value: () -> Block, Index: number)
		const Listed = Vide.source(false)

		const function Kind(): string
			return Value().Kind
		end

		const function Many(): boolean
			const Chosen = Value().Calls

			return Chosen ~= nil and #Chosen > 1
		end

		return Create "Frame" {
			Name = function()
				return `{Kind():sub(1, 1):upper()}{Kind():sub(2)}`
			end,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = Index,
			Visible = function()
				return Kind() ~= "thinking" or Chat.Thinking()
			end,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = function()
					return if Kind() == "user" then Enum.UIFlexAlignment.None else Enum.UIFlexAlignment.Fill
				end,
				HorizontalAlignment = function()
					return if Kind() == "user" then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
				end,
				Padding = UDim.new(0, 6),
			},
			Create "Frame" {
				Name = "Thought",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Visible = function()
					return Kind() == "thinking"
				end,

				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
				},
				Create "Frame" {
					Name = "Rule",
					Size = UDim2.new(0, 2, 1, 0),
					Position = UDim2.fromOffset(-12, 0),
					BackgroundColor3 = Theme.Colors.Border,
					BorderSizePixel = 0,

					Create "UICorner" {CornerRadius = UDim.new(1, 0)},
				},
				Create "TextLabel" {
					Name = "Text",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
					TextWrapped = true,
					LineHeight = 1.15,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = function()
						return if Kind() == "thinking" then ((Value().Text or ""):gsub("^%s+", ""):gsub("%s+$", "")) else ""
					end,
				},
			},
			Create "Frame" {
				Name = "Said",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Visible = function()
					return Kind() == "text"
				end,

				Create "UIListLayout" {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
				},
				Vide.indexes(Vide.derive(function()
					const Keyed: {[string]: Markdown.Segment} = {}

					if Kind() ~= "text" then
						return Keyed
					end

					for _, Piece in Markdown.Split(Value().Text or "") do
						Keyed[`{Piece.Order}|{Piece.Kind}`] = Piece
					end

					return Keyed
				end), Segment),
			},
			Create "Frame" {
				Name = "Asked",
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Panel,
				LayoutOrder = 3,
				Visible = function()
					return Kind() == "user"
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 8)},
				Create "UIStroke" {Color = Theme.Colors.Border},
				Create "UISizeConstraint" {
					MaxSize = function()
						return Vector2.new(math.max(40, math.floor(Hug() * 0.85)), math.huge)
					end,
				},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				},
				Create "TextLabel" {
					Name = "Text",
					Size = UDim2.fromOffset(0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = function()
						return if Kind() == "user" then Value().Text or "" else ""
					end,

					Create "UISizeConstraint" {
						MaxSize = function()
							return Vector2.new(math.max(20, math.floor(Hug() * 0.85) - 20), math.huge)
						end,
					},
				},
			},
			Create "TextButton" {
				Name = "Summary",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = 4,
				Visible = function()
					return Kind() == "calls" and Many()
				end,
				Activated = function()
					Listed(not Listed())
				end,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				},
				Create "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextXAlignment = Enum.TextXAlignment.Left,
					RichText = true,
					LayoutOrder = 1,
					Text = function()
						return if Kind() == "calls" then Summarize(Value().Calls or {}) else ""
					end,
				},
				Icon {
					Name = function()
						return if Listed() then Config.Icons.Down else Config.Icons.Right
					end,
					Size = Settings.SmallText,
					LayoutOrder = 2,
				},
			},
			Create "Frame" {
				Name = "Calls",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 5,
				Visible = function()
					return Kind() == "calls" and (not Many() or Listed())
				end,

				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 4),
				},
				Vide.indexes(function()
					return if Kind() == "calls" then Value().Calls or {} else {}
				end, function(Which: () -> number, Order: number)
					return Call(function()
						return (Props.Calls :: () -> {Types.ToolCall})()[Which()] or Blank
					end, Order)
				end),
			},
		}
	end

	return Create "Frame" {
		Name = function()
			return if IsUser() then "UserMessage" else "AssistantMessage"
		end,
		Size = function()
			return UDim2.fromScale(if IsUser() then 0.85 else 1, 0)
		end,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Props.LayoutOrder,
		Visible = function()
			return not Empty()
		end,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = function()
				return if IsUser() then Enum.UIFlexAlignment.None else Enum.UIFlexAlignment.Fill
			end,
			HorizontalAlignment = function()
				return if IsUser() then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
			end,
			Padding = UDim.new(0, 2),
		},
		Create "Frame" {
			Name = "Bubble",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = function()
				return if IsUser() then 0 else 1
			end,
			LayoutOrder = 1,

			Create "UICorner" {CornerRadius = UDim.new(0, 8)},
			Create "UISizeConstraint" {
				MaxSize = function()
					return Vector2.new(Hug(), math.huge)
				end,
			},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			Create "UIListLayout" {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},
			Vide.indexes(Blocks, Group),
			Create "TextButton" {
				Name = "Trouble",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = 1000004,
				Visible = function()
					return Broke() ~= ""
				end,
				Activated = function()
					Shown(not Shown())
				end,

				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 4),
				},
				Create "Frame" {
					Name = "Line",
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					LayoutOrder = 1,

					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					},
					Icon {
						Name = Config.Icons.Limit,
						Size = Settings.SmallText,
						Colour = Theme.Colors.Error,
						LayoutOrder = 1,
					},
					Create "TextLabel" {
						Name = "Label",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Error,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
						Text = function()
							return if Format.IsLimit(Broke()) then "Session limit reached" else "Claude hit an error"
						end,
					},
					Icon {
						Name = Config.Icons.Down,
						Size = Settings.SmallText,
						Colour = Theme.Colors.Error,
						Rotation = function()
							return if Shown() then 0 else -90
						end,
						LayoutOrder = 3,
					},
				},
				Create "TextLabel" {
					Name = "Said",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Colors.Code,
					TextColor3 = Theme.Colors.CodeText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.Code),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					LayoutOrder = 2,
					Visible = Shown,
					Text = Broke,

					Create "UICorner" {CornerRadius = UDim.new(0, 4)},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
					},
				},
			},
			Vide.show(function()
				return Format.IsLimit(Broke())
			end, function()
				return Limits.Card(Broke, function()
					task.spawn(Chat.Continue, if Props.Prompt then Props.Prompt() else nil)
				end, 1000005)
			end),
			Note("Activity", 0, function()
				const Names = {}

				for _, Name in Props.Activity() do
					table.insert(Names, (Name:gsub("^mcp__.-__", "")))
				end

				return `Used {table.concat(Names, ", ")}`
			end, function()
				return #Props.Activity() > 0 and (not Props.Calls or #Props.Calls() == 0)
			end),
			Vide.indexes(Vide.derive(function()
				const Claimed = {}
				const Made: {Types.ToolCall} = if Props.Calls then Props.Calls() else {}
				const All: {EditableImage} = if Props.Images then Props.Images() else {}

				for _, Call in Made do
					if Call.image then
						Claimed[Call.image] = true
					end
				end

				const Loose = {}

				for Index, Image in All do
					if not Claimed[Index] then
						Loose[Index] = Image
					end
				end

				return Loose
			end), function(Image, Index: number)
				return ImageView(Image, 900000 + Index)
			end),
			Note("Attachments", 1000000, function()
				return `Attached {table.concat(if Props.Attachments then Props.Attachments() else {}, ", ")}`
			end, function()
				return Props.Attachments ~= nil and #Props.Attachments() > 0
			end),
		},
		Create "Frame" {
			Name = "Changes",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			LayoutOrder = 2,
			Visible = function()
				return #Written() > 0
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 8)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 2),
			},
			Create "Frame" {
				Name = "Heading",
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				},
				Create "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					Text = function()
							local Scripts = 0
						local Total = 0
						local Made = 0
						local Gone = 0

						for _, Change in Written() do
							if not Change.Path then
								continue
							end

							Total += 1

							if Change.Added or Change.Removed then
								Scripts += 1
							end

							if Change.Kind == "added" then
								Made += 1
							elseif Change.Kind == "removed" then
								Gone += 1
							end
						end

						const Verb = if Made == Total then "Created" elseif Gone == Total then "Deleted" elseif Scripts == Total then "Edited" else "Changed"
						const Noun = if Scripts == Total then "script" else "instance"

						return `{if IsUser() then "You " else ""}{if IsUser() then Verb:lower() else Verb} {Total} {Noun}{if Total == 1 then "" else "s"}`
					end,
				},
				Create "Frame" {
					Name = "Spacer",
					Size = UDim2.fromOffset(0, 0),
					BackgroundTransparency = 1,
					LayoutOrder = 2,

					Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				},
				Button {
					Text = "Undo",
					LayoutOrder = 3,
					Visible = function()
						return not IsUser() and Props.Index ~= nil and Chat.UndoPoint(Props.Index()) ~= nil
					end,
					OnClick = function()
						Chat.Rewinding(if Props.Index then Chat.UndoPoint(Props.Index()) else nil)
					end,
				},
			},
			Vide.indexes(Trimmed, function(Entry: () -> Types.Change, Index: number)
				const Hovered = Vide.source(false)

				const function Counted(): boolean
					return Entry().Added ~= nil or Entry().Removed ~= nil
				end

				const function Sign(): string
					return if Entry().Kind == "added" then "+" elseif Entry().Kind == "removed" then "-" else ""
				end

				return Create "TextButton" {
					Name = "Change",
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundColor3 = function()
						return if Sign() == "+" then Theme.Colors.Added() elseif Sign() == "-" then Theme.Colors.Removed() else Theme.Colors.Button()
					end,
					BackgroundTransparency = function()
						if Sign() == "" then
							return if Hovered() then 0.5 else 1
						end

						return if Hovered() then 0 else 0.35
					end,
					AutoButtonColor = false,
					Text = "",
					LayoutOrder = Index + 1,
					MouseEnter = function()
						Hovered(true)
					end,
					MouseLeave = function()
						Hovered(false)
					end,
					Activated = function()
						const Path = Entry().Path

						if Path then
							task.spawn(Navigate.Go, {Path = Path})
						end
					end,

					Create "UICorner" {CornerRadius = UDim.new(0, 4)},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					},
					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					},
					Create "TextLabel" {
						Name = "Sign",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						TextColor3 = function()
							return if Sign() == "-" then Theme.Colors.Error() else Theme.Colors.AddedText()
						end,
						TextSize = Settings.TextSize,
						FontFace = Font.fromEnum(Enum.Font.Code),
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 0,
						Visible = function()
							return Sign() ~= ""
						end,
						Text = Sign,
					},
					Icon {
						Name = function()
							const Path = Entry().Path or ""

							if Path == "" then
								return ""
							end

							if Path:find("[/\\]") then
								return Config.Icons.File
							end

							return if Counted() then Config.Icons.Script else Config.Icons.Instance
						end,
						Size = Settings.SmallText,
						Colour = function()
							return if Sign() == "-" then Theme.Colors.Error() elseif Sign() == "+" then Theme.Colors.AddedText() else Theme.Colors.DimText()
						end,
						LayoutOrder = 1,
					},
					Create "TextLabel" {
						Name = "Name",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.TextSize,
						FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
						Text = function()
							const Path = Entry().Path

							return if Path then (Path:match("[^%./\\]+$") or Path) else Entry().Text
						end,

						Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Shrink},
					},
					Create "TextLabel" {
						Name = "Detail",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 3,
						Visible = function()
							return Entry().Path ~= nil and not Counted()
						end,
						Text = function()
							return (Entry().Text:match("^(%a+)") or ""):lower()
						end,

						Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Shrink},
					},
					Create "Frame" {
						Name = "Spacer",
						Size = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						LayoutOrder = 4,

						Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
					},
					Create "TextLabel" {
						Name = "Lines",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
						RichText = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						LayoutOrder = 5,
						Visible = Counted,
						Text = function()
							const function Hex(Colour: Color3): string
								return `#{Colour:ToHex()}`
							end

							return `<font color="{Hex(Theme.Colors.AddedText())}">+{Entry().Added or 0}</font> <font color="{Hex(Theme.Colors.Error())}">-{Entry().Removed or 0}</font>`
						end,
					},
					Icon {
						Name = Config.Icons.Right,
						Size = Settings.SmallText,
						Colour = Theme.Colors.DimText,
						LayoutOrder = 6,
						Visible = function()
							return Entry().Path ~= nil
						end,
					},
				}
			end),
			Create "TextButton" {
				Name = "More",
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				LayoutOrder = 1000000,
				Visible = function()
					return #Written() > 5
				end,
				Text = function()
					return if Expanded() then "Show fewer" else `Show {#Written() - 5} more  >`
				end,
				Activated = function()
					Expanded(not Expanded())
				end,

				Create "UIPadding" {PaddingLeft = UDim.new(0, 4)},
			},
		},
		Note("Model", if Props.Live then -2 else 1000002, function()
			return if Props.Model then Props.Model() or "" else ""
		end, function()
			return Props.Model ~= nil and Props.Model() ~= nil
		end),
		Create "Frame" {
			Name = "Actions",
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			LayoutOrder = 3,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = function()
					return if IsUser() then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
				end,
				Padding = UDim.new(0, 4),
			},
			Create "ImageLabel" {
				Name = "Mark",
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = Config.ButtonIcon,
				LayoutOrder = 0,
				Visible = function()
					return not IsUser() and Props.Index ~= nil
				end,
			},
			Vide.show(function()
				return Hovered() or (Props.Failed ~= nil and Props.Failed())
			end, function()
				return Create "Frame" {
					Name = "Buttons",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					LayoutOrder = 1,

					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = function()
							return if IsUser() then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
						end,
						Padding = UDim.new(0, 4),
					},
					Button {
						Text = "Continue",
						LayoutOrder = 1,
						Visible = function()
							return Props.Failed ~= nil and Props.Failed() and not Format.IsLimit(Broke()) and Props.Prompt ~= nil and Props.Prompt() ~= nil
						end,
						OnClick = function()
							task.spawn(Chat.Continue, if Props.Prompt then Props.Prompt() else nil)
						end,
					},
					IconButton {
						Icon = Config.Icons.Retry,
						LayoutOrder = 1,
						Size = Settings.SmallText,
						Visible = function()
							return Hovered() and IsUser() and Props.Index ~= nil and Props.Index() ~= nil
						end,
						Disabled = Chat.Sending,
						Tooltip = "Send this again",
						DisabledTooltip = "Cannot resend while Claude is working",
						OnClick = function()
							task.spawn(Chat.Retry, if Props.Index then Props.Index() else 0)
						end,
					},
					IconButton {
						Icon = Config.Icons.Copy,
						LayoutOrder = 2,
						Size = Settings.SmallText,
						Visible = Hovered,
						Tooltip = "Copy",
						OnClick = function()
							task.spawn(Chat.Copy, Props.Text())
						end,
					},
					IconButton {
						Icon = Config.Icons.Fork,
						LayoutOrder = 3,
						Size = Settings.SmallText,
						Visible = Hovered,
						Tooltip = "Fork from here",
						OnClick = function()
							task.spawn(Chat.ForkHere)
						end,
					},
					IconButton {
						Icon = function()
							return if Props.Index and Chat.IsChapter(Props.Index()) then Config.Icons.Unpin else Config.Icons.Pin
						end,
						LayoutOrder = 4,
						Size = Settings.SmallText,
						Visible = function()
							return Hovered() and not IsUser() and Props.Index ~= nil
						end,
						Active = function()
							return Props.Index ~= nil and Chat.IsChapter(Props.Index())
						end,
						Tooltip = function()
							return if Props.Index and Chat.IsChapter(Props.Index()) then "Unpin chapter" else "Pin as chapter"
						end,
						OnClick = function()
							if not Props.Index then
								return
							end

							task.spawn(Chat.ToggleChapter, Props.Index(), Props.Text())
						end,
					},
					IconButton {
						Icon = Config.Icons.Restore,
						LayoutOrder = 5,
						Size = Settings.SmallText,
						Visible = function()
							return Hovered() and Props.Checkpoint ~= nil and Props.Checkpoint() ~= nil and Props.Index ~= nil and Props.Index() ~= nil
						end,
						Disabled = Chat.Sending,
						Tooltip = "Rewind",
						DisabledTooltip = "Rewind is unavailable while Claude is working",
						OnClick = function()
							const Index = if Props.Checkpoint then Props.Checkpoint() else nil

							if not Index then
								return
							end

							Chat.Rewinding(if Props.Index then Props.Index() else nil)
						end,
					},
					Create "TextLabel" {
						Name = "Usage",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.TextSize,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						LayoutOrder = 7,
						Visible = function()
							return Hovered() and Spend() ~= ""
						end,
						Text = function()
							return Spend()
						end,

						Create "UIPadding" {PaddingLeft = UDim.new(0, 4)},
					},
				}
			end),
		},
	}
end