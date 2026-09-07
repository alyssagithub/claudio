--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

return function(Key: string)
	const function On(): boolean
		return Settings.Get(Key)() == true
	end

	return Create "TextButton" {
		Name = "Toggle",
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = function()
			return if On() then Theme.Colors.Accent() else Theme.Colors.Button()
		end,
		Text = "",
		AutoButtonColor = false,
		Activated = function()
			Settings.Set(Key, not On())
		end,

		Create "UICorner" {CornerRadius = UDim.new(1, 0)},
		Create "UIStroke" {
			Color = Theme.Colors.Border,
			Thickness = 1,
		},
		Create "Frame" {
			Name = "Knob",
			Size = UDim2.fromOffset(14, 14),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = function()
				return UDim2.new(0, if On() then 21 else 3, 0.5, 0)
			end,
			BackgroundColor3 = function()
				return if On() then Theme.Colors.AccentText() else Theme.Colors.DimText()
			end,

			Create "UICorner" {CornerRadius = UDim.new(1, 0)},
		},
	}
end