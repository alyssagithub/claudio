--!strict
export type Segment = {
	Kind: "text" | "code" | "table",
	Text: string,
	Order: number,
	Language: string?,
	Rows: {{string}}?,
}

const Markdown = {}

const Cached: {[string]: string} = {}
local Held = 0

const Mono = 'font family="rbxasset://fonts/families/RobotoMono.json"'

function Markdown.Rich(Text: string, Size: number?, Accent: string?): string
	const Key = `{Size or 0}|{Accent or ""}|{Text}`

	if Cached[Key] then
		return Cached[Key]
	end

	const Built = Markdown.Build(Text, Size, Accent)

	if Held > 400 then
		table.clear(Cached)
		Held = 0
	end

	Cached[Key] = Built
	Held += 1

	return Built
end

function Markdown.Inline(Text: string): string
	local Marked = Text:gsub("%*%*%*(.-)%*%*%*", "<b><i>%1</i></b>")

	Marked = Marked:gsub("%*%*(.-)%*%*", "<b>%1</b>")
	Marked = Marked:gsub("%f[%w_]__(.-)__%f[^%w_]", "<b>%1</b>")
	Marked = Marked:gsub("%*(.-)%*", "<i>%1</i>")
	Marked = Marked:gsub("~~(.-)~~", "<s>%1</s>")
	Marked = Marked:gsub("%f[%w_]_(.-)_%f[^%w_]", function(Body: string): string
		return `<i>{Body}</i>`
	end)
	Marked = Marked:gsub("%[([^%]]-)%]%([^%)]-%)", function(Label: string): string
		return `<u>{Label}</u>`
	end)

	return Marked
end

function Markdown.Tokens(Text: string, Accent: string, Fade: boolean): string
	const Pieces: {string} = {}
	local At = 1

	const function Plain(Body: string)
		if Body == "" then
			return
		end

		table.insert(Pieces, if Fade then `<font transparency="1">{Body}</font>` else Body)
	end

	const function Marked(Body: string)
		table.insert(Pieces, `<font color="#{Accent}">{Body}</font>`)
	end

	while At <= #Text do
		local Start, Stop = Text:find("%[[^%[%]\n]+%]", At)

		while Start and Stop and Text:sub(Stop + 1, Stop + 1) == "(" do
			Start, Stop = Text:find("%[[^%[%]\n]+%]", Stop + 1)
		end

		const CommandStart, CommandStop = Text:find("^/[%w%-_]+", At)
		const MentionStart, MentionStop = Text:find("%f[@]@[%w_%.]+", At)
		local Chosen: number? = Start
		local Ended: number? = Stop

		if At == 1 and CommandStart then
			Chosen, Ended = CommandStart, CommandStop
		end

		if MentionStart and (not Chosen or MentionStart < Chosen) then
			Chosen, Ended = MentionStart, MentionStop
		end

		if not Chosen or not Ended then
			Plain(Text:sub(At))

			break
		end

		Plain(Text:sub(At, Chosen - 1))
		Marked(Text:sub(Chosen, Ended))
		At = Ended + 1
	end

	return table.concat(Pieces)
end

function Markdown.Build(Text: string, Size: number?, Accent: string?): string
	const Safe = Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	const Lines: {string} = {}

	for _, Line in string.split(Safe, "\n") do
		if Line:match("^%s*[-*_][-*_%s]*$") and #Line:gsub("%s", "") >= 3 then
			table.insert(Lines, "────────────")

			continue
		end

		local Marked = Line:gsub("^#+%s+.*$", function(Whole: string): string
			const Hashes, Heading = Whole:match("^(#+)%s+(.*)$")

			if not Hashes then
				return Whole
			end

			const Raised = if #Hashes == 1 then 4 elseif #Hashes == 2 then 2 else 0

			if Raised == 0 or not Size then
				return `<b>{Heading}</b>`
			end

			return `<font size="{Size + Raised}"><b>{Heading}</b></font>`
		end)

		Marked = Marked:gsub("^(%s*)[%*%-]%s+%[([ xX])%]%s+", function(...: string): string
			const Indent, Mark = ...

			return `{Indent}{if Mark == " " then "☐" else "☑"} `
		end)
		Marked = Marked:gsub("^(%s*)[%*%-]%s+", "%1• ")
		Marked = Marked:gsub("^&gt;%s?(.*)$", "▎ <i>%1</i>")
		Marked = Markdown.Coded(Marked)

		if Accent then
			Marked = Markdown.Tokens(Marked, Accent, false)
		end

		table.insert(Lines, Marked)
	end

	return table.concat(Lines, "\n")
