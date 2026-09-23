--!nocheck
--!nolint UnknownGlobal
return function()
	const Attention = require(script.Parent.Parent.App.Attention)

	describe("Closing", function()
		it("uses the last paragraph rather than the first", function()
			expect(Attention.Closing("Looking into it now.\n\nRead three files.\n\nAll four parts are done and installed.")).to.equal("All four parts are done and installed.")
		end)

		it("skips a trailing code block and strips markdown", function()
			expect(Attention.Closing("Start.\n\nFixed **the bug** in [Chat.luau](plugin/Chat.luau).\n\n```bash\nnpm test\n```\n")).to.equal("Fixed the bug in Chat.luau.")
		end)

		it("keeps whole closing sentences that fit in 200 characters", function()
			expect(Attention.Closing(`{string.rep("word ", 40)}ends here. Then a second sentence. And the last one.`)).to.equal("Then a second sentence. And the last one.")
		end)

		it("does not split a sentence at a dot inside a name", function()
			expect(Attention.Closing(`{string.rep("word ", 40)}ends here. Fixed Chat.luau in v1.2 today.`)).to.equal("Fixed Chat.luau in v1.2 today.")
		end)

		it("cuts from the front when one sentence is too long", function()
			const Result = Attention.Closing(string.rep("a", 300))

			expect(#Result).to.equal(200)
			expect(Result:sub(1, 3)).to.equal("...")
		end)
	end)
end