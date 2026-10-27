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

const Create = Vide.create

const Other = "Other"

local Kept: {Id: string?, Step: number, Picked: {[string]: {[string]: boolean}}, Written: {[string]: string}} = {
	Id = nil,
	Step = 1,
	Picked = {},
	Written = {},
}

return function()
	const Step = Vide.source(1)
	const Picked = Vide.source({} :: {[string]: {[string]: boolean}})
	const Written = Vide.source({} :: {[string]: string})
	const Shut = Vide.source(false)

	Vide.effect(function()
		const Held = Chat.Question()

		Vide.untrack(function()
			const Id = if Held then Held.id else nil

			if Id == nil then
				return
			end

			if Id == Kept.Id then
				Step(math.clamp(Kept.Step, 1, math.max(1, #Held.questions)))
				Picked(Kept.Picked)
				Written(Kept.Written)

				return
			end

			Kept = {Id = Id, Step = 1, Picked = {}, Written = {}}
			Step(1)
			Picked({})
			Written({})
			Shut(false)
		end)
	end)

	Vide.effect(function()
		const Now = {Step = Step(), Picked = Picked(), Written = Written()}

		Vide.untrack(function()
			if Kept.Id then
				Kept.Step = Now.Step
				Kept.Picked = Now.Picked
				Kept.Written = Now.Written
			end
		end)
	end)

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
		const Annotations = {}

		for _, Question in Asked() do
			const Given = Answer(Question)

			if Given ~= "" then
				Answers[Question.question] = Given
			end

			for _, Option in Question.options do
				if (Picked()[Question.question] or {})[Option.label] and Option.preview and not Question.multiSelect then
					Annotations[Question.question] = {preview = Option.preview}
				end
			end
		end

		Chat.Reply(Answers, if next(Annotations) then Annotations else nil)
	end

	const function Dismiss()
		Chat.Reply(nil)
	end

	const function Advance()
		if Step() < #Asked() then
			Step(Step() + 1)

			return
		end

		Finish()
	end

	const function Writing(): Instance
		return Create "TextBox" {
			Name = "Written",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Background,
			TextColor3 = Theme.Colors.Text,
			PlaceholderText = "Type your own answer here",
			PlaceholderColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ClearTextOnFocus = false,
			LayoutOrder = 3,
			Visible = function()
				return not Shut()
			end,
			Text = function()
				const Held = Current()

				return if Held then Written()[Held.question] or "" else ""
			end,

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

					if Box.Text:match("%S") and not Chosen()[Other] then
						Take(Other)
					end
				end))
			end),
		}
	end

	const function Row(Label: () -> string, Detail: () -> string, Order: number, Number: () -> number, Extra: Instance?)
		const Hovered = Vide.source(false)

		return Create "TextButton" {
			Name = "Choice",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Button,
			BackgroundTransparency = function()
				return if Chosen()[Label()] then 0 elseif Hovered() then 0.3 else 0.6
			end,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = Order,
			Visible = function()
				return not Shut()
			end,
			Vide.action(Covers.Hover(Hovered)),
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
			Create "Frame" {
				Name = "Words",
				Size = function()
					return UDim2.new(1, -(Settings.SmallText() + 10), 0, 0)
				end,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,

				Extra,

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
				Size = function()
					return UDim2.fromOffset(Settings.SmallText() + 4, Settings.SmallText() + 4)
				end,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				BackgroundColor3 = function()
					return if Chosen()[Label()] then Theme.Colors.Accent() else Theme.Colors.Input()
				end,
				BackgroundTransparency = function()
					const Held = Current()

					return if Chosen()[Label()] or (Held and Held.multiSelect) then 0 else 1
				end,
				TextColor3 = function()
					return if Chosen()[Label()] then Theme.Colors.AccentText() else Theme.Colors.DimText()
				end,
				TextSize = Settings.SmallText,
				FontFace = function()
					const Held = Current()

					return if Held and Held.multiSelect then Config.IconFont else Font.fromEnum(Enum.Font.BuilderSans)
				end,
				Text = function()
					const Held = Current()

					if Held and Held.multiSelect then
						return if Chosen()[Label()] then Config.Icons.Chosen else ""
					end

					return tostring(Number())
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 3)},
				Create "UIStroke" {
					Color = function()
						const Held = Current()

						return if Held and Held.multiSelect then Theme.Colors.DimText() else Theme.Colors.Border()
					end,
					Thickness = 1.5,
					Transparency = function()
						return if Chosen()[Label()] then 1 else 0
					end,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				},
			},
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
			return Current() ~= nil
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Border},
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

			Create "TextLabel" {
				Name = "Counter",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Accent,
				BackgroundTransparency = 0.8,
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

				Create "UICorner" {CornerRadius = UDim.new(0, 4)},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 5),
					PaddingRight = UDim.new(0, 5),
					PaddingTop = UDim.new(0, 1),
					PaddingBottom = UDim.new(0, 1),
				},
			},
			Create "Frame" {
				Name = "Buttons",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				},
				IconButton {
					Icon = Config.Icons.Down,
					LayoutOrder = 1,
					Size = Settings.SmallText,
					OnClick = function()
						Shut(not Shut())
					end,
				},
				IconButton {
					Icon = Config.Icons.Close,
					LayoutOrder = 2,
					Size = Settings.SmallText,
					OnClick = Dismiss,
				},
			},
			Create "TextLabel" {
				Name = "Question",
				Position = function()
					return UDim2.fromOffset(if #Asked() > 1 then 32 else 0, 0)
				end,
				Size = function()
					return UDim2.new(1, -(if #Asked() > 1 then 32 else 0) - 2 * (Settings.SmallText() + 10), 0, 0)
				end,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 3,
				Text = function()
					const Held = Current()

					return if Held then Held.question else ""
				end,
			},
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
		Row(function()
			return Other
		end, function()
			return ""
		end, 90, function()
			const Held = Current()

			return if Held then #Held.options + 1 else 1
		end, Writing()),
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
				Text = "Back",
				LayoutOrder = 1,
				Visible = function()
					return Step() > 1
				end,
				OnClick = function()
					Step(Step() - 1)
				end,
			},
			Create "Frame" {
				Name = "Gap",
				Size = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Button {
				Text = "Skip",
				LayoutOrder = 3,
				OnClick = Advance,
			},
			Create "TextButton" {
				Name = "Next",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = function()
					return if Ready() then Theme.Colors.Text() else Theme.Colors.Button()
				end,
				TextColor3 = function()
					return if Ready() then Theme.Colors.Background() else Theme.Colors.DimText()
				end,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				AutoButtonColor = false,
				LayoutOrder = 4,
				Text = function()
					return if Step() < #Asked() then "Next" else "Submit"
				end,
				Activated = function()
					if Ready() then
						Advance()
					end
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 4)},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				},
			},
		},
		},
	}
end