--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Theme = require(script.Parent.Parent.Theme)
const IconButton = require(script.Parent.IconButton)

const Create = Vide.create

const function Card(Chip: () -> Types.Chip, Index: number, Remove: (string) -> ())
	return Create "Frame" {
		Name = "Attachment",
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Theme.Colors.Code,
		LayoutOrder = Index,

		Create "UICorner" {CornerRadius = UDim.new(0, 8)},
		Create "UIStroke" {
			Color = Theme.Colors.Border,
			Thickness = 1,
			Transparency = 0.15,
		},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "ImageLabel" {
			Name = "Preview",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Crop,
			Visible = function()
				return Chip().Preview ~= nil
			end,
			ImageContent = function()
				const Preview = Chip().Preview

				return if Preview then Content.fromObject(Preview) else Content.none
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		},
		Create "TextLabel" {
			Name = "Loading",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			Text = "…",
			Visible = function()
				return Chip().Preview == nil
			end,
		},
		Create "Frame" {
			Name = "Corner",
			Size = UDim2.fromOffset(22, 22),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,

			IconButton {
				Icon = Config.Icons.Close,
				Size = Settings.SmallText,
				OnClick = function()
					Remove(Chip().Token :: string)
				end,
			},
		},
	}
end

return function(Remove: (string) -> ())
	const Pictures = Vide.derive(function()
		const Found = {}

		for _, Chip in Context.Chips() do
			if Chip.Kind == "image" then
				table.insert(Found, Chip)
			end
		end

		return Found
	end)

	return Create "Frame" {
		Name = "Attachments",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Visible = function()
			return #Pictures() > 0
		end,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		Vide.indexes(Pictures, function(Chip, Index)
			return Card(Chip, Index, Remove)
		end),
	}
end