--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "DropScreen",
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundTransparency = 1,
		ZIndex = 400,
		Visible = function()
			return Chat.Dragging() ~= "off"
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {
			Color = Theme.Colors.Accent,
			Thickness = 2,
		},
	}
end