end

function Markdown.Coded(Text: string): string
	const Spans: {string} = {}
	const Held = Text:gsub("`(.-)`", function(Body: string): string
		table.insert(Spans, Body)

		return `\2{#Spans}\2`
	end)

	return (Markdown.Inline(Held):gsub("\2(%d+)\2", function(Index: string): string
		return `<{Mono}>{Spans[tonumber(Index) :: number]}</font>`
	end))
end

function Markdown.Cell(Text: string): string
	return Markdown.Coded((Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")))
end

const function IsTableRow(Line: string): boolean
	return Line:match("^%s*|.*|%s*$") ~= nil
end

const function IsDivider(Line: string): boolean
	return Line:match("^%s*|[%s:%-|]+|%s*$") ~= nil and Line:find("%-") ~= nil
end

const function Cells(Line: string): {string}
	const Found = {}

	for Cell in (Line:gsub("^%s*|", ""):gsub("|%s*$", "") .. "|"):gmatch("(.-)|") do
		table.insert(Found, (Cell:gsub("^%s+", ""):gsub("%s+$", "")))
	end

	return Found
end

const function Tables(Text: string, Into: {Segment})
	const Lines = string.split(Text, "\n")
	local Plain: {string} = {}
	local Index = 1

	const function Flush()
		const Joined = table.concat(Plain, "\n")

		if Joined:match("%S") then
			table.insert(Into, {
				Kind = "text",
				Text = (Joined:gsub("^%s+", ""):gsub("%s+$", "")),
				Order = #Into + 1,
			})
		end

		Plain = {}
	end

	while Index <= #Lines do
		const Line = Lines[Index]
		const Next = Lines[Index + 1]

		if not (IsTableRow(Line) and Next and IsDivider(Next)) then
			table.insert(Plain, Line)
			Index += 1

			continue
		end

		Flush()

		const Rows = {Cells(Line)}

		Index += 2

		while Index <= #Lines and IsTableRow(Lines[Index]) do
			table.insert(Rows, Cells(Lines[Index]))
			Index += 1
		end

		table.insert(Into, {
			Kind = "table",
			Text = "",
			Order = #Into + 1,
			Rows = Rows,
		})
	end

	Flush()
end

function Markdown.Split(Text: string): {Segment}
	const Segments: {Segment} = {}
	local Position = 1
	local Search = 1

	while true do
		const FenceStart, FenceEnd, Language, Body = Text:find("```([%w_-]*)\n?(.-)```", Search)

		if not FenceStart or not FenceEnd or type(Body) ~= "string" or type(Language) ~= "string" then
			break
		end

		if not (Text:sub(1, FenceStart - 1):match("[^\n]*$") or ""):match("^[ \t]*$") then
			Search = FenceStart + 3
			continue
		end

		Tables(Text:sub(Position, FenceStart - 1), Segments)

		const Fenced: Segment = {
			Kind = "code",
			Text = (Body:gsub("%s+$", "")),
			Order = #Segments + 1,
			Language = if Language ~= "" then Language else nil,
		}

		table.insert(Segments, Fenced)
		Position = FenceEnd + 1
		Search = Position
	end

	Tables(Text:sub(Position), Segments)

	return Segments
end

return Markdown