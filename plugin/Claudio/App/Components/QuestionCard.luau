--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)
const IconButton = require(script.Parent.IconButton)
const Paragraph = require(script.Parent.Paragraph)

const Create = Vide.create

const Other = "Other"
const Talk = "Chat about this"

const function Plain(Html: string): string
	return (Html:gsub("<[Bb][Rr]%s*/?>", "\n"):gsub("</[Pp]>", "\n\n"):gsub("</?[Ll][Ii]>", "\n"):gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", "\""):gsub("&#39;", "'"):gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("\n\n\n+", "\n\n"):match("^%s*(.-)%s*$")) :: string
end

const function Escape(Text: string): string
	return (Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

return function()
	const Step = Vide.source(1)
	const Focus = Vide.source(1)
	const Picked = Vide.source({} :: {[string]: {[string]: boolean}})
	const Written = Vide.source({} :: {[string]: string})
	const Notes = Vide.source({} :: {[string]: string})
	const Noting = Vide.source(false)
	const KeyBox = Vide.source(nil :: TextBox?)
	const Wide = Vide.source(0)
	const OtherBox = Vide.source(nil :: TextBox?)

	const function Asked(): {Types.Question}
		const Held = Chat.Question()

		return if Held then Held.questions else {}
	end

	const function Reviewing(): boolean
		return #Asked() > 1 and Step() > #Asked()
	end

	const function Current(): Types.Question?
		return if Reviewing() then nil else Asked()[Step()]
	end

	const function Chosen(): {[string]: boolean}
		const Held = Current()

		return if Held then Picked()[Held.question] or {} else {}
	end

	const function Previewing(): boolean
		const Held = Current()

		if not Held or Held.multiSelect then
			return false
		end

		for _, Option in Held.options do
			if Option.preview and Option.preview ~= "" then
				return true
			end
		end

		return false
	end

	const function Rows(): {string}
		const Held = Current()

		if not Held then
			return {}
		end

		const Labels = {}

		for _, Option in Held.options do
			table.insert(Labels, Option.label)
		end

		table.insert(Labels, Other)

		if not Held.multiSelect then
			table.insert(Labels, Talk)
		end

		return Labels
	end

	const function Answer(Question: Types.Question): string
		const Mine = Picked()[Question.question] or {}
		const Labels = {}

		for _, Option in Question.options do
			if Mine[Option.label] then
				table.insert(Labels, Option.label)
			end
		end

		if Mine[Other] and (Written()[Question.question] or ""):match("%S") then
			table.insert(Labels, Written()[Question.question])
		end

		return table.concat(Labels, ", ")
	end

	const function Finish()
		const Answers = {}
		const Annotations = {}

		for _, Question in Asked() do
			const Given = Answer(Question)
			const Noted = Notes()[Question.question]
			const Extra: {[string]: string} = {}

			if Given ~= "" then
				Answers[Question.question] = Given
			end

			for _, Option in Question.options do
				if (Picked()[Question.question] or {})[Option.label] and Option.preview and not Question.multiSelect then
					Extra.preview = Option.preview
				end
			end

			if Noted and Noted:match("%S") then
				Extra.notes = Noted
			end

			if next(Extra) then
				Annotations[Question.question] = Extra
			end
		end

		Chat.Reply(Answers, if next(Annotations) then Annotations else nil)
	end

	const function Decline()
		Chat.Reply(nil)
	end

	const function Go(Wanted: number)
		Step(math.clamp(Wanted, 1, if #Asked() > 1 then #Asked() + 1 else 1))
		Focus(1)
		Noting(false)
	end

	const function Advance()
		if Step() < #Asked() or (#Asked() > 1 and Step() == #Asked()) then
			Go(Step() + 1)

			return
		end

		Finish()
	end

	const function Listen()
		task.defer(function()
			const Box = KeyBox()
			const Writing = OtherBox()

			if Box and Chat.Question() and not (Writing and Writing:IsFocused()) and not Noting() then
				Box:CaptureFocus()
			end
		end)
	end

	const function Take(Label: string)
		const Held = Current()

		if not Held then
			return
		end

		if Label == Talk then
			Chat.Reply(nil, nil, true)

			return
		end

		const Board = table.clone(Picked())
		const Mine = table.clone(Board[Held.question] or {})

		if Held.multiSelect then
			Mine[Label] = if Mine[Label] then nil else true
		else
			table.clear(Mine)
			Mine[Label] = true
		end

		Board[Held.question] = Mine
		Picked(Board)

		if Label ~= Other then
			return
		end

		task.defer(function()
			const Box = OtherBox()

			if Box then
				Box:CaptureFocus()
			end
		end)
	end

	Vide.effect(function()
		Chat.Question()

		Vide.untrack(function()
			Step(1)
			Focus(1)
			Picked({})
			Written({})
			Notes({})
			Noting(false)
			Listen()
		end)
	end)

	const function Press(Key: Enum.KeyCode)
		if Key == Enum.KeyCode.Escape then
			Decline()
		elseif Key == Enum.KeyCode.Tab or Key == Enum.KeyCode.Right then
			Go(Step() + 1)
		elseif Key == Enum.KeyCode.Left then
			Go(Step() - 1)
		elseif Reviewing() then
			if Key == Enum.KeyCode.Return then
				Finish()
			end
		elseif Key == Enum.KeyCode.Up then
			Focus(math.max(1, Focus() - 1))
		elseif Key == Enum.KeyCode.Down then
			Focus(math.min(#Rows(), Focus() + 1))
		elseif Key == Enum.KeyCode.Return then
			const Label = Rows()[Focus()]

			if Label then
				Take(Label)
			end
		elseif Key == Enum.KeyCode.N and Previewing() then
			Noting(true)
		end
	end

	const function Row(Index: number)
		const Hovered = Vide.source(false)

		const function Label(): string
			return Rows()[Index] or ""
		end

		const function Detail(): string
			const Held = Current()
			const Option = if Held then Held.options[Index] else nil

			return if Option then Option.description else ""
		end

		const function Selected(): boolean
			return Chosen()[Label()] == true
		end

		return Create "TextButton" {
			Name = "Choice",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Button,
			BackgroundTransparency = function()
				return if Selected() then 0 elseif Focus() == Index or Hovered() then 0.5 else 1
			end,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = Index,
			Vide.action(Covers.Hover(Hovered)),
			Vide.action(function()
				Vide.effect(function()
					if Hovered() then
						Vide.untrack(function()
							Focus(Index)
						end)
					end
				end)
			end),
			Activated = function()
				Focus(Index)
				Take(Label())
				Listen()
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},
			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			},
			Create "TextLabel" {
				Name = "Mark",
				Size = function()
					return UDim2.fromOffset(Settings.SmallText() + 4, Settings.SmallText() + 4)
				end,
				BackgroundColor3 = function()
					return if Selected() then Theme.Colors.Accent() else Theme.Colors.Input()
				end,
				BackgroundTransparency = function()
					return if Label() == Talk then 1 else 0
				end,
				TextColor3 = function()
					return if Selected() then Theme.Colors.AccentText() else Theme.Colors.DimText()
				end,
				TextSize = Settings.SmallText,
				FontFace = Config.IconFont,
				LayoutOrder = 1,
				Text = function()
					return if Selected() then Config.Icons.Chosen else ""
				end,

				Create "UICorner" {
					CornerRadius = function()
						const Held = Current()

						return if Held and Held.multiSelect then UDim.new(0, 3) else UDim.new(1, 0)
					end,
				},
				Create "UIStroke" {
					Color = Theme.Colors.DimText,
					Thickness = 1.5,
					Transparency = function()
						return if Selected() or Label() == Talk then 1 else 0
					end,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				},
			},
			Create "Frame" {
				Name = "Words",
				Size = function()
					return UDim2.new(1, -(Settings.SmallText() + 12), 0, 0)
				end,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
				Create "TextLabel" {
					Name = "Label",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = function()
						return if Label() == Talk then Theme.Colors.DimText() else Theme.Colors.Text()
					end,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					LayoutOrder = 1,
					Visible = function()
						return Label() ~= Other
					end,
					Text = Label,
				},
				Create "TextBox" {
					Name = "Written",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					PlaceholderText = "Type something…",
					PlaceholderColor3 = Theme.Colors.DimText,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					ClearTextOnFocus = false,
					LayoutOrder = 2,
					Visible = function()
						return Label() == Other
					end,
					Text = function()
						const Held = Current()

						return if Held then Written()[Held.question] or "" else ""
					end,
					Vide.action(function(Box: TextBox)
						Vide.effect(function()
							if Label() == Other then
								Vide.untrack(function()
									OtherBox(Box)
								end)
							end
						end)
						Vide.cleanup(Box:GetPropertyChangedSignal("Text"):Connect(function()
							const Held = Current()

							if not Held or Label() ~= Other then
								return
							end

							const Board = table.clone(Written())

							Board[Held.question] = Box.Text
							Written(Board)

							if Box.Text:match("%S") and not Chosen()[Other] then
								Take(Other)
							end
						end))
						Vide.cleanup(Box.Focused:Connect(function()
							Focus(Index)

							if not Chosen()[Other] then
								Take(Other)
							end
						end))
						Vide.cleanup(Box.FocusLost:Connect(function(Entered: boolean)
							if Entered then
								Advance()
							end

							Listen()
						end))
					end),
				},
				Create "TextLabel" {
					Name = "Detail",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					LayoutOrder = 3,
					Visible = function()
						return Detail() ~= ""
					end,
					Text = Detail,
				},
			},
		}
	end

	const function Tab(Index: number)
		const Hovered = Vide.source(false)

		return Create "TextButton" {
			Name = "Tab",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = function()
				return if Step() == Index then Theme.Colors.Accent() else Theme.Colors.Button()
			end,
			BackgroundTransparency = function()
				return if Step() == Index or Hovered() then 0 else 0.4
			end,
			TextColor3 = function()
				return if Step() == Index then Theme.Colors.AccentText() else Theme.Colors.DimText()
			end,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			AutoButtonColor = false,
			LayoutOrder = Index,
			Text = function()
				const Question = Asked()[Index]

				if not Question then
					return "Submit"
				end

				return `{if Answer(Question) ~= "" then "✓ " else ""}{Question.header}`
			end,
			Vide.action(Covers.Hover(Hovered)),
			Activated = function()
				Go(Index)
				Listen()
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			},
		}
	end

	const function Hint(Text: string, Order: number, Visible: () -> boolean)
		return Create "TextLabel" {
			Name = "Hint",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = Order,
			Visible = Visible,
			Text = Text,
		}
	end

	return Create "Frame" {
		Name = "Asking",
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,

		Create "UIPadding" {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 6),
		},
		Create "Frame" {
			Name = "QuestionCard",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			LayoutOrder = 1500000,
			Visible = function()
				return #Asked() > 0
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
			Create "UIStroke" {Color = Theme.Colors.Accent},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 6),
			},
			Create "TextBox" {
				Name = "Keys",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				TextTransparency = 1,
				Text = "",
				ClearTextOnFocus = true,
				LayoutOrder = 0,
				Vide.action(function(Box: TextBox)
					KeyBox(Box)
					Vide.cleanup(Box.InputBegan:Connect(function(Input: InputObject)
						if Input.UserInputType == Enum.UserInputType.Keyboard then
							Press(Input.KeyCode)
						end
					end))
					Vide.cleanup(Box:GetPropertyChangedSignal("Text"):Connect(function()
						if Box.Text == "" then
							return
						end

						if Box.Text:lower():find("n", 1, true) and Previewing() then
							Noting(true)
						end

						Box.Text = ""
					end))
					Vide.cleanup(Box.FocusLost:Connect(function(Entered: boolean)
						if Entered then
							Press(Enum.KeyCode.Return)
							Listen()
						end
					end))
				end),
			},
			Create "Frame" {
				Name = "Heading",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Wraps = true,
					Padding = UDim.new(0, 4),
				},
				Vide.indexes(function()
					const Slots = {}

					if #Asked() > 1 then
						for Index = 1, #Asked() + 1 do
							table.insert(Slots, Index)
						end
					end

					return Slots
				end, function(Slot: () -> number)
					return Tab(Slot())
				end),
				Create "TextLabel" {
					Name = "Chip",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundColor3 = Theme.Colors.Button,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					LayoutOrder = 1,
					Visible = function()
						return #Asked() == 1
					end,
					Text = function()
						const Held = Asked()[1]

						return if Held then Held.header else ""
					end,

					Create "UICorner" {CornerRadius = UDim.new(0, 4)},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 5),
						PaddingRight = UDim.new(0, 5),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					},
				},
				Create "Frame" {
					Name = "Gap",
					Size = UDim2.fromScale(0, 0),
					BackgroundTransparency = 1,
					LayoutOrder = 99,

					Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				},
				IconButton {
					Icon = Config.Icons.Close,
					LayoutOrder = 100,
					Size = Settings.SmallText,
					OnClick = Decline,
				},
			},
			Paragraph(function()
				const Held = Current()

				return if Held then Held.question elseif Reviewing() then "Review your answers" else ""
			end, 2),
			Create "Frame" {
				Name = "Body",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Visible = function()
					return Current() ~= nil
				end,

				Create "UIListLayout" {
					FillDirection = function()
						return if Previewing() and Wide() >= 480 then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
					end,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				},
				Vide.action(function(Body: Frame)
					Wide(Body.AbsoluteSize.X)
					Vide.cleanup(Body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
						Wide(Body.AbsoluteSize.X)
					end))
				end),
				Create "Frame" {
					Name = "List",
					Size = function()
						return if Previewing() and Wide() >= 480 then UDim2.new(0.42, -4, 0, 0) else UDim2.fromScale(1, 0)
					end,
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,

					Create "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						Padding = UDim.new(0, 2),
					},
					Vide.indexes(Rows, function(_: () -> string, Index: number)
						return Row(Index)
					end),
				},
				Create "Frame" {
					Name = "Pane",
					Size = function()
						return if Wide() >= 480 then UDim2.new(0.58, -4, 0, 0) else UDim2.fromScale(1, 0)
					end,
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Visible = Previewing,

					Create "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						Padding = UDim.new(0, 4),
					},
					Create "Frame" {
						Name = "Preview",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Theme.Colors.Code,
						LayoutOrder = 1,

						Create "UICorner" {CornerRadius = UDim.new(0, 4)},
						Create "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
							PaddingTop = UDim.new(0, 6),
							PaddingBottom = UDim.new(0, 6),
						},
						Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
						Paragraph(function()
							const Held = Current()

							if not Held then
								return ""
							end

							const Focused = Held.options[Focus()]

							if Focused and Focused.preview and Focused.preview ~= "" then
								return Plain(Focused.preview)
							end

							for _, Option in Held.options do
								if Chosen()[Option.label] and Option.preview then
									return Plain(Option.preview)
								end
							end

							return ""
						end, 1),
					},
					Create "TextButton" {
						Name = "AddNotes",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
						Visible = function()
							return not Noting()
						end,
						Text = "press n to add notes",
						Activated = function()
							Noting(true)
						end,
					},
					Create "TextBox" {
						Name = "Notes",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Theme.Colors.Input,
						TextColor3 = Theme.Colors.Text,
						PlaceholderText = "Notes",
						PlaceholderColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
						ClearTextOnFocus = false,
						LayoutOrder = 3,
						Visible = Noting,
						Text = function()
							const Held = Current()

							return if Held then Notes()[Held.question] or "" else ""
						end,

						Create "UICorner" {CornerRadius = UDim.new(0, 4)},
						Create "UIPadding" {
							PaddingLeft = UDim.new(0, 6),
							PaddingRight = UDim.new(0, 6),
							PaddingTop = UDim.new(0, 4),
							PaddingBottom = UDim.new(0, 4),
						},
						Vide.action(function(Box: TextBox)
							Vide.effect(function()
								if Noting() then
									Vide.untrack(function()
										task.defer(Box.CaptureFocus, Box)
									end)
								end
							end)
							Vide.cleanup(Box:GetPropertyChangedSignal("Text"):Connect(function()
								const Held = Current()

								if not Held then
									return
								end

								const Board = table.clone(Notes())

								Board[Held.question] = Box.Text
								Notes(Board)
							end))
							Vide.cleanup(Box.FocusLost:Connect(function()
								Noting(false)
								Listen()
							end))
						end),
					},
				},
			},
			Create "Frame" {
				Name = "Review",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Visible = Reviewing,

				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 4),
				},
				Vide.indexes(Asked, function(Question: () -> Types.Question, Index: number)
					return Create "TextLabel" {
						Name = "Answered",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
						RichText = true,
						LayoutOrder = Index,
						Text = function()
							const Given = Answer(Question())

							return `· {Escape(Question().question)}\n  <font color="#{Theme.Colors.Accent():ToHex()}">→ {if Given ~= "" then Escape(Given) else "<i>not set</i>"}</font>`
						end,
					}
				end),
				Hint("You have not answered all questions", 900, function()
					for _, Question in Asked() do
						if Answer(Question) == "" then
							return true
						end
					end

					return false
				end),
				Hint("Ready to submit your answers?", 901, function()
					return true
				end),
			},
			Create "Frame" {
				Name = "Choices",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 100,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				},
				Create "TextLabel" {
					Name = "Shortcuts",
					Size = UDim2.fromScale(0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					LayoutOrder = 0,
					Text = function()
						if Reviewing() then
							return "enter submit · ←/→ switch · esc cancel"
						end

						return `↑/↓ navigate · enter select{if Previewing() then " · n add notes" else ""}{if #Asked() > 1 then " · tab switch questions" else ""} · esc cancel`
					end,

					Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				},
				Button {
					Text = "Cancel",
					LayoutOrder = 1,
					Visible = Reviewing,
					OnClick = function()
						Go(#Asked())
					end,
				},
				Button {
					Text = function()
						if Reviewing() then
							return "Submit answers"
						end

						return if Step() < #Asked() then "Next" else "Submit"
					end,
					Primary = true,
					LayoutOrder = 2,
					OnClick = Advance,
				},
			},
		},
	}
end
