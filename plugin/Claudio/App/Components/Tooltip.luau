--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

return function()
	const Nudge = Vide.source(0)

	return Create "TextLabel" {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.Colors.Background,
		TextColor3 = Theme.Colors.Text,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextWrapped = true,
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

			return if Held then UDim2.fromOffset(Held.Where.X + Nudge(), Held.Where.Y) else UDim2.fromOffset(0, 0)
		end,

		Vide.action(function(Object: TextLabel)
			const function Fit()
				const Window = Chat.Window

				if not Window then
					return
				end

				const Left = Object.AbsolutePosition.X - Nudge() - Window.AbsolutePosition.X
				const Right = Left + Object.AbsoluteSize.X
				const Room = Window.AbsoluteSize.X

				Nudge(if Left < 6 then 6 - Left elseif Right > Room - 6 then Room - 6 - Right else 0)
			end

			Vide.cleanup(Object:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit))
			Vide.cleanup(Object:GetPropertyChangedSignal("Text"):Connect(function()
				task.defer(Fit)
			end))
		end),
		Text = function()
			const Held = Chat.Tip()

			return if Held then Held.Text else ""
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UISizeConstraint" {
			MaxSize = function()
				return Vector2.new(if Chat.Window then math.max(80, Chat.Window.AbsoluteSize.X - 12) else 300, math.huge)
			end,
		},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
	}
end