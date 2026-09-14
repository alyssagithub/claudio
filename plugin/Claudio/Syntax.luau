--!strict
const Theme = require(script.Parent.App.Theme)

const Syntax = {}

const Keywords: {[string]: {[string]: boolean}} = {
	luau = {
		["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true, ["continue"] = true, ["const"] = true, ["type"] = true, ["export"] = true, ["self"] = true,
	},
	js = {
		["const"] = true, ["let"] = true, ["var"] = true, ["function"] = true, ["return"] = true, ["if"] = true, ["else"] = true, ["for"] = true, ["while"] = true, ["do"] = true, ["break"] = true, ["continue"] = true, ["new"] = true, ["class"] = true, ["extends"] = true, ["import"] = true, ["export"] = true, ["from"] = true, ["async"] = true, ["await"] = true, ["try"] = true, ["catch"] = true, ["finally"] = true, ["throw"] = true, ["typeof"] = true, ["instanceof"] = true, ["this"] = true, ["null"] = true, ["undefined"] = true, ["true"] = true, ["false"] = true, ["switch"] = true, ["case"] = true, ["default"] = true, ["of"] = true, ["in"] = true, ["yield"] = true, ["static"] = true, ["delete"] = true, ["void"] = true,
	},
	sh = {
		["if"] = true, ["then"] = true, ["else"] = true, ["elif"] = true, ["fi"] = true, ["for"] = true, ["in"] = true, ["do"] = true, ["done"] = true, ["while"] = true, ["case"] = true, ["esac"] = true, ["function"] = true, ["return"] = true, ["export"] = true, ["local"] = true, ["cd"] = true, ["echo"] = true, ["true"] = true, ["false"] = true,
	},
	json = {
		["true"] = true, ["false"] = true, ["null"] = true,
	},
}

const Builtins: {[string]: boolean} = {
	print = true, warn = true, error = true, require = true, pcall = true, xpcall = true, task = true, game = true, workspace = true, script = true, math = true, string = true, table = true, typeof = true, tostring = true, tonumber = true, ipairs = true, pairs = true, next = true, select = true, unpack = true, assert = true, Instance = true, Vector3 = true, Vector2 = true, CFrame = true, Color3 = true, UDim2 = true, UDim = true, Enum = true, buffer = true, coroutine = true, os = true, plugin = true, settings = true, console = true, process = true, Math = true, JSON = true, Promise = true, Object = true, Array = true, Buffer = true,
}

const Aliases: {[string]: string} = {
	lua = "luau",
	luau = "luau",
	javascript = "js",
	js = "js",
	mjs = "js",
	ts = "js",
	typescript = "js",
	bash = "sh",
	sh = "sh",
	shell = "sh",
	powershell = "sh",
	ps1 = "sh",
	json = "json",
}

const function Escape(Text: string): string
	return (Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

const function Paint(Text: string, Colour: Color3): string
	return `<font color="#{Colour:ToHex()}">{Escape(Text)}</font>`
end

function Syntax.Language(Name: string?): string?
	return if Name then Aliases[Name:lower()] else nil
end

function Syntax.Guess(Text: string): string
	if Text:match("^%s*[%[{]") then
		return "json"
	end

	if Text:match("%f[%w]const%s+[%w_]+%s*=") and (Text:match(";%s*\n") or Text:match("=>") or Text:match("%f[%w]await%f[%W]")) then
		return "js"
	end

	if Text:match("%f[%w]local%f[%W]") or Text:match("%f[%w]end%f[%W]") or Text:match("%f[%w]then%f[%W]") or Text:match("game:GetService") then
		return "luau"
	end

	if Text:match("^%s*%$ ") or Text:match("^%s*[%w%./-]+ [^\n]* %-%-?%a") then
		return "sh"
	end

	return "luau"
end

function Syntax.Highlight(Code: string, Language: string?): string
	const Words = Keywords[Language or "luau"] or Keywords.luau
	const Colours = Theme.Colors
	const Out = {}
	local At = 1

	while At <= #Code do
		const Rest = Code:sub(At)
		const Comment = if Language == "luau" or Language == nil then Rest:match("^%-%-%[%[.-%]%]") or Rest:match("^%-%-[^\n]*") elseif Language == "js" then Rest:match("^/%*.-%*/") or Rest:match("^//[^\n]*") elseif Language == "sh" then Rest:match("^#[^\n]*") else nil

		if Comment then
			table.insert(Out, Paint(Comment, Colours.Comment()))
			At += #Comment

			continue
		end

		const Long = if Language == "luau" or Language == nil then Rest:match("^%[%[.-%]%]") else nil
		const Quoted = Long or Rest:match('^"[^"\n]*"') or Rest:match("^'[^'\n]*'") or Rest:match("^`[^`]*`")

		if Quoted then
			table.insert(Out, Paint(Quoted, Colours.String()))
			At += #Quoted

			continue
		end

		const Number = Rest:match("^0[xX]%x+") or Rest:match("^%d+%.?%d*[eE]?[%+%-]?%d*")

		if Number and not Code:sub(At - 1, At - 1):match("[%w_]") then
			table.insert(Out, Paint(Number, Colours.Number()))
			At += #Number

			continue
		end

		const Word = Rest:match("^[%a_][%w_]*")

		if Word then
			const Before = Code:sub(At - 1, At - 1)
			const Colour = if Words[Word] then Colours.Keyword() elseif Builtins[Word] and Before ~= "." and Before ~= ":" then Colours.Builtin() elseif Rest:sub(#Word + 1):match("^%s*%(") then Colours.Call() else nil

			table.insert(Out, if Colour then Paint(Word, Colour) else Escape(Word))
			At += #Word

			continue
		end

		const Operator = Rest:match("^[%+%-%*/%%%^#=~<>:%.,;%(%)%[%]{}|&!?]+")

		if Operator then
			table.insert(Out, Paint(Operator, Colours.Operator()))
			At += #Operator

			continue
		end

		const Plain = Rest:match("^[^%w_\"'`%-/#%[%+%*%%%^=~<>:%.,;%(%)%]{}|&!?]+") or Rest:sub(1, 1)

		table.insert(Out, Escape(Plain))
		At += #Plain
	end

	return table.concat(Out)
end

return Syntax