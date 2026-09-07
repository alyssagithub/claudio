--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	Icon: any,
	OnClick: () -> (),
	LayoutOrder: number?,
	Visible: (() -> boolean)?,
	Size: (() -> number)?,
	Tooltip: (string | () -> string)?,
	Disabled: (() -> boolean)?,
	DisabledTooltip: string?,
	Active: (() -> boolean)?,
}

const function Read(Value: (string | () -> string)?): string
	if type(Value) == "function" then
		return Value()
	end

	return Value or ""
end

return function(Props: Props)
	const Hovered = Vide.source(false)

	const function Room(): number
		return if Props.Size then Props.Size() else Settings.TextSize()
	end

	return Create "TextButton" {
		Name = "IconButton",
		Size = function()
			return UDim2.fromOffset(Room() + 10, Room() + 6)
		end,
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() then 0 else 1
		end,
		FontFace = Config.IconFont,
		Text = Props.Icon,
		TextColor3 = function()
			if Props.Disabled and Props.Disabled() then
				return Theme.Colors.Border()
			end

			if Props.Active and Props.Active() then
				return Theme.Colors.Accent()
			end

			return if Hovered() then Theme.Colors.Text() else Theme.Colors.DimText()
		end,
		TextSize = Props.Size or Settings.TextSize,
		AutoButtonColor = false,
		LayoutOrder = Props.LayoutOrder,
		Visible = Props.Visible,
		Activated = function()
			if Props.Disabled and Props.Disabled() then
				return
			end

			Props.OnClick()
		end,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "TextLabel" {
			Name = "Tooltip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Theme.Colors.Background,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			ZIndex = 60,
			Visible = function()
				return Hovered() and (Props.Tooltip ~= nil or Props.DisabledTooltip ~= nil)
			end,
			Text = function()
				if Props.Disabled and Props.Disabled() then
					return Props.DisabledTooltip or Read(Props.Tooltip)
				end

				return Read(Props.Tooltip)
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			},
		},
		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
	}
end