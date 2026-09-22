--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Covers = require(script.Parent.Parent.Covers)
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
	local Anchor: TextButton

	local Sent: any

	const function Withdraw()
		if Sent and Vide.untrack(Chat.Tip) == Sent then
			Chat.Tip(nil)
		end

		Sent = nil
	end

	Vide.effect(function()
		if not Hovered() then
			Withdraw()

			return
		end

		const Text = if Props.Disabled and Props.Disabled() then Props.DisabledTooltip or Read(Props.Tooltip) else Read(Props.Tooltip)

		Vide.untrack(function()
			const Window = Chat.Window

			if not Anchor or not Window or (Props.Tooltip == nil and Props.DisabledTooltip == nil) then
				return
			end

			const Room = Window.AbsoluteSize
			const Corner = Anchor.AbsolutePosition - Window.AbsolutePosition
			const Middle = Corner.X + Anchor.AbsoluteSize.X / 2
			const Under = Room.Y - (Corner.Y + Anchor.AbsoluteSize.Y) > 30

			Sent = {
				Text = Text,
				Where = Vector2.new(Middle, if Under then Corner.Y + Anchor.AbsoluteSize.Y + 4 else Corner.Y - 4),
				Side = if Room.X - Middle < 90 then 1 elseif Middle < 90 then 0 else 0.5,
				Below = Under,
			}
			Chat.Tip(Sent)
		end)
	end)

	Vide.cleanup(Withdraw)

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
		Vide.action(Covers.Hover(Hovered)),

		Vide.action(function(Object: TextButton)
			Anchor = Object
		end),
		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
	}
end