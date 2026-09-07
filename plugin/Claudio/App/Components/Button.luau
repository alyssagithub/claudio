--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	Text: any,
	OnClick: () -> (),
	Primary: boolean?,
	Danger: boolean?,
	LayoutOrder: number?,
	Visible: (() -> boolean)?,
}

return function(Props: Props)
	return Create "TextButton" {
		Name = "Button",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = if Props.Danger then Theme.Colors.Error elseif Props.Primary then Theme.Colors.Accent else Theme.Colors.Button,
		TextColor3 = if Props.Danger or Props.Primary then Theme.Colors.AccentText else Theme.Colors.ButtonText,
		Text = Props.Text,
		TextSize = Settings.TextSize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		AutoButtonColor = true,
		LayoutOrder = Props.LayoutOrder,
		Visible = Props.Visible,
		Activated = Props.OnClick,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		},
	}
end