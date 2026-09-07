--!strict
export type Segment = {
	Kind: "text" | "code",
	Text: string,
	Order: number,
}

const Markdown = {}

const Cached: {[string]: string} = {}
local Held = 0

function Markdown.Rich(Text: string): string
	if Cached[Text] then
		return Cached[Text]
	end

	const Built = Markdown.Build(Text)

	if Held > 400 then
		table.clear(Cached)
		Held = 0
	end

	Cached[Text] = Built
	Held += 1

	return Built
end

function Markdown.Build(Text: string): string
	const Safe = Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	const Lines: {string} = {}

	for _, Line in string.split(Safe, "\n") do
		local Marked = Line:gsub("^#+%s+(.*)$", function(Heading: string): string
			return `<b>{Heading}</b>`
		end)

		Marked = Marked:gsub("^(%s*)[%*%-]%s+", "%1• ")
		Marked = Marked:gsub("%*%*(.-)%*%*", "<b>%1</b>")

		Marked = Marked:gsub("%f[%w_]_(.-)_%f[^%w_]", function(Body: string): string
			return `<i>{Body}</i>`
		end)
		table.insert(Lines, Marked)
	end

	return table.concat(Lines, "\n")
end

function Markdown.Split(Text: string): {Segment}
	const Segments: {Segment} = {}
	local Position = 1

	while true do
		const FenceStart, FenceEnd, Body = Text:find("```[%w_-]*\n?(.-)```", Position)

		if not FenceStart or not FenceEnd or type(Body) ~= "string" then
			break
		end

		const Before = Text:sub(Position, FenceStart - 1)

		if Before:match("%S") then
			const Trimmed: Segment = {
				Kind = "text",
				Text = (Before:gsub("^%s+", ""):gsub("%s+$", "")),
				Order = #Segments + 1,
			}

			table.insert(Segments, Trimmed)
		end

		const Fenced: Segment = {
			Kind = "code",
			Text = (Body:gsub("%s+$", "")),
			Order = #Segments + 1,
		}

		table.insert(Segments, Fenced)
		Position = FenceEnd + 1
	end

	const Tail = Text:sub(Position)

	if Tail:match("%S") then
		const Trailing: Segment = {
			Kind = "text",
			Text = (Tail:gsub("^%s+", ""):gsub("%s+$", "")),
			Order = #Segments + 1,
		}

		table.insert(Segments, Trailing)
	end

	return Segments
end

return Markdown