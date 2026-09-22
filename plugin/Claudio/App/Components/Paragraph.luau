--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Markdown = require(script.Parent.Parent.Parent.Markdown)
const Navigate = require(script.Parent.Parent.Parent.Navigate)
const Types = require(script.Parent.Parent.Parent.Types)
const Theme = require(script.Parent.Parent.Theme)
const Selectable = require(script.Parent.Selectable)

const function Escaped(Text: string): string
	return (Text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

return function(Text: () -> string, LayoutOrder: number, Live: boolean?)
	const Links = Vide.derive(function(): {[string]: string}
		const Found: {[string]: string} = {}

		for _, Reference in (if Live then {} else Navigate.FindReferences(Text())) :: {Types.Reference} do
			Found[(Reference.Path:gsub("^game%.", ""))] = Reference.Path
		end

		return Found
	end)

	const Urls = Vide.derive(function(): {[string]: string}
		const Found: {[string]: string} = {}

		for Label, Url in Text():gmatch("%[([^%]]+)%]%(([^%)%s]+)%)") do
			Found[Label :: string] = Url :: string
		end

		return Found
	end)

	return Selectable {
		Name = "Paragraph",
		LayoutOrder = LayoutOrder,
		Links = Links,
		Urls = Urls,
		Text = function()
			const Accent = Theme.Colors.Accent():ToHex()
			local Rich = Markdown.Rich(Text(), Settings.TextSize(), Accent)
			const Paths = {}

			for Path in Links() do
				table.insert(Paths, Path)
			end

			table.sort(Paths, function(Left, Right)
				return #Left > #Right
			end)

			for Index, Path in Paths do
				Rich = Rich:gsub(Escaped(Path), `\1{Index}\1`)
			end

			return (Rich:gsub("\1(%d+)\1", function(Index: string): string
				const Path = Paths[tonumber(Index) :: number]

				return `<font color="#{Accent}"><u>{Path}</u></font>`
			end))
		end,
	}
end