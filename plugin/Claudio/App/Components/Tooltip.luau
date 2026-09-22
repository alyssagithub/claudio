--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

return function()
	return Create "TextLabel" {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.Colors.Background,
		TextColor3 = Theme.Colors.Text,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		ZIndex = 400,
		Visible = function()
			return Chat.Tip() ~= nil
		end,
		AnchorPoint = function()
			const Held = Chat.Tip()

			return if Held then Vector2.new(Held.Side, if Held.Below then 0 else 1) else Vector2.zero
		end,
		Position = function()
			const Held = Chat.Tip()

			return if Held then UDim2.fromOffset(Held.Where.X, Held.Where.Y) else UDim2.fromOffset(0, 0)
		end,
		Text = function()
			const Held = Chat.Tip()

			return if Held then Held.Text else ""
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
	}
end