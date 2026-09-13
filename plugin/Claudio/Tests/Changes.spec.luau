--!nocheck
--!nolint UnknownGlobal
return function()
	const Changes = require(script.Parent.Parent.Changes)

	const function Call(Name: string, Input: string, Status: string?, Lines: any?)
		return {
			name = Name,
			input = Input,
			output = "",
			status = Status or "done",
			milliseconds = 0,
			lines = Lines,
		}
	end

	describe("For", function()
		it("carries watcher changes through with their counts", function()
			const Found = Changes.For({
				Role = "assistant",
				Text = "",
				Edits = {{Kind = "changed", Text = "Edited ServerScriptService.Main", Path = "ServerScriptService.Main", Added = 3, Removed = 1}},
			} :: any)

			expect(#Found).to.equal(1)
			expect(Found[1].Added).to.equal(3)
			expect(Found[1].Removed).to.equal(1)
		end)

		it("adds a file write with the lines the bridge counted", function()
			const Found = Changes.For({
				Role = "assistant",
				Text = "",
				Edits = {},
				Calls = {Call("Write", "file_path: C:/Repo/src/Thing.js", "done", {added = 21, removed = 0})},
			} :: any)

			expect(#Found).to.equal(1)
			expect(Found[1].Path).to.equal("C:/Repo/src/Thing.js")
			expect(Found[1].Added).to.equal(21)
		end)

		it("skips a write that failed", function()
			const Found = Changes.For({
				Role = "assistant",
				Text = "",
				Edits = {},
				Calls = {Call("Write", "file_path: C:/Repo/x.js", "error")},
			} :: any)

			expect(#Found).to.equal(0)
		end)

		it("does not list the same change twice", function()
			const Found = Changes.For({
				Role = "assistant",
				Text = "",
				Edits = {
					{Kind = "changed", Text = "Edited Workspace.Part", Path = "Workspace.Part"},
					{Kind = "changed", Text = "Edited Workspace.Part", Path = "Workspace.Part"},
				},
			} :: any)

			expect(#Found).to.equal(1)
		end)
	end)

	describe("Describe", function()
		it("reads a modify call as the past tense of its action", function()
			const Found = Changes.Describe({Call("mcp__claudio__modify", "action: create\nparentPath: Workspace\nclassName: Part")})

			expect(#Found).to.equal(1)
			expect(Found[1].Kind).to.equal("added")
		end)
	end)
end