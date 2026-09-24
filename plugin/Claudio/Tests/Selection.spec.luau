--!nocheck
--!nolint UnknownGlobal
return function()
	const CoreGui = game:GetService("CoreGui")
	const TextService = game:GetService("TextService")

	const Selection = require(script.Parent.Parent.Store.Selection)
	const Covers = require(script.Parent.Parent.App.Covers)
	const Vide = require(script.Parent.Parent.Packages.vide)
	const Keys = require(script.Parent.Parent.Store.Keys)

	local Screen: ScreenGui

	beforeEach(function()
		Screen = Instance.new("ScreenGui")
		Screen.Name = "ClaudioSpecScreen"
		Screen.Parent = CoreGui
	end)

	afterEach(function()
		Screen:Destroy()
	end)

	const function Box(Text: string, Width: number): TextBox
		const Made = Instance.new("TextBox")

		Made.Font = Enum.Font.Code
		Made.TextSize = 14
		Made.TextWrapped = true
		Made.Text = Text
		Made.Position = UDim2.fromOffset(20, 30)
		Made.Size = UDim2.fromOffset(Width, 200)
		Made.Parent = Screen
		task.wait()

		return Made
	end

	const function Frame(X: number, Y: number, Width: number, Height: number, Parent: Instance?): Frame
		const Made = Instance.new("Frame")

		Made.Position = UDim2.fromOffset(X, Y)
		Made.Size = UDim2.fromOffset(Width, Height)
		Made.Parent = Parent or Screen

		return Made
	end

	describe("IndexAt", function()
		it("finds the caret before the first character and after the last", function()
			const Made = Box("hello world", 400)
			const Corner = Made.AbsolutePosition

			expect(Selection.IndexAt(Made, Corner + Vector2.new(0, 5))).to.equal(1)
			expect(Selection.IndexAt(Made, Corner + Vector2.new(390, 5))).to.equal(12)
		end)

		it("rounds to the nearer side of the character under the pointer", function()
			const Made = Box("abcdefgh", 400)
			const Wide = TextService:GetTextSize("a", 14, Enum.Font.Code, Vector2.new(1e5, 1e5)).X
			const Corner = Made.AbsolutePosition

			expect(Selection.IndexAt(Made, Corner + Vector2.new(Wide * 3.2, 5))).to.equal(4)
			expect(Selection.IndexAt(Made, Corner + Vector2.new(Wide * 3.8, 5))).to.equal(5)
		end)

		it("moves to the next line on a newline", function()
			const Made = Box("ab\ncd", 400)
			const Tall = TextService:GetTextSize("Ag", 14, Enum.Font.Code, Vector2.new(1e5, 1e5)).Y

			expect(Selection.IndexAt(Made, Made.AbsolutePosition + Vector2.new(0, Tall * 1.5))).to.equal(4)
		end)

		it("follows word wrapping onto the next line", function()
			const Wide = TextService:GetTextSize("hello ", 14, Enum.Font.Code, Vector2.new(1e5, 1e5)).X
			const Made = Box("hello world", Wide + 4)
			const Tall = TextService:GetTextSize("Ag", 14, Enum.Font.Code, Vector2.new(1e5, 1e5)).Y

			expect(Selection.IndexAt(Made, Made.AbsolutePosition + Vector2.new(0, Tall * 1.5))).to.equal(7)
		end)
	end)

	describe("Covers", function()
		it("counts a point under an open cover, but not beside it or for the cover's own contents", function()
			const Behind = Frame(0, 0, 300, 300)
			const Cover = Frame(50, 50, 100, 100)
			const Inside = Frame(10, 10, 20, 20, Cover)

			Vide.root(function()
				Covers.Add(Cover)
			end)
			task.wait()

			expect(Covers.Over(Behind, 60, 60)).to.equal(true)
			expect(Covers.Over(Behind, 10, 10)).to.equal(false)
			expect(Covers.Over(Inside, 60, 60)).to.equal(false)
		end)

		it("ignores a hidden cover and forgets a destroyed one", function()
			const Behind = Frame(0, 0, 300, 300)
			const Cover = Frame(50, 50, 100, 100)

			Vide.root(function()
				Covers.Add(Cover)
			end)
			Cover.Visible = false
			task.wait()

			expect(Covers.Over(Behind, 60, 60)).to.equal(false)

			Cover.Visible = true
			Cover:Destroy()

			expect(Covers.Over(Behind, 60, 60)).to.equal(false)
		end)
	end)

	describe("Clean", function()
		it("strips rich text tags and decodes every entity once", function()
			expect(Keys.Clean('<font color="#fff">a &lt;b&gt;</font> &quot;c&quot; &apos;d&apos; &amp;lt;')).to.equal("a <b> \"c\" 'd' &lt;")
		end)
	end)
end