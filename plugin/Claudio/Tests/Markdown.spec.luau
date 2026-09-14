--!nocheck
--!nolint UnknownGlobal
return function()
	const Markdown = require(script.Parent.Parent.Markdown)

	describe("Split", function()
		it("keeps prose and fenced code apart in order", function()
			const Pieces = Markdown.Split("before\n```lua\nprint(1)\n```\nafter")

			expect(#Pieces).to.equal(3)
			expect(Pieces[1].Kind).to.equal("text")
			expect(Pieces[1].Text).to.equal("before")
			expect(Pieces[2].Kind).to.equal("code")
			expect(Pieces[2].Text).to.equal("print(1)")
			expect(Pieces[3].Kind).to.equal("text")
			expect(Pieces[3].Text).to.equal("after")
		end)

		it("returns one text piece for plain prose", function()
			const Pieces = Markdown.Split("just words")

			expect(#Pieces).to.equal(1)
			expect(Pieces[1].Kind).to.equal("text")
		end)

		it("keeps the language written after the fence", function()
			const Pieces = Markdown.Split("```json\n{}\n```")

			expect(Pieces[1].Language).to.equal("json")
			expect(Markdown.Split("```\nx\n```")[1].Language).to.equal(nil)
		end)

		it("treats an unclosed fence as prose", function()
			const Pieces = Markdown.Split("start\n```lua\nprint(1)")

			expect(#Pieces).to.equal(1)
			expect(Pieces[1].Kind).to.equal("text")
		end)

		it("trims trailing blank lines off a fence but keeps indentation", function()
			const Pieces = Markdown.Split("```\n\tindented\n\n\n```")

			expect(Pieces[1].Text).to.equal("\tindented")
		end)

		it("numbers pieces in order so they can be keyed", function()
			const Pieces = Markdown.Split("a\n```\nb\n```\nc")

			expect(Pieces[1].Order).to.equal(1)
			expect(Pieces[2].Order).to.equal(2)
			expect(Pieces[3].Order).to.equal(3)
		end)

		it("does not produce an empty piece between two fences", function()
			const Pieces = Markdown.Split("```\na\n```\n```\nb\n```")

			expect(#Pieces).to.equal(2)
			expect(Pieces[1].Text).to.equal("a")
			expect(Pieces[2].Text).to.equal("b")
		end)
	end)

	describe("Build", function()
		it("escapes rich text characters before adding its own tags", function()
			expect(Markdown.Build("a < b & c > d")).to.equal("a &lt; b &amp; c &gt; d")
		end)

		it("turns bold, italic and underscores into tags", function()
			expect(Markdown.Build("**bold** and *soft* and _low_")).to.equal("<b>bold</b> and <i>soft</i> and <i>low</i>")
		end)

		it("leaves an underscore inside a word alone", function()
			expect(Markdown.Build("snake_case_name")).to.equal("snake_case_name")
		end)

		it("makes headings bold and larger only when a size is given", function()
			expect(Markdown.Build("# Title")).to.equal("<b>Title</b>")
			expect(Markdown.Build("# Title", 14)).to.equal('<font size="18"><b>Title</b></font>')
			expect(Markdown.Build("## Sub", 14)).to.equal('<font size="16"><b>Sub</b></font>')
			expect(Markdown.Build("### Small", 14)).to.equal("<b>Small</b>")
		end)

		it("turns list markers into bullets and keeps their indent", function()
			expect(Markdown.Build("- one\n  * two")).to.equal("• one\n  • two")
		end)
	end)

	describe("Rich", function()
		it("gives the same answer as Build and remembers it", function()
			expect(Markdown.Rich("**x**", 14)).to.equal(Markdown.Build("**x**", 14))
			expect(Markdown.Rich("**x**", 14)).to.equal("<b>x</b>")
		end)
	end)
end