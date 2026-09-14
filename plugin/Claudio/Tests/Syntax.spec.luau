--!nocheck
--!nolint UnknownGlobal
return function()
	const Syntax = require(script.Parent.Parent.Syntax)

	const function Plain(Rich: string): string
		return (Rich:gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
	end

	describe("Language", function()
		it("maps fence names onto the four it knows", function()
			expect(Syntax.Language("lua")).to.equal("luau")
			expect(Syntax.Language("Luau")).to.equal("luau")
			expect(Syntax.Language("typescript")).to.equal("js")
			expect(Syntax.Language("bash")).to.equal("sh")
			expect(Syntax.Language("powershell")).to.equal("sh")
			expect(Syntax.Language("json")).to.equal("json")
		end)

		it("gives nothing for a fence it does not know or no fence", function()
			expect(Syntax.Language("python")).to.equal(nil)
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

		it("sees a shell line from a prompt or a flag", function()
			expect(Syntax.Guess("$ ls -la")).to.equal("sh")
			expect(Syntax.Guess("git log --oneline")).to.equal("sh")
		end)

		it("falls back to luau", function()
			expect(Syntax.Guess("hello")).to.equal("luau")
		end)
	end)

	describe("Highlight", function()
		it("keeps every character of the code once the tags are stripped", function()
			const Code = 'local Part = Instance.new("Part") -- 5 < 6 & a > b\nPart.Parent = workspace'

			expect(Plain(Syntax.Highlight(Code, "luau"))).to.equal(Code)
		end)

		it("escapes the characters rich text would otherwise read", function()
			const Rich = Syntax.Highlight("if a < b and c > d then end", "luau")

			expect(Rich:find("<b", 1, true)).to.equal(nil)
			expect(Rich:find("&lt;", 1, true)).never.to.equal(nil)
			expect(Rich:find("&gt;", 1, true)).never.to.equal(nil)
		end)

		it("wraps a keyword in a font tag and leaves a plain name bare", function()
			const Rich = Syntax.Highlight("local Thing = Other", "luau")

			expect(Rich:match('<font color="#%x+">local</font>')).never.to.equal(nil)
			expect(Rich:find(">Thing<", 1, true)).to.equal(nil)
			expect(Rich:find("Thing", 1, true)).never.to.equal(nil)
		end)

		it("keeps a keyword inside a string as part of the string", function()
			const Rich = Syntax.Highlight('print("local end")', "luau")

			expect(Rich:match('<font color="#%x+">"local end"</font>')).never.to.equal(nil)
			expect(Rich:match('<font color="#%x+">local</font>')).to.equal(nil)
		end)

		it("keeps a whole comment together", function()
			const Rich = Syntax.Highlight("-- if this then that\nlocal X = 1", "luau")

			expect(Rich:match('<font color="#%x+">%-%- if this then that</font>')).never.to.equal(nil)
		end)

		it("does not read the digits inside a name as a number", function()
			const Rich = Syntax.Highlight("Part2 = 2", "luau")
			const Painted = {}

			for Body in Rich:gmatch('<font color="#%x+">(.-)</font>') do
				table.insert(Painted, Body)
			end

			expect(table.find(Painted, "2")).never.to.equal(nil)
			expect(table.find(Painted, "Part2")).to.equal(nil)
		end)

		it("uses each language's own comment shape", function()
			expect(Syntax.Highlight("// note\nconst X = 1;", "js"):match('<font color="#%x+">// note</font>')).never.to.equal(nil)
			expect(Syntax.Highlight("# note\nls", "sh"):match('<font color="#%x+"># note</font>')).never.to.equal(nil)
			expect(Syntax.Highlight("-- note", "js"):match('<font color="#%x+">%-%- note</font>')).to.equal(nil)
		end)

		it("paints a call but not a field of the same name", function()
			const Called = Syntax.Highlight("Build()", "luau")
			const Field = Syntax.Highlight("Thing.Build = 1", "luau")

			expect(Called:match('<font color="#%x+">Build</font>')).never.to.equal(nil)
			expect(Field:match('<font color="#%x+">Build</font>')).to.equal(nil)
		end)

		it("survives an empty string and one lone symbol", function()
			expect(Syntax.Highlight("", "luau")).to.equal("")
			expect(Plain(Syntax.Highlight("@", "luau"))).to.equal("@")
		end)
	end)
end