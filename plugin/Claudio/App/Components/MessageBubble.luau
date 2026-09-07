--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Config = require(script.Parent.Parent.Parent.Config)
const Markdown = require(script.Parent.Parent.Parent.Markdown)
const Format = require(script.Parent.Parent.Parent.Format)
const Changes = require(script.Parent.Parent.Parent.Changes)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const ImageView = require(script.Parent.ImageView)
const Paragraph = require(script.Parent.Paragraph)
const Icon = require(script.Parent.Icon)
const IconButton = require(script.Parent.IconButton)
const Button = require(script.Parent.Button)

const TextService = game:GetService("TextService")

const Create = Vide.create

type Props = {
	Role: () -> string,
	Text: () -> string,
	Activity: () -> {string},
	Thinking: (() -> string?)?,
	Calls: (() -> {Types.ToolCall})?,
	Edits: (() -> {string}?)?,
	Tokens: (() -> Types.Tokens?)?,
	Milliseconds: (() -> number?)?,
	Failed: (() -> boolean)?,
	Cost: (() -> number?)?,
	Estimated: (() -> boolean?)?,
	Prompt: (() -> string?)?,
	At: (() -> number?)?,
	Index: (() -> number)?,
	Attachments: (() -> {string})?,
	Images: (() -> {EditableImage})?,
	Model: (() -> string?)?,
	Checkpoint: (() -> number?)?,
	LayoutOrder: any,
}

const function IsCommand(Name: string): boolean
	return Name == "Bash" or Name == "PowerShell"
end

const function Describe(Entry: Types.ToolCall, Running: boolean): string
	if Entry.delegate then
		const Sent = Entry.delegate :: {name: string, model: string}

		return `{if Running then "Delegating" else "Delegated"} to the {Sent.name} on {Format.Model(Sent.model)}`
	end

	const Name = Entry.name

	if IsCommand(Name) then
		return if Running then "Running a command" else "Ran a command"
	end

	const Server, Tool = Name:match("^mcp__(.-)__(.+)$")
	const Verb = if Running then "Using" else "Used"

	if not Server or not Tool then
		return `{Verb} {Name}`
	end

	const Words = (Tool:gsub("_", " "))

	return `{Verb} {Server}: {Words:sub(1, 1):upper()}{Words:sub(2)}`
end

const function Detail(Name: string, Text: () -> string, LayoutOrder: number)
	return Create "TextLabel" {
		Name = Name,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Code,
		TextColor3 = Theme.Colors.CodeText,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.Code),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = LayoutOrder,
		Text = Text,
		Visible = function()
			return Text() ~= ""
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
	}
end

const function Note(Name: string, LayoutOrder: number, Text: () -> string, Visible: () -> boolean)
	return Create "TextLabel" {
		Name = Name,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.DimText,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = LayoutOrder,
		Visible = Visible,
		Text = Text,
	}
end

