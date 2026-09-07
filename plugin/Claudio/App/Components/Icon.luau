--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	Name: any,
	Colour: (() -> Color3)?,
	Size: (() -> number)?,
	LayoutOrder: number?,
	Visible: (() -> boolean)?,
	Rotation: (() -> number)?,
}

return function(Props: Props)
	return Create "TextLabel" {
		Name = "Icon",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = Config.IconFont,
		Text = Props.Name,
		TextColor3 = Props.Colour or Theme.Colors.DimText,
		TextSize = Props.Size or Settings.TextSize,
		LayoutOrder = Props.LayoutOrder,
		Rotation = Props.Rotation,
		Visible = Props.Visible,
	}
end