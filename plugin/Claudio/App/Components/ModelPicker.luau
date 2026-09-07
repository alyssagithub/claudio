--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)
const Slider = require(script.Parent.Slider)
const Toggle = require(script.Parent.Toggle)

const Create = Vide.create

const EffortNames = {
	low = "Low",
	medium = "Medium",
	high = "High",
	xhigh = "Extra",
	max = "Max",
	ultracode = "Ultracode",
}

const function CurrentModel(): Types.ModelInfo?
	for _, Model in Chat.Models() do
		if Model.value == Settings.Get("Model")() then
			return Model
		end
	end

	return nil
end

const function EffortLevels(): {string}
	const Model = CurrentModel()

	return if Model and Model.supportsEffort then Model.supportedEffortLevels else {}
end

const function CurrentEffort(): string
	const Chosen = Settings.Get("Effort")()

	return if Chosen == "" then "high" else Chosen
end

const function EffortName(Level: string): string
	return EffortNames[Level] or `{Level:sub(1, 1):upper()}{Level:sub(2)}`
end

const Tip = Vide.source("")
const Explaining = Vide.source(false)

const function Row(Name: () -> string, Detail: () -> string, Chosen: () -> boolean, OnClick: () -> (), LayoutOrder: number, Arrow: (() -> boolean)?, Hover: ((boolean) -> ())?, Described: boolean?, Badge: (() -> boolean)?)
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Choice",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() then 0 else 1
		end,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = LayoutOrder,
		Activated = OnClick,
		MouseEnter = function()
			Hovered(true)

			if not Described then
				Tip(Detail())
			end

			if Hover then
				Hover(true)
			end
		end,
		MouseLeave = function()
			Hovered(false)

			if Tip() == Detail() then
				Tip("")
			end

			if Hover then
				Hover(false)
			end
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, if Described then 6 else 2),
			PaddingBottom = UDim.new(0, if Described then 6 else 2),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, if Described then 1 else 0),
		},
		Create "Frame" {
			Name = "Row",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			},
			Create "TextLabel" {
				Name = "Title",
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Text = Name,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Create "Frame" {
				Name = "Badge",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Button,
				LayoutOrder = 2,
				Visible = function()
					return Badge ~= nil and Badge()
				end,

				Create "UICorner" {CornerRadius = UDim.new(0, 4)},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 5),
					PaddingRight = UDim.new(0, 5),
					PaddingTop = UDim.new(0, 1),
					PaddingBottom = UDim.new(0, 1),
				},
				Create "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					Text = "Default",
				},
			},
			Icon {
				Name = Config.Icons.Chosen,
				Colour = Theme.Colors.Accent,
				LayoutOrder = 3,
				Visible = Chosen,
			},
			Icon {
				Name = Config.Icons.Down,
				Colour = Theme.Colors.DimText,
				Rotation = function()
					return -90
				end,
				LayoutOrder = 4,
				Visible = function()
					return Arrow ~= nil and Arrow()
				end,
			},
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
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 2,
			Visible = Described == true,
			Text = Detail,
		},
	}
end

const ModelPicker = {
	BarHeight = Vide.source(0),
}

const MoreOpen = Vide.source(false)

const function Listed(Extra: boolean): {Types.ModelInfo}
	const Found = {}

	for _, Model in Chat.Models() do
		if (Model.extra == true) == Extra then
			table.insert(Found, Model)
		end
	end

	return Found
end

const function Divider(LayoutOrder: number)
	return Create "Frame" {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Colors.Border,
		BorderSizePixel = 0,
		LayoutOrder = LayoutOrder,

		Create "UIPadding" {
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		},
	}
end

const function Titled(Model: Types.ModelInfo): string
	const Version = Model.description:match("^(%a[%a ]-%s[%d%.]+)")

	if Model.value == "default" then
		return if Version then `Default ({Version})` else "Default"
	end

	if not Version then
		return Model.displayName
	end

	return Version
end

const OverMore = Vide.source(false)

const function CloseMoreLater()
	task.delay(0.25, function()
		if not OverMore() then
			MoreOpen(false)
		end
	end)
end

const function Pick(Model: () -> Types.ModelInfo, LayoutOrder: number, Inside: boolean?)
	return Row(function()
		return Titled(Model())
	end, function()
		return Model().description
	end, function()
		return Settings.Get("Model")() == Model().value
	end, function()
		Settings.Set("Model", Model().value)
		Settings.Set("Effort", "")
		OverMore(false)
		MoreOpen(false)
		Chat.PickerOpen(false)
	end, LayoutOrder, nil, function(Entered: boolean)
		if Inside then
			OverMore(Entered)

			if not Entered then
				CloseMoreLater()
			end

			return
		end

		if Entered then
			MoreOpen(false)
		end
	end)
