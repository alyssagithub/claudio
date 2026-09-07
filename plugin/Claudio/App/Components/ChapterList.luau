--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

const function Row(Title: () -> string, LayoutOrder: number, OnClick: () -> ())
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Chapter",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() then 0 else 1
		end,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = LayoutOrder,
		Activated = OnClick,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Create "TextLabel" {
			Name = "Dash",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			LayoutOrder = 1,
			Text = "·",
		},
		Create "TextLabel" {
			Name = "Title",
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 2,
			Text = Title,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		},
	}
end

return function()
	return Create "Frame" {
		Name = "ChapterList",
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 32),
		BackgroundColor3 = Theme.Colors.Background,
		ZIndex = 90,
		Visible = Chat.ChaptersOpen,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Row(function()
			return "Session start"
		end, 1, function()
			Chat.ChaptersOpen(false)

			const ScrollTo: ((Index: number) -> ())? = Chat.ScrollTo

			if not ScrollTo then
				return
			end

			ScrollTo(1)
		end),
		Vide.indexes(Chat.Chapters, function(Chapter: () -> Types.Chapter, Index: number)
			return Row(function()
				return Chapter().title
			end, Index + 1, function()
				Chat.ChaptersOpen(false)

				const ScrollTo: ((Index: number) -> ())? = Chat.ScrollTo

				if not ScrollTo then
					return
				end

				ScrollTo(Chapter().index)
			end)
		end),
	}
end