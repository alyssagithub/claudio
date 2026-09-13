--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

return function(Image: () -> EditableImage, LayoutOrder: number)
	return Create "ImageButton" {
		Name = "Picture",
		Size = function()
			return UDim2.new(1, 0, 0, Image().Size.Y)
		end,
		BackgroundColor3 = Theme.Colors.Code,
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = false,
		LayoutOrder = LayoutOrder,
		ImageContent = function()
			return Content.fromObject(Image())
		end,
		Activated = function()
			Chat.Zoomed(Image())
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