end

function ModelPicker.Menu()
	return Create "Frame" {
		Name = "ModelMenu",
		Size = UDim2.fromOffset(182, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 1),
		Position = function()
			return UDim2.new(0, 8, 1, -ModelPicker.BarHeight() - 6)
		end,
		ZIndex = 40,
		BackgroundColor3 = Theme.Colors.Input,
		LayoutOrder = 1,
		Visible = Chat.PickerOpen,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Button},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Row(function()
			return "Auto"
		end, function()
			return "Picks the cheapest model that can do the task, and moves up when work goes wrong"
		end, function()
			return Settings.Get("Model")() == "auto"
		end, function()
			Settings.Set("Model", "auto")
			Settings.Set("Effort", "")
			Chat.PickerOpen(false)
		end, 1),
		Vide.indexes(function()
			return Listed(false)
		end, function(Model: () -> Types.ModelInfo, Index: number)
			return Pick(Model, Index + 1)
		end),
		Divider(9000),
		Row(function()
			return "More models"
		end, function()
			return ""
		end, function()
			return false
		end, function()
			MoreOpen(true)
		end, 9001, function()
			return true
		end, function(Entered: boolean)
			if Entered then
				MoreOpen(true)

				return
			end

			CloseMoreLater()
		end),
		Divider(9002),
		Create "TextLabel" {
			Name = "Section",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 9003,
			Text = "Fast mode",

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 2),
			},
		},
		Create "Frame" {
			Name = "FastMode",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 9004,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			},
			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Create "TextLabel" {
				Name = "Title",
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Text = "Enable fast mode",

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Create "Frame" {
				Name = "Switch",
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				Toggle("FastMode"),
			},
		},
		Create "Frame" {
			Name = "Anchor",
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 0,

			Create "Frame" {
				Name = "More",
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromOffset(128, 0),
				Position = UDim2.fromOffset(186, 0),
				BackgroundColor3 = Theme.Colors.Input,
				ZIndex = 150,
				Visible = MoreOpen,

				Create "UICorner" {CornerRadius = UDim.new(0, 6)},
				Create "UIStroke" {Color = Theme.Colors.Button},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 3),
					PaddingRight = UDim.new(0, 3),
					PaddingTop = UDim.new(0, 3),
					PaddingBottom = UDim.new(0, 3),
				},
				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
				},
				Vide.indexes(function()
					return Listed(true)
				end, function(Model: () -> Types.ModelInfo, Index: number)
					return Pick(Model, Index, true)
				end),
			},
		},
		Create "TextLabel" {
			Name = "Tip",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 0, -6),
			BackgroundColor3 = Theme.Colors.Panel,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 200,
			Visible = function()
				return Tip() ~= ""
			end,
			Text = Tip,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
			Create "UIStroke" {Color = Theme.Colors.Button},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
			},
		},
	}
end

function ModelPicker.Button()
	return Create "TextButton" {
		Name = "ModelButton",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 4,
		Activated = function()
			if #Chat.Models() == 0 then
				task.spawn(Chat.LoadModels)
			end

			Chat.EffortOpen(false)
			Chat.ModeOpen(false)
			Chat.PickerOpen(not Chat.PickerOpen())
		end,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
		},
		Create "TextLabel" {
			Name = "Label",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			LayoutOrder = 1,
			Text = function()
				const Model = CurrentModel()

				return if Model then (Model.displayName:gsub(" %(Experimental%)", "")) else "Auto"
			end,
		},
		Icon {
			Name = Config.Icons.Down,
			Size = Settings.SmallText,
			LayoutOrder = 2,
		},
	}
end

const function CurrentMode(): Types.Mode
	for _, Mode in Config.Modes do
		if Mode.value == Settings.Get("Mode")() then
			return Mode
		end
	end

	return Config.Modes[1]
end

function ModelPicker.ModeButton()
	return Create "TextButton" {
		Name = "ModeButton",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		TextColor3 = function()
			return if Chat.ModeOpen() then Theme.Colors.Text() else Theme.Colors.DimText()
		end,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		AutoButtonColor = false,
		LayoutOrder = 1,
		Text = function()
			return CurrentMode().label
		end,
		Activated = function()
			Chat.PickerOpen(false)
			Chat.EffortOpen(false)
			Chat.ModeOpen(not Chat.ModeOpen())
		end,
	}
end