return function(Props: Props)
	const Hovered = Vide.source(false)

	const function IsUser(): boolean
		return Props.Role() == "user"
	end

	const function Hug(): number
		if not IsUser() or (Props.Images ~= nil and #Props.Images() > 0) then
			return math.huge
		end

		return TextService:GetTextSize(Props.Text(), Settings.TextSize(), Enum.Font.BuilderSans, Vector2.new(9999, 9999)).X + 21
	end

	const function Segment(Value: () -> Markdown.Segment)
		const function IsCode(): boolean
			return Value().Kind == "code"
		end

		if not IsCode() then
			return Paragraph(function()
				return Value().Text
			end, 1000 + Value().Order, Props.Index == nil)
		end

		const function CodePadding(): UDim
			return UDim.new(0, if IsCode() then 8 else 0)
		end

		return Create "TextLabel" {
			Name = function()
				return if IsCode() then "Code" else "Text"
			end,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Code,
			BackgroundTransparency = function()
				return if IsCode() then 0 else 1
			end,
			TextColor3 = function()
				return if IsCode() then Theme.Colors.CodeText() else Theme.Colors.Text()
			end,
			TextSize = Settings.TextSize,
			FontFace = function()
				return Font.fromEnum(if IsCode() then Enum.Font.Code else Enum.Font.BuilderSans)
			end,
			TextWrapped = true,
			RichText = function()
				return not IsCode()
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = function()
				return if IsCode() then Value().Text else Markdown.Rich(Value().Text)
			end,
			LayoutOrder = 1000 + Value().Order,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = CodePadding,
				PaddingRight = CodePadding,
				PaddingTop = function()
					return UDim.new(0, if IsCode() then 6 else 0)
				end,
				PaddingBottom = function()
					return UDim.new(0, if IsCode() then 6 else 0)
				end,
			},
		}
	end

	const function Spend(): string
		const At = if Props.At then Props.At() else nil
		const Tokens = if Props.Tokens then Props.Tokens() else nil
		const Cost = if Props.Cost then Props.Cost() else nil
		const Parts: {string} = {}

		if At then
			table.insert(Parts, (Format.Ago(At)))
		end

		if Tokens then
			const Counted = if IsUser() then Tokens.input else Tokens.output

			if Counted > 0 then
				table.insert(Parts, `{Format.Amount(Counted)} tokens`)
			end
		end

		if Cost and Cost > 0 then
			table.insert(Parts, `{if Props.Estimated and Props.Estimated() then "~" else ""}${string.format("%.3f", Cost)}`)
		end

		return table.concat(Parts, " · ")
	end

	const function Written(): {string}
		return Changes.For({
			Edits = if Props.Edits then Props.Edits() else nil,
			Calls = if Props.Calls then Props.Calls() else nil,
		} :: any)
	end

	const function Empty(): boolean
		return Props.Text() == ""
			and (if Props.Thinking then Props.Thinking() or "" else "") == ""
			and #(if Props.Calls then Props.Calls() else {}) == 0
			and #(if Props.Images then Props.Images() else {}) == 0
			and #(if Props.Attachments then Props.Attachments() else {}) == 0
			and #Written() == 0
	end

	const Listed = Vide.source(false)

	const function Asked(Entry: Types.ToolCall): {{Question: string, Given: string}}
		const Pairs = {}

		if Entry.name ~= Config.AskTool then
			return Pairs
		end

		for Question, Given in Entry.output:gmatch('"([^"]+)"="([^"]*)"') do
			table.insert(Pairs, {Question = Question, Given = Given})
		end

		return Pairs
	end

	const function Call(Value: () -> Types.ToolCall, Index: number)
		const Open = Vide.source(false)

		return Create "Frame" {
			Name = "ToolCall",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = Index,
			Visible = function()
				return #Asked(Value()) > 0 or Listed() or Chat.Thinking()
			end,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 4),
			},
			Create "Frame" {
				Name = "Answered",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				LayoutOrder = 0,
				Visible = function()
					return #Asked(Value()) > 0
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 6)},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				},
				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 8),
				},
				Vide.indexes(function()
					return Asked(Value())
				end, function(Pair: () -> {Question: string, Given: string}, Order: number)
					return Create "Frame" {
						Name = "Line",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = Order,

						Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
						Create "TextLabel" {
							Name = "Question",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.DimText,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextWrapped = true,
							LayoutOrder = 1,
							Text = function()
								return Pair().Question
							end,
						},
						Create "TextLabel" {
							Name = "Given",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.Text,
							TextSize = Settings.TextSize,
							FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextWrapped = true,
							LayoutOrder = 2,
							Text = function()
								return (Pair().Given:gsub(",", ", "))
							end,
						},
					}
				end),
			},
			Create "TextButton" {
				Name = "Header",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = function()
					return #Asked(Value()) == 0
				end,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = 1,
				Activated = function()
					Open(not Open())
				end,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				},
				Icon {
					Name = Config.Icons.Down,
					Size = Settings.SmallText,
					Colour = function()
						return if Value().status == "error" then Theme.Colors.Error() else Theme.Colors.DimText()
					end,
					Rotation = function()
						return if Open() then 0 else -90
					end,
					LayoutOrder = 1,
				},
				Create "TextLabel" {
					Name = "Summary",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = function()
						return if Value().status == "error" then Theme.Colors.Error() else Theme.Colors.DimText()
					end,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
					Text = function()
						const Entry = Value()

						if Entry.status == "running" then
							return Describe(Entry, true)
						end

						return `{Describe(Entry, false)}{if Entry.status == "error" then " · failed" else ""}`
					end,
				},
			},
			Create "Frame" {
				Name = "Steps",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				Create "UIPadding" {PaddingLeft = UDim.new(0, 14)},
				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 2),
				},
				Vide.indexes(function()
					return Value().steps or {}
				end, function(Step: () -> string, Index: number)
					return Create "TextLabel" {
						Name = "Step",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = Index,
						Text = function()
							return `· {Step()}`
						end,
					}
				end),
			},
			Detail("Input", function()
				return if Open() then Value().input else ""
			end, 3),
			Detail("Output", function()
				return if Open() then Value().output else ""
			end, 4),
		}
	end



	return Create "Frame" {
		Name = function()
			return if IsUser() then "UserMessage" else "AssistantMessage"
		end,
		Size = function()
			return UDim2.fromScale(if IsUser() then 0.85 else 1, 0)
		end,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Props.LayoutOrder,
		Visible = function()
			return not Empty()
		end,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = function()
				return if IsUser() then Enum.UIFlexAlignment.None else Enum.UIFlexAlignment.Fill
			end,
			HorizontalAlignment = function()
				return if IsUser() then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
			end,
			Padding = UDim.new(0, 2),
		},
		Create "Frame" {
			Name = "Bubble",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = function()
				return if IsUser() then 0 else 1
			end,
			LayoutOrder = 1,

			Create "UICorner" {CornerRadius = UDim.new(0, 8)},
			Create "UISizeConstraint" {
				MaxSize = function()
					return Vector2.new(Hug(), math.huge)
				end,
			},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			Create "UIListLayout" {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},
			Create "Frame" {
				Name = "Thought",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = -1,
				Visible = function()
					return Chat.Thinking() and Props.Thinking ~= nil and (Props.Thinking() or "") ~= ""
				end,

				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
				},
				Create "Frame" {
					Name = "Rule",
					Size = UDim2.new(0, 2, 1, 0),
					Position = UDim2.fromOffset(-12, 0),
					BackgroundColor3 = Theme.Colors.Border,
					BorderSizePixel = 0,

					Create "UICorner" {CornerRadius = UDim.new(1, 0)},
				},
				Create "TextLabel" {
					Name = "Text",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
					TextWrapped = true,
					LineHeight = 1.15,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = function()
						return if Props.Thinking then Props.Thinking() or "" else ""
					end,
				},
			},
			Vide.indexes(function()
				return if Props.Calls then Props.Calls() else {}
			end, Call),
			Create "TextButton" {
				Name = "Summary",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = "",
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				AutoButtonColor = false,
				LayoutOrder = 0,
				Visible = function()
					if Listed() or Chat.Thinking() or not Props.Calls then
						return false
					end

					for _, Entry in Props.Calls() do
						if Entry.name ~= Config.AskTool then
							return true
						end
					end

					return false
				end,
				Activated = function()
					Listed(not Listed())
				end,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				},
				Create "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					Text = function()
						const Calls: {Types.ToolCall} = if Props.Calls then Props.Calls() else {}
						local Commands = 0
						local Questions = 0
						local Sent = 0

						for _, Entry in Calls do
							if Entry.name == Config.AskTool then
								Questions += 1

								continue
							end

							if Entry.status == "running" then
								return Describe(Entry, true)
							end

							if Entry.delegate then
								Sent += 1

								continue
							end

							if IsCommand(Entry.name) then
								Commands += 1
							end
						end

						const Tools = #Calls - Commands - Questions - Sent
						const Parts = {}

						if Sent > 0 then
							table.insert(Parts, if Sent == 1 then "Delegated a read" else `Delegated {Sent} reads`)
						end

						if Commands > 0 then
							table.insert(Parts, if Commands == 1 then "ran a command" else `ran {Commands} commands`)
						end

						if Tools > 0 or #Parts == 0 then
							table.insert(Parts, `used {Tools} tool{if Tools == 1 then "" else "s"}`)
						end

						const Line = table.concat(Parts, ", ")

						return `{Line:sub(1, 1):upper()}{Line:sub(2)}`
					end,
				},
				Icon {
					Name = Config.Icons.Down,
					Size = Settings.SmallText,
					Rotation = function()
						return -90
					end,
					LayoutOrder = 2,
				},
			},
			Note("Activity", 0, function()
				const Names = {}

				for _, Name in Props.Activity() do
					table.insert(Names, (Name:gsub("^mcp__.-__", "")))
				end

				return `Used {table.concat(Names, ", ")}`
			end, function()
				return #Props.Activity() > 0 and (not Props.Calls or #Props.Calls() == 0)
			end),
			Vide.indexes(Vide.derive(function()
				const Keyed: {[string]: Markdown.Segment} = {}

				for _, Piece in Markdown.Split(Props.Text()) do
					Keyed[`{Piece.Order}|{Piece.Kind}`] = Piece
				end

				return Keyed
			end), Segment),
			Vide.indexes(Vide.derive(function()
				return if Props.Images then Props.Images() else {}
			end), function(Image, Index: number)
				return ImageView(Image, 900000 + Index)
			end),
			Note("Attachments", 1000000, function()
				return `Attached {table.concat(if Props.Attachments then Props.Attachments() else {}, ", ")}`
			end, function()
				return Props.Attachments ~= nil and #Props.Attachments() > 0
			end),
			Create "Frame" {
				Name = "Changes",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				LayoutOrder = 1000006,
				Visible = function()
					return #Written() > 0
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 6)},
				Create "UIStroke" {Color = Theme.Colors.Border},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				},
				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 2),
				},
				Create "TextLabel" {
					Name = "Heading",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					Text = function()
						const Lines = Written()
						const Count = `{#Lines} thing{if #Lines == 1 then "" else "s"} in Studio`

						return if IsUser() then `You changed {Count}` else `Changed {Count}`
					end,
				},
				Vide.indexes(Written, function(Text: () -> string, Index: number)
					return Create "TextLabel" {
						Name = "Change",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = Index + 1,
						Text = function()
							return `• {Text()}`
						end,
					}
				end),
			},
			Note("Model", 1000002, function()
				return if Props.Model then Props.Model() or "" else ""
			end, function()
				return Props.Model ~= nil and Props.Model() ~= nil
			end),
		},
		Create "Frame" {
			Name = "Actions",
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			LayoutOrder = 2,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = function()
					return if IsUser() then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
				end,
				Padding = UDim.new(0, 4),
			},
			Create "ImageLabel" {
				Name = "Mark",
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = Config.ButtonIcon,
				LayoutOrder = 0,
				Visible = function()
					return not IsUser() and Props.Index ~= nil
				end,
			},
			Vide.show(function()
				return Hovered() or (Props.Failed ~= nil and Props.Failed())
			end, function()
				return Create "Frame" {
					Name = "Buttons",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					LayoutOrder = 1,

					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = function()
							return if IsUser() then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
						end,
						Padding = UDim.new(0, 4),
					},
					Button {
						Text = "Continue",
						LayoutOrder = 1,
						Visible = function()
							return Props.Failed ~= nil and Props.Failed() and Props.Prompt ~= nil and Props.Prompt() ~= nil
						end,
						OnClick = function()
							task.spawn(Chat.Continue, if Props.Prompt then Props.Prompt() else nil)
						end,
					},
					IconButton {
						Icon = Config.Icons.Retry,
						LayoutOrder = 1,
						Size = Settings.SmallText,
						Visible = function()
							return Hovered() and IsUser() and Props.Index ~= nil and Props.Index() ~= nil
						end,
						Disabled = Chat.Sending,
						Tooltip = "Send this again",
						DisabledTooltip = "Cannot resend while Claude is working",
						OnClick = function()
							task.spawn(Chat.Retry, if Props.Index then Props.Index() else 0)
						end,
					},
					IconButton {
						Icon = Config.Icons.Copy,
						LayoutOrder = 2,
						Size = Settings.SmallText,
						Visible = Hovered,
						Tooltip = "Copy",
						OnClick = function()
							task.spawn(Chat.Copy, Props.Text())
						end,
					},
					IconButton {
						Icon = Config.Icons.Fork,
						LayoutOrder = 3,
						Size = Settings.SmallText,
						Visible = Hovered,
						Tooltip = "Fork from here",
						OnClick = function()
							task.spawn(Chat.ForkHere)
						end,
					},
					IconButton {
						Icon = function()
							return if Props.Index and Chat.IsChapter(Props.Index()) then Config.Icons.Unpin else Config.Icons.Pin
						end,
						LayoutOrder = 4,
						Size = Settings.SmallText,
						Visible = function()
							return Hovered() and not IsUser() and Props.Index ~= nil
						end,
						Active = function()
							return Props.Index ~= nil and Chat.IsChapter(Props.Index())
						end,
						Tooltip = function()
							return if Props.Index and Chat.IsChapter(Props.Index()) then "Unpin chapter" else "Pin as chapter"
						end,
						OnClick = function()
							if not Props.Index then
								return
							end

							task.spawn(Chat.ToggleChapter, Props.Index(), Props.Text())
						end,
					},
					IconButton {
						Icon = Config.Icons.Restore,
						LayoutOrder = 5,
						Size = Settings.SmallText,
						Visible = function()
							return Hovered() and Props.Checkpoint ~= nil and Props.Checkpoint() ~= nil and Props.Index ~= nil and Props.Index() ~= nil
						end,
						Disabled = Chat.Sending,
						Tooltip = "Rewind",
						DisabledTooltip = "Rewind is unavailable while Claude is working",
						OnClick = function()
							const Index = if Props.Checkpoint then Props.Checkpoint() else nil

							if not Index then
								return
							end

							Chat.Rewinding(if Props.Index then Props.Index() else nil)
						end,
					},
					Create "TextLabel" {
						Name = "Usage",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.TextSize,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						LayoutOrder = 7,
						Visible = function()
							return Hovered() and Spend() ~= ""
						end,
						Text = function()
							return Spend()
						end,

						Create "UIPadding" {PaddingLeft = UDim.new(0, 4)},
					},
				}
			end),
		},
	}
end