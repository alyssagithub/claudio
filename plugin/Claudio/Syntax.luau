--!strict
const Theme = require(script.Parent.App.Theme)
const Highlighter = require(script.Parent.Packages.highlighter)

type Grammar = {
	Keywords: {[string]: boolean},
	Builtins: {[string]: boolean}?,
	Line: {string}?,
	Block: {{string}}?,
	Quotes: string?,
	Template: boolean?,
	Triple: boolean?,
	Prefixes: boolean?,
	Variables: boolean?,
	Flags: boolean?,
	Commands: boolean?,
	Cmdlets: boolean?,
	Types: boolean?,
	Decorators: boolean?,
	Preprocessor: boolean?,
	AtRules: boolean?,
	Hex: boolean?,
	Keys: string?,
	KeyStrings: boolean?,
	Sections: boolean?,
	Dash: boolean?,
	Caseless: boolean?,
	HashAfterSpace: boolean?,
}

const Syntax = {}

const function Set(Words: string): {[string]: boolean}
	const Found = {}

	for Word in Words:gmatch("%S+") do
		Found[Word] = true
	end

	return Found
end

const Script = "break case catch class const continue debugger default delete do else export extends finally for from function if import in instanceof let new of return static super switch this throw try typeof var void while with yield async await get set null undefined true false"
const ScriptBuiltins = Set("console process Math JSON Promise Object Array Buffer String Number Boolean Symbol Map Set WeakMap WeakSet Date RegExp Error TypeError RangeError require module exports window document globalThis setTimeout setInterval clearTimeout clearInterval fetch parseInt parseFloat isNaN structuredClone")

const Grammars: {[string]: Grammar} = {
	js = {
		Keywords = Set(Script),
		Builtins = ScriptBuiltins,
		Line = {"//"},
		Block = {
			{
				"/*",
				"*/",
			},
		},
		Quotes = "\"'`",
		Template = true,
		Decorators = true,
	},
	ts = {
		Keywords = Set(`{Script} interface type enum implements private public protected readonly as keyof namespace declare abstract is infer satisfies never unknown any string number boolean symbol bigint object`),
		Builtins = ScriptBuiltins,
		Line = {"//"},
		Block = {
			{
				"/*",
				"*/",
			},
		},
		Quotes = "\"'`",
		Template = true,
		Decorators = true,
	},
	python = {
		Keywords = Set("False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case self cls"),
		Builtins = Set("print len range str int float bool list dict set tuple open isinstance issubclass enumerate zip map filter sorted reversed sum min max abs any all input type super object getattr setattr hasattr repr format round Exception ValueError TypeError KeyError IndexError RuntimeError"),
		Line = {"#"},
		Quotes = "\"'",
		Triple = true,
		Prefixes = true,
		Decorators = true,
	},
	sh = {
		Keywords = Set("if then else elif fi for in do done while until case esac function return export local select break continue exit declare readonly unset shift source"),
		Line = {"#"},
		Quotes = "\"'`",
		Variables = true,
		Flags = true,
		Commands = true,
		HashAfterSpace = true,
	},
	powershell = {
		Keywords = Set("if else elseif foreach for while do until switch function param return break continue try catch finally throw begin process end filter class using in -eq -ne -gt -ge -lt -le -like -notlike -match -notmatch -contains -notcontains -in -notin -and -or -not -xor -is -isnot -replace -split -join $true $false $null"),
		Line = {"#"},
		Block = {
			{
				"<#",
				"#>",
			},
		},
		Quotes = "\"'",
		Variables = true,
		Flags = true,
		Cmdlets = true,
		Types = true,
		Caseless = true,
	},
	json = {
		Keywords = Set("true false null"),
		Line = {"//"},
		Block = {
			{
				"/*",
				"*/",
			},
		},
		Quotes = "\"",
		KeyStrings = true,
	},
	sql = {
		Keywords = Set("select from where insert into values update set delete create table alter drop join left right inner outer full cross on group by order having limit offset as and or not null is in like between distinct union all primary key foreign references index view begin commit rollback transaction case when then else end exists default unique check constraint if returning with asc desc true false"),
		Builtins = Set("count sum avg min max coalesce now lower upper cast length substr round date"),
		Line = {"--"},
		Block = {
			{
				"/*",
				"*/",
			},
		},
		Quotes = "'\"`",
		Caseless = true,
	},
	c = {
		Keywords = Set("if else for while do switch case default break continue return goto struct union enum typedef static const extern void int char float double long short unsigned signed bool true false null nullptr NULL class public private protected virtual override new delete this namespace using template typename try catch throw throws finally import package interface extends implements abstract final var val let fn func mut pub impl trait match loop use mod crate self Self super where async await go defer chan map select type range readonly sealed internal string object dynamic def auto inline constexpr noexcept operator friend volatile sizeof typeof instanceof synchronized assert yield record when is as in out ref params base get set event delegate partial unsafe fixed lock implicit explicit"),
		Builtins = Set("printf println print std cout cin cerr endl vector Console System Math String Integer List ArrayList HashMap Println Printf fmt len make append panic Some None Ok Err Box Vec Option Result"),
		Line = {"//"},
		Block = {
			{
				"/*",
				"*/",
			},
		},
		Quotes = "\"'`",
		Preprocessor = true,
		Decorators = true,
	},
	css = {
		Keywords = Set("!important important inherit initial unset none auto"),
		Block = {
			{
				"/*",
				"*/",
			},
		},
		Quotes = "\"'",
		AtRules = true,
		Hex = true,
		Keys = ":",
		Dash = true,
	},
	yaml = {
		Keywords = Set("true false null yes no on off True False Null TRUE FALSE ~"),
		Line = {"#"},
		Quotes = "\"'",
		Keys = ":",
		Dash = true,
		HashAfterSpace = true,
	},
	toml = {
		Keywords = Set("true false"),
		Line = {
			"#",
			";",
		},
		Quotes = "\"'",
		Keys = "=",
		Sections = true,
		Dash = true,
	},
}

