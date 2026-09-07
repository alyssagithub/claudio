--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)
const IconButton = require(script.Parent.IconButton)

const Create = Vide.create

const Other = "Other"

return function()
	const Step = Vide.source(1)
	const Picked = Vide.source({} :: {[string]: {[string]: boolean}})
	const Written = Vide.source({} :: {[string]: string})
	const Shut = Vide.source(false)
	const Settled = Vide.source({} :: {{Question: string, Given: string}})

	const function Asked(): {Types.Question}
		const Held = Chat.Question()

		return if Held then Held.questions else {}
	end

	const function Current(): Types.Question?
		return Asked()[Step()]
	end

	const function Chosen(): {[string]: boolean}
		const Held = Current()

		return if Held then Picked()[Held.question] or {} else {}
	end

	const function Ready(): boolean
		const Held = Current()

		if not Held then
			return false
		end

		for Label in Chosen() do
			if Label ~= Other or (Written()[Held.question] or ""):match("%S") then
				return true
			end
		end

		return false
	end

	const function Take(Label: string)
		const Held = Current()

		if not Held then
			return
		end

		const Board = table.clone(Picked())
		const Mine = table.clone(Board[Held.question] or {})

		if not Held.multiSelect then
			table.clear(Mine)
		end

		Mine[Label] = if Mine[Label] then nil else true
		Board[Held.question] = Mine

		Picked(Board)
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

		return table.concat(Labels, ",")
	end

	const function Finish()
		const Answers = {}

		for _, Question in Asked() do
			const Given = Answer(Question)

			if Given ~= "" then
				Answers[Question.question] = Given
			end
		end

		const Record = {}

		for _, Question in Asked() do
			table.insert(Record, {Question = Question.question, Given = Answer(Question)})
		end

		Step(1)
		Picked({})
		Written({})
		Shut(false)
		Settled(Record)
		Chat.Reply(Answers)
	end

	const function Dismiss()
		Step(1)
		Picked({})
		Written({})
		Shut(false)
		Settled({})
		Chat.Reply(nil)
	end

	const function Advance()
		if Step() < #Asked() then
			Step(Step() + 1)

			return
		end

		Finish()
	end

	const function Row(Label: () -> string, Detail: () -> string, Order: number, Number: () -> number)
		const Hovered = Vide.source(false)

		return Create "TextButton" {
			Name = "Choice",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Button,
			BackgroundTransparency = function()
				return if Chosen()[Label()] then 0 elseif Hovered() then 0.5 else 1
			end,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = Order,
			Visible = function()
				return not Shut()
			end,
			MouseEnter = function()
				Hovered(true)
			end,
			MouseLeave = function()
				Hovered(false)
			end,
			Activated = function()
				Take(Label())
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
				Padding = UDim.new(0, 6),
			},
			Create "Frame" {
				Name = "Words",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
				Create "TextLabel" {
					Name = "Label",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					LayoutOrder = 1,
					Text = Label,
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
					LayoutOrder = 2,
					Visible = function()
						return Detail() ~= ""
					end,
					Text = Detail,
				},
			},
			Create "TextLabel" {
				Name = "Mark",
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Theme.Colors.Accent,
				BackgroundTransparency = function()
					return if Chosen()[Label()] then 0 else 1
				end,
				TextColor3 = function()
					return if Chosen()[Label()] then Theme.Colors.AccentText() else Theme.Colors.DimText()
				end,
				TextSize = Settings.SmallText,
				FontFace = function()
					const Held = Current()

					return if Held and Held.multiSelect then Config.IconFont else Font.fromEnum(Enum.Font.BuilderSans)
				end,
				LayoutOrder = 2,
				Text = function()
					const Held = Current()

					if Held and Held.multiSelect then
						return if Chosen()[Label()] then Config.Icons.Chosen else ""
					end

					return tostring(Number())
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 3)},
				Create "UIStroke" {
					Color = Theme.Colors.Border,
					Transparency = function()
						return if Chosen()[Label()] then 1 else 0
					end,
				},
			},
		}
	end

	const function Preview(Look: () -> string, Order: number)
		return Create "TextLabel" {
			Name = "Preview",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Code,
			TextColor3 = Theme.Colors.CodeText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = Order,
			Visible = function()
				return Look() ~= ""
			end,
			Text = Look,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},
		}
	end

	const function Summary()
		return Create "Frame" {
			Name = "Answered",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			LayoutOrder = 1500001,
			Visible = function()
				return Current() == nil and #Settled() > 0
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
				Padding = UDim.new(0, 4),
			},
			Vide.indexes(Settled, function(Entry: () -> {Question: string, Given: string}, Index: number)
				return Create "Frame" {
					Name = "Line",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = Index,

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
							return Entry().Question
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
							const Given = Entry().Given

							return if Given == "" then "Skipped" else Given
						end,
					},
				}
			end),
		}
	end

	return Create "Frame" {
		Name = "Asking",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 6),
		},
		Summary(),
		Create "Frame" {
			Name = "QuestionCard",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 1500000,
		Visible = function()
			return Current() ~= nil
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
		Create "Frame" {
			Name = "Heading",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Create "TextLabel" {
				Name = "Counter",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Accent,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 1,
				Visible = function()
					return #Asked() > 1
				end,
				Text = function()
					return `{Step()}/{#Asked()}`
				end,
			},
			Create "TextLabel" {
				Name = "Chip",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Button,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				LayoutOrder = 2,
				Text = function()
					const Held = Current()

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
			IconButton {
				Icon = Config.Icons.Down,
				LayoutOrder = 4,
				Size = Settings.SmallText,
				Tooltip = "Collapse",
				OnClick = function()
					Shut(not Shut())
				end,
			},
			IconButton {
				Icon = Config.Icons.Close,
				LayoutOrder = 5,
				Size = Settings.SmallText,
				Tooltip = "Dismiss without answering",
				OnClick = Dismiss,
			},
			Create "Frame" {
				Name = "Gap",
				Size = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
		},
		Create "TextLabel" {
			Name = "Question",
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
				const Held = Current()

				return if Held then Held.question else ""
			end,
		},
		Vide.indexes(function()
			const Held = Current()

			return if Held then Held.options else {}
		end, function(Option: () -> Types.Choice, Index: number)
			return Row(function()
				return Option().label
			end, function()
				return Option().description
			end, Index + 10, function()
				return Index
			end)
		end),
		Preview(function()
			const Held = Current()

			if not Held or Shut() then
				return ""
			end

			for _, Option in Held.options do
				if Chosen()[Option.label] and Option.preview then
					return Option.preview :: string
				end
			end

			return ""
		end, 92),
		Row(function()
			return Other
		end, function()
			return ""
		end, 90, function()
			const Held = Current()

			return if Held then #Held.options + 1 else 1
		end),
		Create "TextBox" {
			Name = "Written",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Input,
			TextColor3 = Theme.Colors.Text,
			PlaceholderText = "Type your own answer here",
			PlaceholderColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ClearTextOnFocus = false,
			LayoutOrder = 91,
			Visible = function()
				return Chosen()[Other] == true and not Shut()
			end,
			Text = "",

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			},
			Vide.action(function(Box: TextBox)
				Vide.cleanup(Box:GetPropertyChangedSignal("Text"):Connect(function()
					const Held = Current()

					if not Held then
						return
					end

					const Board = table.clone(Written())

					Board[Held.question] = Box.Text
					Written(Board)
				end))
			end),
		},
		Create "Frame" {
			Name = "Choices",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 100,
			Visible = function()
				return not Shut()
			end,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Button {
				Text = "Skip",
				LayoutOrder = 1,
				OnClick = Advance,
			},
			Button {
				Text = function()
					return if Step() < #Asked() then "Next" else "Submit"
				end,
				Primary = true,
				LayoutOrder = 2,
				Visible = Ready,
				OnClick = Advance,
			},
		},
		},
	}
end
