--!nocheck
--!nolint UnknownGlobal
return function()
	const Syntax = require(script.Parent.Parent.Syntax)
	const Theme = require(script.Parent.Parent.App.Theme)

	beforeAll(function()
		Theme.Init()
	end)

	afterAll(function()
		Theme.Destroy()
	end)

	const function Decode(Text: string): string
		return (Text:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&"))
	end

	const function Plain(Rich: string): string
		return Decode((Rich:gsub("<[^>]->", "")))
	end

	const function ColourOf(Rich: string, Piece: string): string?
		for Colour, Body in Rich:gmatch('<font color="#(%x+)">(.-)</font>') do
			if Decode(Body):match("^%s*(.-)%s*$") == Piece then
				return Colour:lower()
			end
		end

		return nil
	end

	const function Hex(Name: string): string
		return Theme.Colors[Name]():ToHex():lower()
	end

	const function Tone(Name: string): string
		return (Syntax.Palette() :: any)[Name]:ToHex():lower()
	end

	describe("Language", function()
		it("maps common fence names onto the languages it knows", function()
			expect(Syntax.Language("lua")).to.equal("luau")
			expect(Syntax.Language("Luau")).to.equal("luau")
			expect(Syntax.Language("typescript")).to.equal("ts")
			expect(Syntax.Language("tsx")).to.equal("ts")
			expect(Syntax.Language("javascript")).to.equal("js")
			expect(Syntax.Language("bash")).to.equal("sh")
			expect(Syntax.Language("powershell")).to.equal("powershell")
			expect(Syntax.Language("python")).to.equal("python")
			expect(Syntax.Language("json")).to.equal("json")
			expect(Syntax.Language("rust")).to.equal("c")
			expect(Syntax.Language("yml")).to.equal("yaml")
			expect(Syntax.Language("xml")).to.equal("html")
			expect(Syntax.Language("patch")).to.equal("diff")
		end)

		it("gives nothing for a fence it does not know or no fence", function()
			expect(Syntax.Language("brainfuck")).to.equal(nil)
			expect(Syntax.Language(nil)).to.equal(nil)
		end)
	end)

	describe("Guess", function()
		it("sees json from the opening bracket", function()
			expect(Syntax.Guess('{"a": 1}')).to.equal("json")
			expect(Syntax.Guess("  [1, 2]")).to.equal("json")
		end)

		it("sees javascript from const plus semicolons or arrows", function()
			expect(Syntax.Guess("const X = 1;\nconst Y = 2;\n")).to.equal("js")
			expect(Syntax.Guess("const Go = () => 1")).to.equal("js")
		end)

		it("sees luau from its keywords", function()
			expect(Syntax.Guess("local X = 1")).to.equal("luau")
			expect(Syntax.Guess("if A then\n\tB()\nend")).to.equal("luau")
			expect(Syntax.Guess('game:GetService("Players")')).to.equal("luau")
		end)

		it("sees a shell line from a prompt or a known command", function()
			expect(Syntax.Guess("$ ls -la")).to.equal("sh")
			expect(Syntax.Guess("git log --oneline")).to.equal("sh")
		end)

		it("sees the other common languages", function()
			expect(Syntax.Guess("def Main(X):\n    return X\n")).to.equal("python")
			expect(Syntax.Guess('<div class="a">b</div>')).to.equal("html")
			expect(Syntax.Guess("@@ -1 +1 @@\n-a\n+b")).to.equal("diff")
			expect(Syntax.Guess("$Name = Get-ChildItem")).to.equal("powershell")
			expect(Syntax.Guess("SELECT * FROM Users")).to.equal("sql")
			expect(Syntax.Guess("interface Point {\n  X: number;\n}")).to.equal("ts")
		end)

		it("leaves prose as plain text", function()
			expect(Syntax.Guess("hello")).to.equal("text")
		end)
	end)

	describe("Highlight", function()
		it("keeps every character of the code once the tags are stripped, in every language", function()
			const Samples = {
				luau = 'local Part = Instance.new("Part") -- 5 < 6 & a > b\nPart.Parent = workspace\nprint(`a {1 + 2} b`, [==[x]]y]==])',
				js = "const A = `x ${B + `y`} z`; // < & >\nlet C = 1e-5 - .5;",
				ts = "interface P { X: number }\nconst Q: P = {X: 0x1F};",
				python = 'def F(X):\n    """doc < >"""\n    return f"{X}" # note\n',
				sh = 'export A="b & c"\nls -la | grep "x" # tail\necho $HOME ${A}',
				powershell = '$Files = Get-ChildItem -Path "C:\\" | Where-Object { $_.Length -gt 10 }',
				json = '{"a": [1, true, null], "b": "c<d"}',
				sql = "SELECT Name, COUNT(*) FROM Users WHERE Age > 5 -- x",
				c = '#include <stdio.h>\nint main() { printf("%d\\n", 1 < 2); }',
				css = ".a:hover {\n  color: #fff !important;\n  margin: 1.5rem;\n}",
				yaml = "name: Build\non:\n  push: true # x",
				toml = '[package]\nname = "x"\nversion = 1',
				diff = "@@ -1 +1 @@\n-old < a\n+new > b",
				html = '<!-- c --><a href="x&amp;y">B &lt; C</a>',
				text = "just < words & more",
			}

			for Language, Code in Samples do
				expect(`{Language}: {Plain(Syntax.Highlight(Code, Language))}`).to.equal(`{Language}: {Code}`)
			end
		end)

		it("escapes the characters rich text would otherwise read", function()
			const Rich = Syntax.Highlight("if a < b and c > d then end", "luau")

			expect(Rich:find("<b", 1, true)).to.equal(nil)
			expect(Rich:find("&lt;", 1, true)).never.to.equal(nil)
			expect(Rich:find("&gt;", 1, true)).never.to.equal(nil)
		end)

		it("colours a luau keyword, string, number and comment in Studio's colours", function()
			const Rich = Syntax.Highlight('local Thing = "x" .. 5 -- note', "luau")

			expect(ColourOf(Rich, "local")).to.equal(Hex("Keyword"))
			expect(ColourOf(Rich, '"x"')).to.equal(Hex("String"))
			expect(ColourOf(Rich, "5")).to.equal(Hex("Number"))
			expect(ColourOf(Rich, "-- note")).to.equal(Hex("Comment"))
			expect(ColourOf(Rich, "Thing")).never.to.equal(Hex("Keyword"))
		end)

		it("keeps a keyword inside a string as part of the string", function()
			const Rich = Syntax.Highlight('print("local end")', "luau")

			expect(ColourOf(Rich, '"local end"')).to.equal(Hex("String"))
			expect(ColourOf(Rich, "local")).to.equal(nil)
		end)

		it("reads luau long brackets with levels and library members", function()
			const Rich = Syntax.Highlight("local S = [==[a]]b]==] print(math.floor(1))", "luau")

			expect(ColourOf(Rich, "[==[a]]b]==]")).to.equal(Hex("String"))
			expect(ColourOf(Rich, "floor")).to.equal(Hex("Builtin"))
		end)

		it("does not read the digits inside a name as a number", function()
			const Rich = Syntax.Highlight("Part2 = 2", "js")

			expect(ColourOf(Rich, "2")).to.equal(Tone("Number"))
			expect(ColourOf(Rich, "Part2")).to.equal(nil)
		end)

		it("does not join a subtraction into one number", function()
			const Rich = Syntax.Highlight("X = 1-2", "js")

			expect(ColourOf(Rich, "1")).to.equal(Tone("Number"))
			expect(ColourOf(Rich, "2")).to.equal(Tone("Number"))
			expect(ColourOf(Rich, "1-2")).to.equal(nil)
		end)

		it("uses each language's own comment shape", function()
			expect(ColourOf(Syntax.Highlight("// note\nconst X = 1;", "js"), "// note")).to.equal(Tone("Comment"))
			expect(ColourOf(Syntax.Highlight("# note\nls", "sh"), "# note")).to.equal(Tone("Comment"))
			expect(ColourOf(Syntax.Highlight("# note", "python"), "# note")).to.equal(Tone("Comment"))
			expect(ColourOf(Syntax.Highlight("<# a #>", "powershell"), "<# a #>")).to.equal(Tone("Comment"))
			expect(ColourOf(Syntax.Highlight("-- note", "js"), "-- note")).to.equal(nil)
		end)

		it("keeps an escaped quote inside its string", function()
			expect(ColourOf(Syntax.Highlight('X = "a\\"b"', "js"), '"a\\"b"')).to.equal(Tone("String"))
		end)

		it("paints the expression inside a template string as code", function()
			const Rich = Syntax.Highlight("`a ${Count + 1} b`", "js")

			expect(ColourOf(Rich, "`a")).to.equal(Tone("String"))
			expect(ColourOf(Rich, "1")).to.equal(Tone("Number"))
		end)

		it("treats a python triple quoted string as one string", function()
			expect(ColourOf(Syntax.Highlight('X = """a\ndef b"""', "python"), '"""a\ndef b"""')).to.equal(Tone("String"))
		end)

		it("paints a shell command, flag and variable", function()
			const Rich = Syntax.Highlight("git log --oneline $HOME", "sh")

			expect(ColourOf(Rich, "git")).to.equal(Tone("Call"))
			expect(ColourOf(Rich, "--oneline")).to.equal(Tone("Builtin"))
			expect(ColourOf(Rich, "$HOME")).to.equal(Tone("Variable"))
			expect(ColourOf(Rich, "log")).to.equal(nil)
		end)

		it("paints a json key apart from a string value", function()
			const Rich = Syntax.Highlight('{"Name": "Value"}', "json")

			expect(ColourOf(Rich, '"Name"')).to.equal(Tone("Variable"))
			expect(ColourOf(Rich, '"Value"')).to.equal(Tone("String"))
		end)

		it("paints added and removed diff lines", function()
			const Rich = Syntax.Highlight("+new\n-old\n same", "diff")

			expect(ColourOf(Rich, "+new")).to.equal(Tone("Added"))
			expect(ColourOf(Rich, "-old")).to.equal(Tone("Removed"))
		end)

		it("paints a markup tag and attribute", function()
			const Rich = Syntax.Highlight('<a href="x">y</a>', "html")

			expect(ColourOf(Rich, "a")).to.equal(Tone("Keyword"))
			expect(ColourOf(Rich, "href")).to.equal(Tone("Variable"))
			expect(ColourOf(Rich, '"x"')).to.equal(Tone("String"))
		end)

		it("paints a call but not a field of the same name", function()
			expect(ColourOf(Syntax.Highlight("Build()", "js"), "Build")).to.equal(Tone("Call"))
			expect(ColourOf(Syntax.Highlight("Thing.Build = 1", "js"), "Build")).to.equal(nil)
		end)

		it("never paints another language in Luau's colours", function()
			const Luau = Syntax.Highlight("local X = 1 -- c", "luau")
			const Script = Syntax.Highlight('const X = "a"; // c', "js")

			expect(ColourOf(Script, "const")).never.to.equal(ColourOf(Luau, "local"))
			expect(ColourOf(Script, "// c")).never.to.equal(ColourOf(Luau, "-- c"))
			expect(ColourOf(Script, '"a"')).never.to.equal(Hex("String"))
		end)

		it("survives an empty string and one lone symbol", function()
			expect(Syntax.Highlight("", "luau")).to.equal("")
			expect(Plain(Syntax.Highlight("@", "luau"))).to.equal("@")
			expect(Plain(Syntax.Highlight("@", "js"))).to.equal("@")
		end)
	end)
end