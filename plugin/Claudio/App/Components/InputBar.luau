--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Markdown = require(script.Parent.Parent.Parent.Markdown)
const Format = require(script.Parent.Parent.Parent.Format)
const Keys = require(script.Parent.Parent.Parent.Store.Keys)
const Theme = require(script.Parent.Parent.Theme)
const IconButton = require(script.Parent.IconButton)
const Attachments = require(script.Parent.Attachments)
const AddMenu = require(script.Parent.AddMenu)
const CommandSuggestions = require(script.Parent.CommandSuggestions)
const MentionSuggestions = require(script.Parent.MentionSuggestions)
const ModelPicker = require(script.Parent.ModelPicker)
const UsageRing = require(script.Parent.UsageRing)

const Create = Vide.create

const TextService = game:GetService("TextService")

return function()
	const Line = 18

	local Box: TextBox
	local Field: ScrollingFrame
	local Marker = ""

	const AddOpen = Vide.source(false)
	const Wide = Vide.source(0)
	const Tall = Vide.source(Line)

	local Token = 0

	const function Fit()
		Token += 1

		const Mine = Token
		const Width = Wide()
		const Draft = Chat.Draft()
		const Size = Settings.TextSize()

		if Width <= 0 then
			return
		end

		if Draft == "" then
			Tall(Line)

			return
		end

		task.spawn(function()
			const Params = Instance.new("GetTextBoundsParams")

			Params.Text = Draft
			Params.Font = Font.fromEnum(Enum.Font.BuilderSans)
			Params.Size = Size
			Params.Width = Width

			const Ok, Bounds = pcall(function()
				return TextService:GetTextBoundsAsync(Params)
			end)

			if Ok and Token == Mine then
				Tall(math.max(Bounds.Y, Line))
			end
		end)
	end

	Vide.effect(Fit)

	const function Follow()
		if Field and Box and Box.CursorPosition >= #Box.Text then
			Field.CanvasPosition = Vector2.new(0, Field.AbsoluteCanvasSize.Y)
		end
	end

	const function Ready(): boolean
		return Chat.Draft() ~= "" or Chat.Sending()
	end

	const function Insert(Token: string)
		const Text = Chat.Draft()
		const At = math.clamp(if Box.CursorPosition >= 0 then Box.CursorPosition - 1 else #Text, 0, #Text)
		const Before = Text:sub(1, At)
		const Spacer = if Before ~= "" and Before:sub(-1) ~= " " then " " else ""

		Chat.Draft(`{Before}{Spacer}{Token} {Text:sub(At + 1)}`)
		task.defer(function()
			Box:CaptureFocus()
			Box.CursorPosition = At + #Spacer + #Token + 2
		end)
	end

	Chat.Insert = Insert

	local Watching = not game:GetService("RunService"):IsRunning()

	Vide.cleanup(function()
		if Watching then
			Watching = false
			task.spawn(Client.SetDropArea)
		end
	end)

	task.spawn(function()
		local Last = ""

		if Watching then
			Client.SetDropArea()
		end

		while Watching and task.wait(0.25) do
			const Window = Chat.Window

			if not Window then
				continue
			end

			if not Window.Enabled then
				if Last ~= "off" then
					Last = "off"
					Client.SetDropArea()
				end

				continue
			end

			const Point = Window:GetRelativeMousePosition()
			const Size = Window.AbsoluteSize

			if Point.X >= 0 and Point.Y >= 0 and Point.X <= Size.X and Point.Y <= Size.Y then
				const Key = `{Point.X},{Point.Y},{Size.X},{Size.Y}`

				if Key ~= Last then
					Last = Key
					Client.SetDropArea(Point, Size)
				end
			end
		end
	end)

	task.spawn(function()
		while Watching do
			const Ok, Answer = Client.TakeDropped(Chat.Dragging())

			if not Ok or typeof(Answer) ~= "table" or typeof(Answer.files) ~= "table" then
				task.wait(2)

				continue
			end

			if typeof(Answer.dragging) == "string" then
				Chat.Dragging(Answer.dragging)
			end

			for _, File in Answer.files do
				Insert(if typeof(File.data) == "string" then Context.AddImage(File.name, File.data, File.mediaType) else Context.AddFile(File.name, File.path))
			end
		end
	end)

	Vide.cleanup(function()
		Chat.Insert = nil
	end)

	const function Arm()
		if not Settings.Get("ClipboardPaste")() then
			return
		end

		Marker = Context.NextImageToken()
		task.spawn(Client.ArmClipboard, Marker)
	end

	const function Disarm()
		if Marker == "" then
			return
		end

		const Previous = Marker

		Marker = ""
		task.spawn(Client.DisarmClipboard, Previous)
	end

	Vide.cleanup(Disarm)

	local Holding = false

	Vide.cleanup(function()
		if Holding then
			Holding = false
			Keys.Release()
		end
	end)

	const function Attach(Token: string)
		const Ok, Image = Client.GetClipboardImage(Token)

		if not Ok or not Image.data then
			return
		end

		Context.AddImage("Image", Image.data, Image.mediaType, Token)
		Arm()
	end

	Vide.cleanup(Keys.OnPaste(function()
		if not Box or not Box:IsFocused() or Marker == "" or not Settings.Get("ClipboardPaste")() then
			return
		end

		const Token = Marker
		const Before = Chat.Draft()

		task.wait(0.25)

		if Marker ~= Token or Chat.Draft() ~= Before or Chat.Draft():find(Token, 1, true) then
			return
		end

		const Ok, Image = Client.GetClipboardImage(nil)

		if not Ok or typeof(Image) ~= "table" or not Image.data or Marker ~= Token then
			return
		end

		Context.AddImage("Image", Image.data, Image.mediaType, Token)
		Insert(Token)
		Arm()
	end))

	const function Remove(Token: string)
		Context.Remove(Token)
		Chat.Draft((Chat.Draft():gsub(Token:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"), "")):gsub("  +", " "))
	end

	Box = Create "TextBox" {
		Name = "Draft",
		Size = function()
			return UDim2.new(0, Wide(), 0, Tall())
		end,
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Text,
		PlaceholderColor3 = Theme.Colors.DimText,
		PlaceholderText = function()
			if Settings.Get("PromptSuggestions")() and Chat.Suggestion() then
				return Chat.Suggestion() :: string
			end

			return if Chat.WindowWidth() < 300 then "/ for commands, @ for objects" else "Type / for commands, @ for objects"
		end,
		TextSize = Settings.TextSize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextWrapped = true,
		MultiLine = true,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = Chat.Draft,
		Focused = function()
			Arm()

			if not Holding then
				Holding = true
				Keys.Hold()
			end
		end,
		FocusLost = function()
			Disarm()

			if Holding then
				Holding = false
				Keys.Release()
			end
		end,

		Vide.changed("Text", function(Text: string)
			const Previous = Chat.Draft()
			const Cursor = if Box then Box.CursorPosition else -1
			const Suggested = Chat.Suggestion()

			if Previous == "" and Text:match("^\t+$") and Suggested and Settings.Get("PromptSuggestions")() then
				Chat.Draft(Suggested)
				Box.Text = Suggested
				task.defer(function()
					Box.CursorPosition = #Suggested + 1
					Follow()
				end)

				return
			end

			-- Enter also types a carriage return after the newline; drop it so the draft only holds \n.
			if Text:find("\r", 1, true) then
				const Kept = if Cursor > 0 then (Text:sub(1, Cursor - 1):gsub("\r", "")) else ""
				const Clean = Text:gsub("\r", "")

				Chat.Draft(Clean)

				if Box and Box.Text ~= Clean then
					Box.Text = Clean
				end

				task.defer(function()
					if Box.Text == Clean and Cursor > 0 then
						Box.CursorPosition = #Kept + 1
					end

					Follow()
				end)

				return
			end

			-- The box already knows where the newline went; searching for the first changed character
			-- would land at the end of a run of blank lines instead.
			const Where = Cursor - 1
			const Added = #Text == #Previous + 1 and Where >= 1 and Text:sub(Where, Where) == "\n" and Text:sub(1, Where - 1) .. Text:sub(Where + 1) == Previous

			if Added and Settings.Get("SendWithEnter")() then
				Chat.Draft(Text)
				task.defer(function()
					if Box.Text == Text then
						Box.CursorPosition = Where + 1
					end

					Follow()
				end)
				task.spawn(function()
					if Keys.Shifted() or Box.Text ~= Text then
						return
					end

					Chat.Draft("")
					Box.Text = ""
					Chat.Send(Previous)
				end)

				return
			end

			if Marker ~= "" and Text:find(Marker, 1, true) and not Previous:find(Marker, 1, true) then
				task.spawn(Attach, Marker)
			end

			Chat.Draft(Text)
			task.defer(Follow)
		end),
	}

	Field = Create "ScrollingFrame" {
		Name = "Field",
		Size = function()
			return UDim2.new(0, 0, 0, math.clamp(Tall(), Line, 148))
		end,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Colors.Border,
		LayoutOrder = 1,

		Vide.action(function(Object: ScrollingFrame)
			const function Measure()
				Wide(Object.AbsoluteWindowSize.X)
			end

			const Connection = Object:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(Measure)

			Vide.cleanup(function()
				Connection:Disconnect()
			end)
			task.defer(Measure)
		end),

		Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		Box,
		Create "TextLabel" {
			Name = "Painted",
			Size = function()
				return UDim2.new(0, Wide(), 0, Tall())
			end,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,
			Text = function()
				return Markdown.Tokens(Format.Escape(Chat.Draft()), Theme.Colors.Accent():ToHex(), true, Chat.KnownTokens(), Theme.Colors.Input():ToHex())
			end,
		},
	}

	const Send = Create "TextButton" {
		Name = "Send",
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.Colors.Accent,
		BackgroundTransparency = function()
			return if Ready() then 0 else 1
		end,
		TextColor3 = function()
			return if Ready() then Theme.Colors.AccentText() else Theme.Colors.DimText()
		end,
		FontFace = Config.IconFont,
		TextSize = 13,
		AutoButtonColor = true,
		LayoutOrder = 2,
		Text = function()
			return if Chat.Sending() and Chat.Draft() == "" then Config.Icons.Stop else Config.Icons.Send
		end,
		Activated = function()
			if Chat.Sending() and Chat.Draft() == "" then
				Chat.Stop()

				return
			end

			Chat.Send(Chat.Draft())
		end,

		Create "UICorner" {CornerRadius = UDim.new(1, 0)},
		Create "UIStroke" {
			Color = Theme.Colors.Border,
			Transparency = function()
				return if Ready() then 1 else 0
			end,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	}

	return Create "Frame" {
		Name = "InputBar",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 3,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 6),
		},
		CommandSuggestions(),
		MentionSuggestions(),
		Attachments(Remove),
		AddMenu(AddOpen, Insert),
		Vide.action(function(Object: Frame)
			const function Measure()
				ModelPicker.BarHeight(Object.AbsoluteSize.Y)
			end

			Vide.cleanup(Object:GetPropertyChangedSignal("AbsoluteSize"):Connect(Measure))
			task.defer(Measure)
		end),
		Create "Frame" {
			Name = "Row",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Input,
			BorderSizePixel = 0,
			LayoutOrder = 2,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			},
			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 6),
			},
			Field,
			Send,
		},
		Create "Frame" {
			Name = "Tools",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 3,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
				Wraps = true,
			},
			IconButton {
				Icon = Config.Icons.Add,
				LayoutOrder = 0,
				OnClick = function()
					Chat.PickerOpen(false)
					Chat.EffortOpen(false)
					Chat.ModeOpen(false)
					AddOpen(not AddOpen())
				end,
			},
			ModelPicker.ModeButton(),
			ModelPicker.Button(),
			ModelPicker.EffortButton(),
			UsageRing(),
			Create "Frame" {
				Name = "Spacer",
				Size = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
		},
	}
end