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

	describe("Field", function()
		it("reads one key from lines of key colon value", function()
			expect(Changes.Field("action: create\nname: Part\nparent: Workspace", "name")).to.equal("Part")
			expect(Changes.Field("action: create", "name")).to.equal(nil)
			expect(Changes.Field("", "name")).to.equal(nil)
		end)

		it("does not match a key that only starts the same", function()
			expect(Changes.Field("parentPath: Workspace", "parent")).to.equal(nil)
		end)
	end)

	describe("Describe", function()
		it("names a created instance by its parent and its own name", function()
			const Found = Changes.Describe({Call("mcp__claudio__modify", "action: create\nclassName: Folder\nname: Loot\nparent: ServerStorage")})

			expect(#Found).to.equal(1)
			expect(Found[1].Kind).to.equal("added")
			expect(Found[1].Path).to.equal("ServerStorage.Loot")
			expect(Found[1].Text).to.equal("Created ServerStorage.Loot")
		end)

		it("marks a deletion as removed", function()
			const Found = Changes.Describe({Call("mcp__claudio__modify", "action: delete\npath: Workspace.Old")})

			expect(Found[1].Kind).to.equal("removed")
			expect(Found[1].Text).to.equal("Deleted Workspace.Old")
		end)

		it("calls a rename and a move a change", function()
			expect(Changes.Describe({Call("mcp__claudio__modify", "action: rename\npath: Workspace.A\nname: B")})[1].Text).to.equal("Renamed Workspace.A")
			expect(Changes.Describe({Call("mcp__claudio__modify", "action: move\npath: Workspace.A\nparent: Lighting")})[1].Kind).to.equal("changed")
		end)

		it("knows a source edit from a read", function()
			expect(#Changes.Describe({Call("mcp__claudio__source", "action: get\npath: ServerScriptService.Main")})).to.equal(0)

			const Found = Changes.Describe({Call("mcp__claudio__source", "action: set\npath: ServerScriptService.Main\ntext: print(1)")})

			expect(Found[1].Text).to.equal("Edited ServerScriptService.Main")
			expect(Found[1].Path).to.equal("ServerScriptService.Main")
		end)

		it("strips the game prefix from a path", function()
			expect(Changes.Describe({Call("mcp__claudio__modify", "action: delete\npath: game.Workspace.Old")})[1].Text).to.equal("Deleted Workspace.Old")
		end)

		it("reads a loaded rbxm as an addition and a saved one as nothing", function()
			expect(Changes.Describe({Call("mcp__claudio__rbxm", "file: C:/a.rbxm\npath: Workspace")})[1].Kind).to.equal("added")
			expect(#Changes.Describe({Call("mcp__claudio__rbxm", "file: C:/a.rbxm\npaths: [\"Workspace.Part\"]")})).to.equal(0)
		end)

		it("ignores calls that only look", function()
			expect(#Changes.Describe({Call("mcp__claudio__find", "search: Part"), Call("mcp__claudio__capture", "of: viewport"), Call("Read", "file_path: C:/x")})).to.equal(0)
		end)

		it("skips a call that failed and lists a change once", function()
			const Found = Changes.Describe({
				Call("mcp__claudio__modify", "action: delete\npath: Workspace.Old", "error"),
				Call("mcp__claudio__modify", "action: delete\npath: Workspace.Gone"),
				Call("mcp__claudio__modify", "action: delete\npath: Workspace.Gone"),
			})

			expect(#Found).to.equal(1)
			expect(Found[1].Text).to.equal("Deleted Workspace.Gone")
		end)

		it("copes with a call that has no calls at all", function()
			expect(#Changes.Describe(nil)).to.equal(0)
		end)
	end)

	describe("For", function()
		it("falls back to describing the calls when the watcher recorded nothing", function()
			const Found = Changes.For({
				Role = "assistant",
				Text = "",
				Calls = {Call("mcp__claudio__modify", "action: create\nclassName: Part\nname: Floor\nparent: Workspace")},
			} :: any)

			expect(#Found).to.equal(1)
			expect(Found[1].Path).to.equal("Workspace.Floor")
		end)

		it("keeps a plain string edit as a change with that text", function()
			const Found = Changes.For({
				Role = "assistant",
				Text = "",
				Edits = {"Moved the camera"},
			} :: any)

			expect(Found[1].Kind).to.equal("changed")
			expect(Found[1].Text).to.equal("Moved the camera")
		end)

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