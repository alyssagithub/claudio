--!strict
const AssetService = game:GetService("AssetService")

const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

const Edge = 32
local Glyph: EditableImage?

const function Drawn(): EditableImage
	if Glyph then
		return Glyph
	end

	const Made = AssetService:CreateEditableImage({Size = Vector2.new(Edge, Edge)})

	for Offset = -1, 1 do
		Made:DrawLine(Vector2.new(9, 12 + Offset), Vector2.new(16, 19 + Offset), Color3.new(1, 1, 1), 0, Enum.ImageCombineType.Overwrite, Enum.AntiAliasing.Enabled)
		Made:DrawLine(Vector2.new(16, 19 + Offset), Vector2.new(23, 12 + Offset), Color3.new(1, 1, 1), 0, Enum.ImageCombineType.Overwrite, Enum.AntiAliasing.Enabled)
	end

	Glyph = Made

	return Made
end

type Props = {
	Angle: () -> number,
	Colour: (() -> Color3)?,
	Size: (() -> number)?,
	LayoutOrder: number?,
}

return function(Props: Props)
	const Output = AssetService:CreateEditableImage({Size = Vector2.new(Edge, Edge)})

	Vide.cleanup(function()
		Output:Destroy()
	end)

	Vide.effect(function()
		const Angle = Props.Angle()

		Output:DrawRectangle(Vector2.zero, Vector2.new(Edge, Edge), Color3.new(), 1, Enum.ImageCombineType.Overwrite)
		Output:DrawImageTransformed(Vector2.new(Edge / 2, Edge / 2), Vector2.one, Angle, Drawn(), {PivotPoint = Vector2.new(Edge / 2, Edge / 2)})
	end)

	return Create "ImageLabel" {
		Name = "Chevron",
		Size = function()
			const Side = (Props.Size or Settings.SmallText)()

			return UDim2.fromOffset(Side, Side)
		end,
		BackgroundTransparency = 1,
		ImageColor3 = Props.Colour or Theme.Colors.DimText,
		ImageContent = Content.fromObject(Output),
		LayoutOrder = Props.LayoutOrder,
	}
end