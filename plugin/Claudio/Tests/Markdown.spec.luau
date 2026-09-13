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

		it("does not produce an empty piece between two fences", function()
			const Pieces = Markdown.Split("```\na\n```\n```\nb\n```")

			expect(#Pieces).to.equal(2)
			expect(Pieces[1].Text).to.equal("a")
			expect(Pieces[2].Text).to.equal("b")
		end)
	end)
end