const Aliases: {[string]: string} = {}

for Language, Names in ({
	luau = "lua luau rbxlua roblox",
	ts = "ts typescript tsx",
	js = "js javascript jsx mjs cjs node",
	python = "py python python3 py3",
	sh = "sh bash zsh shell console terminal shellscript shell-session cmd bat batch fish",
	powershell = "ps ps1 psm1 powershell pwsh",
	json = "json jsonc json5",
	html = "html htm xml svg xaml xhtml vue rbxmx",
	css = "css scss sass less",
	yaml = "yaml yml",
	toml = "toml ini cfg conf properties env dotenv editorconfig gitconfig",
	diff = "diff patch",
	sql = "sql sqlite mysql postgres postgresql psql",
	c = "c h cpp c++ cc cxx hpp cs csharp c# java kotlin kt go golang rust rs swift dart php scala",
	text = "text txt plaintext plain output log md markdown",
} :: {[string]: string}) do
	for Name in Names:gmatch("%S+") do
		Aliases[Name] = Language
	end
end

const function Escape(Text: string): string
	return (Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

const function Paint(Text: string, Colour: Color3): string
	if Text == "" then
		return ""
	end

	return `<font color="#{Colour:ToHex()}">{Escape(Text)}</font>`
end

local Tinted = ""

const function Signature(): string
	const Colours = Theme.Colors

	return table.concat({
		Colours.Code():ToHex(),
		Colours.CodeText():ToHex(),
		Colours.Keyword():ToHex(),
		Colours.Builtin():ToHex(),
		Colours.LuauType():ToHex(),
		Colours.String():ToHex(),
		Colours.Number():ToHex(),
		Colours.Comment():ToHex(),
		Colours.Operator():ToHex(),
	})
end

const function Luau(Code: string): string
	const Colours = Theme.Colors
	const Chosen = {
		background = Colours.Code(),
		iden = Colours.CodeText(),
		keyword = Colours.Keyword(),
		builtin = Colours.Builtin(),
		type = Colours.LuauType(),
		string = Colours.String(),
		number = Colours.Number(),
		comment = Colours.Comment(),
		operator = Colours.Operator(),
		custom = Colours.Keyword(),
	}
	const Current = Signature()

	if Current ~= Tinted then
		Tinted = Current
		Highlighter.setTokenColors(Chosen)
	end

	return table.concat(Highlighter.buildRichTextLines({
		src = Code,
		customLang = {const = "keyword"},
	}), "\n")
end

const Dark = {
	Keyword = Color3.fromRGB(86, 156, 214),
	String = Color3.fromRGB(206, 145, 120),
	Number = Color3.fromRGB(181, 206, 168),
	Comment = Color3.fromRGB(106, 153, 85),
	Call = Color3.fromRGB(220, 220, 170),
	Builtin = Color3.fromRGB(78, 201, 176),
	Variable = Color3.fromRGB(156, 220, 254),
	Operator = Color3.fromRGB(212, 212, 212),
	Added = Color3.fromRGB(129, 184, 139),
	Removed = Color3.fromRGB(244, 135, 113),
}

const Light = {
	Keyword = Color3.fromRGB(0, 0, 255),
	String = Color3.fromRGB(163, 21, 21),
	Number = Color3.fromRGB(9, 134, 88),
	Comment = Color3.fromRGB(0, 128, 0),
	Call = Color3.fromRGB(121, 94, 38),
	Builtin = Color3.fromRGB(38, 127, 153),
	Variable = Color3.fromRGB(0, 16, 128),
	Operator = Color3.fromRGB(0, 0, 0),
	Added = Color3.fromRGB(0, 128, 0),
	Removed = Color3.fromRGB(163, 21, 21),
}

function Syntax.Palette(): typeof(Dark)
	const Back = Theme.Colors.Code()

	return if 0.2126 * Back.R + 0.7152 * Back.G + 0.0722 * Back.B < 0.5 then Dark else Light
end

const function Closing(Code: string, At: number, Quote: string, Multi: boolean): number
	local Index = At + 1

	while Index <= #Code do
		const Character = Code:sub(Index, Index)

		if Character == "\\" then
			Index += 2

			continue
		end

		if Character == Quote then
			return Index
		end

		if Character == "\n" and not Multi then
			return Index - 1
		end

		Index += 1
	end

	return #Code
end

const function Tokens(Code: string, Rules: Grammar): string
	const Colours = Syntax.Palette()

	const function Template(Body: string, Rules: Grammar): string
		const Parts = {}
		local Index = 1
		local Literal = 1

		while Index <= #Body do
			if Body:sub(Index, Index) == "\\" then
				Index += 2

				continue
			end

			if Body:sub(Index, Index + 1) ~= "${" then
				Index += 1

				continue
			end

			local Depth = 0
			local Close: number?

			for Scan = Index + 1, #Body do
				const Character = Body:sub(Scan, Scan)

				if Character == "{" then
					Depth += 1
				elseif Character == "}" then
					Depth -= 1

					if Depth == 0 then
						Close = Scan

						break
					end
				end
			end

			if not Close then
				break
			end

			table.insert(Parts, Paint(Body:sub(Literal, Index - 1), Colours.String))
			table.insert(Parts, Paint("${", Colours.Operator))
			table.insert(Parts, Tokens(Body:sub(Index + 2, Close - 1), Rules))
			table.insert(Parts, Paint("}", Colours.Operator))
			Index = Close + 1
			Literal = Index
		end

		table.insert(Parts, Paint(Body:sub(Literal), Colours.String))

		return table.concat(Parts)
	end
	const Out = {}
	const Word = if Rules.Dash then "^[%a_][%w_%-]*" else "^[%a_][%w_]*"
	local At = 1
	local LineStart = 1
	local Command = true

	const function Push(Piece: string, Rendered: string)
		table.insert(Out, Rendered)

		const Last = Piece:match(".*()\n")

		if Last then
			LineStart = At + Last
			Command = true
		end

		At += #Piece
	end

	const function Tint(Piece: string, Colour: Color3?)
		Push(Piece, if Colour then Paint(Piece, Colour) else Escape(Piece))
	end

	const function Fresh(): boolean
		return Code:sub(LineStart, At - 1):match("^%s*$") ~= nil
	end

	while At <= #Code do
		const Character = Code:sub(At, At)
		const Before = Code:sub(At - 1, At - 1)
		local Comment: string?

		for _, Pair in (Rules.Block or {}) :: {{string}} do
			if Code:sub(At, At + #Pair[1] - 1) == Pair[1] then
				const Close = Code:find(Pair[2], At + #Pair[1], true)

				Comment = Code:sub(At, if Close then Close + #Pair[2] - 1 else #Code)

				break
			end
		end

		if not Comment then
			for _, Prefix in (Rules.Line or {}) :: {string} do
				if Code:sub(At, At + #Prefix - 1) == Prefix and (not Rules.HashAfterSpace or At == 1 or Before:match("[%s;|&(]")) then
					Comment = Code:match("^[^\n]*", At)

					break
				end
			end
		end

		if Comment then
			Tint(Comment, Colours.Comment)

			continue
		end

		if Character == "#" and Rules.Preprocessor and Fresh() then
			Tint(Code:match("^[^\n]*", At) :: string, Colours.Keyword)

			continue
		end

		if Character == "[" and ((Rules.Sections and Fresh() and Code:match("^%[[^\n%]]*%]", At)) or (Rules.Types and Code:match("^%[[%a_][%w_%.]*%]", At))) then
			Tint(Code:match("^%[[^\n%]]*%]", At) :: string, if Rules.Sections then Colours.Keyword else Colours.Builtin)

			continue
		end

		if Rules.Triple and (Code:sub(At, At + 2) == '"""' or Code:sub(At, At + 2) == "'''") then
			const Close = Code:find(Code:sub(At, At + 2), At + 3, true)

			Tint(Code:sub(At, if Close then Close + 2 else #Code), Colours.String)

			continue
		end

		if Rules.Quotes and Rules.Quotes:find(Character, 1, true) then
			const Body = Code:sub(At, Closing(Code, At, Character, Character == "`"))

			if Character == "`" and Rules.Template then
				Push(Body, Template(Body, Rules))
			else
				Tint(Body, if Rules.KeyStrings and Code:match("^%s*:", At + #Body) then Colours.Variable else Colours.String)
			end

			continue
		end

		if Character == "$" and Rules.Variables then
			const Name = Code:match("^%${[^}\n]*}", At) or Code:match("^%$[%a_][%w_]*:[%a_][%w_]*", At) or Code:match("^%$[%a_][%w_]*", At) or Code:match("^%$[%d#@%?%*!%$]", At)

			if Name then
				Tint(Name, if Rules.Keywords[Name:lower()] then Colours.Keyword else Colours.Variable)

				continue
			end
		end

		if Character == "@" and (Rules.Decorators or Rules.AtRules) then
			const Name = Code:match("^@[%a_][%w_%.%-]*", At)

			if Name then
				Tint(Name, if Rules.AtRules then Colours.Keyword else Colours.Builtin)

				continue
			end
		end

		if Character == "#" and Rules.Hex and Code:match("^#[%w_%-]+", At) then
			Tint(Code:match("^#[%w_%-]+", At) :: string, Colours.Number)

			continue
		end

		if (Character:match("%d") or (Character == "." and Code:sub(At + 1, At + 1):match("%d"))) and not Before:match("[%w_]") then
			const Number = Code:match("^0[xX][%x_]+[%w_]*", At)
				or Code:match("^0[bB][01_]+", At)
				or Code:match("^%d[%d_]*%.?[%d_]*[eE][%+%-]?%d+[%w_]*", At)
				or Code:match("^%d[%d_]*%.?[%d_]*[%a_]*", At)
				or Code:match("^%.%d[%d_]*[%a_]*", At)

			if Number then
				Tint(Number, Colours.Number)

				continue
			end
		end

		if Character == "-" and Rules.Flags and (At == 1 or Before:match("%s")) and Code:match("^%-%-?%a[%w%-_]*", At) then
			const Flag = Code:match("^%-%-?%a[%w%-_]*", At) :: string

			Tint(Flag, if Rules.Keywords[Flag:lower()] then Colours.Keyword else Colours.Builtin)

			continue
		end

		if Rules.Cmdlets and Code:match("^%u%a+%-%u%w+", At) and not Before:match("[%w_]") then
			Tint(Code:match("^%u%a+%-%u%w+", At) :: string, Colours.Call)
			Command = false

			continue
		end

		const Found = Code:match(Word, At)

		if Found then
			const Next = Code:sub(At + #Found, At + #Found)

			if Rules.Prefixes and #Found <= 2 and Found:lower():match("^[rbfu]+$") and (Next == '"' or Next == "'") then
				Tint(Code:sub(At, Closing(Code, At + #Found, Next, false)), Colours.String)

				continue
			end

			const Key = if Rules.Caseless then Found:lower() else Found
			local Colour: Color3?

			if Rules.Keys and Code:sub(LineStart, At - 1):match("^%s*%-?%s*$") and Code:match(`^%s*%{Rules.Keys}`, At + #Found) and not Code:match("^%s*::", At + #Found) then
				Colour = Colours.Variable
			elseif Before == "." or (Before == ":" and not Rules.Keys) then
				Colour = if Code:match("^%s*%(", At + #Found) then Colours.Call else nil
			elseif Rules.Keywords[Key] then
				Colour = Colours.Keyword
			elseif Rules.Builtins and Rules.Builtins[Key] then
				Colour = Colours.Builtin
			elseif (Rules.Commands and Command) or Code:match("^%s*%(", At + #Found) then
				Colour = Colours.Call
			end

			Tint(Found, Colour)
			Command = false

			continue
		end

		if Character:match("[%+%-%*/%%%^=~<>:%.,;%(%)%[%]{}|&!?#$\\]") then
			Tint(Character, Colours.Operator)

			if Rules.Commands and (Character == "|" or Character == ";" or Character == "&" or Character == "(") then
				Command = true
			end

			continue
		end

		Tint(Code:match("^%s+", At) or Code:match("^[\192-\255][\128-\191]*", At) or Character, nil)
	end

	return table.concat(Out)
end

const function Markup(Code: string): string
	const Colours = Syntax.Palette()
	const Out = {}
	local At = 1

	while At <= #Code do
		const Comment = Code:match("^<!%-%-.-%-%->", At) or (if Code:sub(At, At + 3) == "<!--" then Code:sub(At) else nil)

		if Comment then
			table.insert(Out, Paint(Comment, Colours.Comment))
			At += #Comment

			continue
		end

		const Declaration = Code:match("^<[!?][^>]*>?", At)

		if Declaration then
			table.insert(Out, Paint(Declaration, Colours.Keyword))
			At += #Declaration

			continue
		end

		const Opening, Name = Code:match("^(</?)([%w_:%-%.]+)", At)

		if Opening and Name then
			table.insert(Out, Paint(Opening, Colours.Operator))
			table.insert(Out, Paint(Name, Colours.Keyword))
			At += #Opening + #Name

			while At <= #Code do
				const Ending = Code:match("^/?>", At)

				if Ending then
					table.insert(Out, Paint(Ending, Colours.Operator))
					At += #Ending

					break
				end

				const Character = Code:sub(At, At)
				const Attribute = Code:match("^[%w_:%-%.@]+", At)

				if Attribute then
					table.insert(Out, Paint(Attribute, Colours.Variable))
					At += #Attribute
				elseif Character == '"' or Character == "'" then
					const Value = Code:sub(At, Closing(Code, At, Character, true))

					table.insert(Out, Paint(Value, Colours.String))
					At += #Value
				elseif Character == "=" then
					table.insert(Out, Paint(Character, Colours.Operator))
					At += 1
				elseif Character == "<" then
					break
				else
					table.insert(Out, Escape(Character))
					At += 1
				end
			end

			continue
		end

		const Entity = Code:match("^&#?%w+;", At)

		if Entity then
			table.insert(Out, Paint(Entity, Colours.Number))
			At += #Entity

			continue
		end

		const Text = Code:match("^[^<&]+", At) or Code:sub(At, At)

		table.insert(Out, Escape(Text))
		At += #Text
	end

	return table.concat(Out)
end

const function Diff(Code: string): string
	const Colours = Syntax.Palette()
	const Lines = {}

	for _, Line in string.split(Code, "\n") do
		const Colour = if Line:match("^%+%+%+") or Line:match("^%-%-%-") or Line:match("^diff ") or Line:match("^index ") then Colours.Keyword
			elseif Line:match("^@@") then Colours.Builtin
			elseif Line:sub(1, 1) == "+" then Colours.Added
			elseif Line:sub(1, 1) == "-" then Colours.Removed
			else nil

		table.insert(Lines, if Colour then Paint(Line, Colour) else Escape(Line))
	end

	return table.concat(Lines, "\n")
end

function Syntax.Language(Name: string?): string?
	return if Name then Aliases[Name:lower()] else nil
end

const Commands = Set("npm npx git cd ls mkdir rm cp mv curl wget pip pip3 python python3 node echo sudo apt brew cargo go export rojo wally aftman rokit yarn pnpm docker chmod cat grep claudio code tar ssh make cmake")

function Syntax.Guess(Text: string): string
	if Text:match("^%s*<[!%a]") then
		return "html"
	end

	if Text:match("^diff %-%-git") or Text:match("^@@ ") or Text:match("\n@@ ") then
		return "diff"
	end

	if Text:match("^%s*%[[%w_%.%-]+%]%s*\n") then
		return "toml"
	end

	if Text:match("^%s*{") or Text:match("^%s*%[") then
		return "json"
	end

	if Text:match("#include") or Text:match("public%s+static%s+void") or Text:match("%f[%w]fn%s+main%s*%(") or Text:match("%f[%w]func%s+main%s*%(") or Text:match("using%s+System") or Text:match("^package%s+%w+") then
		return "c"
	end

	if Text:match("%f[%w]def%s+[%w_]+%s*%(.-%)[^\n]*:%s*\n") or Text:match("^%s*from%s+[%w_%.]+%s+import%s") or Text:match("^%s*import%s+[%w_%.]+%s*\n") then
		return "python"
	end

	if Text:match("^%s*[Ss][Ee][Ll][Ee][Cc][Tt]%s") or Text:match("[Cc][Rr][Ee][Aa][Tt][Ee]%s+[Tt][Aa][Bb][Ll][Ee]") then
		return "sql"
	end

	if Text:match("%f[%w]local%f[%W]") or Text:match("%f[%w]end%f[%W]") or Text:match("%f[%w]then%f[%W]") or Text:match("game:GetService") then
		return "luau"
	end

	if Text:match("%f[%w]interface%s+%u") or Text:match(":%s*string[%s;,%)=]") or Text:match(":%s*number[%s;,%)=]") then
		return "ts"
	end

	if Text:match("=>") or Text:match("%f[%w]import%s.+%sfrom%s") or Text:match("console%.log") or (Text:match("%f[%w]const%s+[%w_]+%s*=") and Text:match(";")) or Text:match("%f[%w]function%s*[%w_]*%s*%(.-%)%s*{") then
		return "js"
	end

	if Text:match("%$[%w_]+%s*=") or Text:match("%f[%w]%u%l+%-%u%a+") then
		return "powershell"
	end

	if Text:match("^%s*%$ ") or Text:match("^#!") then
		return "sh"
	end

	for Line in (`{Text}\n`):gmatch("([^\n]*)\n") do
		const First = Line:match("^%s*([%w%-_%.]+)")

		if First and Commands[First] then
			return "sh"
		end
	end

	if Text:match("^%s*[%w_%.#%-:]+%s*{[^}]*[%w%-]+%s*:") then
		return "css"
	end

	if Text:match("^%s*[%w_%-]+:%s") and not Text:match("[{};]") then
		return "yaml"
	end

	return "text"
end

const Cached: {[string]: string} = {}
local Held = 0

function Syntax.Highlight(Code: string, Language: string?): string
	const Key = `{Language or "?"}|{Signature()}|{Code}`

	if Cached[Key] then
		return Cached[Key]
	end

	const Chosen = Language or Syntax.Guess(Code)

	const Built = if Chosen == "luau" then Luau(Code)
		elseif Chosen == "diff" then Diff(Code)
		elseif Chosen == "html" then Markup(Code)
		elseif Grammars[Chosen] then Tokens(Code, Grammars[Chosen])
		else Escape(Code)

	if Held > 200 then
		table.clear(Cached)
		Held = 0
	end

	Cached[Key] = Built
	Held += 1

	return Built
end

return Syntax