--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)
const IconButton = require(script.Parent.IconButton)
const Selectable = require(script.Parent.Selectable)

const Create = Vide.create

export type Props = {
	Name: string,
	Text: () -> string,
	Rich: () -> string,
	LayoutOrder: any,
	Small: boolean?,
	Bare: boolean?,
	Colour: (() -> Color3)?,
	Visible: (() -> boolean)?,
}

return function(Props: Props)
	const Hovered = Vide.source(false)
	const Copied = Vide.source(false)
	local Presses = 0

	return Create "Frame" {
		Name = Props.Name,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Code,
		BackgroundTransparency = if Props.Bare then 1 else 0,
		LayoutOrder = Props.LayoutOrder,
		Visible = Props.Visible,

		Vide.action(Covers.Hover(Hovered)),
		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Selectable {
			Name = "Code",
			Font = Enum.Font.Code,
			Size = if Props.Small then Settings.SmallText else Settings.TextSize,
			Colour = Props.Colour or Theme.Colors.CodeText,
			Text = Props.Rich,
			Children = {
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, if Props.Bare then 0 else 8),
					PaddingRight = UDim.new(0, 30),
					PaddingTop = UDim.new(0, if Props.Bare then 2 else 6),
					PaddingBottom = UDim.new(0, if Props.Bare then 2 else 6),
				},
			},
		},
		Create "Frame" {
			Name = "Corner",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			ZIndex = 3,
			Visible = function()
				return Hovered() or Copied()
			end,

			IconButton {
				Icon = function()
					return if Copied() then Config.Icons.Chosen else Config.Icons.Copy
				end,
				Tooltip = function()
					return if Copied() then "Copied" else "Copy"
				end,
				Size = Settings.SmallText,
				OnClick = function()
					Presses += 1

					const Mine = Presses

					task.spawn(function()
						if not Client.WriteClipboard(Props.Text()) then
							return
						end

						Copied(true)
						task.wait(1.5)

						if Presses == Mine then
							Copied(false)
						end
					end)
				end,
			},
		},
	}
end