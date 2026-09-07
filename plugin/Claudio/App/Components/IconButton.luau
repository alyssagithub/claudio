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
	const Below = Vide.source(true)
	const Side = Vide.source(0.5)
	local Anchor: TextButton

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

			if Anchor then
				const Screen = Anchor:FindFirstAncestorWhichIsA("LayerCollector")
				const Bottom = if Screen then Screen.AbsolutePosition.Y + Screen.AbsoluteSize.Y else math.huge
				const Right = if Screen then Screen.AbsolutePosition.X + Screen.AbsoluteSize.X else math.huge
				const Left = if Screen then Screen.AbsolutePosition.X else -math.huge
				const Middle = Anchor.AbsolutePosition.X + Anchor.AbsoluteSize.X / 2

				Below(Bottom - (Anchor.AbsolutePosition.Y + Anchor.AbsoluteSize.Y) > 30)

				if Right - Middle < 90 then
					Side(1)
				elseif Middle - Left < 90 then
					Side(0)
				else
					Side(0.5)
				end
			end
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Vide.action(function(Object: TextButton)
			Anchor = Object
		end),

		Create "TextLabel" {
			Name = "Tooltip",
			AnchorPoint = function()
				return Vector2.new(Side(), if Below() then 0 else 1)
			end,
			Position = function()
				return UDim2.new(Side(), 0, if Below() then 1 else 0, if Below() then 4 else -4)
			end,
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