function ModelPicker.ModeMenu()
	return Create "Frame" {
		Name = "ModeMenu",
		Size = UDim2.fromOffset(224, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 1),
		Position = function()
			return UDim2.new(0, 8, 1, -ModelPicker.BarHeight() - 6)
		end,
		ZIndex = 40,
		BackgroundColor3 = Theme.Colors.Input,
		LayoutOrder = 1,
		Visible = Chat.ModeOpen,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Button},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
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
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Text = "Mode",

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 2),
			},
		},
		Vide.indexes(function()
			return Config.Modes
		end, function(Mode: () -> Types.Mode, Index: number)
			return Row(function()
				return Mode().label
			end, function()
				return Mode().detail
			end, function()
				return Settings.Get("Mode")() == Mode().value
			end, function()
				Settings.Set("Mode", Mode().value)
				Chat.ModeOpen(false)
			end, 1 + Index, nil, nil, true, function()
				return Mode().value == Settings.Hidden.Mode
			end)
		end),
		Create "TextButton" {
			Name = "Bypass",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = 9000,
			Activated = function()
				Settings.Set("Bypass", not Settings.Get("Bypass")())
			end,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 2),
			},
			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Create "TextLabel" {
				Name = "Label",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Text = "Bypass permissions",

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Create "TextLabel" {
				Name = "State",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = function()
					return if Settings.Get("Bypass")() then Theme.Colors.Error() else Theme.Colors.DimText()
				end,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 2,
				Text = function()
					return if Settings.Get("Bypass")() then "Enabled" else "Enable"
				end,
			},
		},
	}
end

function ModelPicker.EffortButton()
	return Create "TextButton" {
		Name = "EffortButton",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		TextColor3 = function()
			return if Chat.EffortOpen() then Theme.Colors.Text() else Theme.Colors.DimText()
		end,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		AutoButtonColor = false,
		LayoutOrder = 5,
		Visible = function()
			return #EffortLevels() > 0
		end,
		Text = function()
			return EffortName(CurrentEffort())
		end,
		Activated = function()
			Chat.PickerOpen(false)
			Chat.ModeOpen(false)
			Chat.EffortOpen(not Chat.EffortOpen())
		end,
	}
end

function ModelPicker.EffortMenu()
	return Create "Frame" {
		Name = "EffortMenu",
		Size = UDim2.fromOffset(182, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 1),
		Position = function()
			return UDim2.new(0, 8, 1, -ModelPicker.BarHeight() - 6)
		end,
		ZIndex = 40,
		BackgroundColor3 = Theme.Colors.Input,
		LayoutOrder = 1,
		Visible = function()
			return Chat.EffortOpen() and #EffortLevels() > 0
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Button},
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
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			},
			Create "TextLabel" {
				Name = "Title",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				LayoutOrder = 1,
				Text = "Effort",
			},
			Create "TextLabel" {
				Name = "Level",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 2,
				Text = function()
					return EffortName(CurrentEffort())
				end,
			},
			Create "Frame" {
				Name = "Spacer",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			},
			Create "TextButton" {
				Name = "Explain",
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				AutoButtonColor = false,
				LayoutOrder = 4,
				Text = "?",
				MouseEnter = function()
					Explaining(true)
				end,
				MouseLeave = function()
					Explaining(false)
				end,

				Create "UICorner" {CornerRadius = UDim.new(1, 0)},
				Create "UIStroke" {Color = Theme.Colors.DimText},
				Create "Frame" {
					Name = "Bubble",
					Size = UDim2.fromOffset(196, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 4, 0, -8),
					BackgroundColor3 = Theme.Colors.Panel,
					ZIndex = 200,
					Visible = Explaining,

					Create "UICorner" {CornerRadius = UDim.new(0, 6)},
					Create "UIStroke" {Color = Theme.Colors.Button},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
					},
					Create "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					},
					Create "TextLabel" {
						Name = "Title",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.TextSize,
						FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 200,
						LayoutOrder = 1,
						Text = "Effort",
					},
					Create "TextLabel" {
						Name = "Body",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.DimText,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 200,
						LayoutOrder = 2,
						Text = "Higher effort means more thorough responses, but takes longer and uses your limits faster.",
					},
				},
			},
		},
		Create "Frame" {
			Name = "Ends",
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			LayoutOrder = 2,

			Create "TextLabel" {
				Name = "Faster",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				Text = "Faster",
			},
			Create "TextLabel" {
				Name = "Smarter",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				Text = "Smarter",
			},
		},
		Slider {
			Stops = EffortLevels,
			Chosen = CurrentEffort,
			OnChange = function(Level: string)
				Settings.Set("Effort", Level)
			end,
			LayoutOrder = 3,
		},
	}
end

return ModelPicker