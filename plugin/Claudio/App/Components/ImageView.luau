--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

return function(Image: () -> EditableImage, LayoutOrder: number)
	return Create "ImageLabel" {
		Name = "Picture",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.Colors.Code,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = LayoutOrder,
		ImageContent = function()
			return Content.fromObject(Image())
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 8)},
		Create "UIAspectRatioConstraint" {
			AspectRatio = function()
				return Image().Size.X / math.max(1, Image().Size.Y)
			end,
			DominantAxis = Enum.DominantAxis.Width,
		},
	}
end