--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

const function Matches(): {Types.Command}
	const Draft = Chat.Draft()

	if Draft:sub(1, 1) ~= "/" or Draft:find("%s") then
		return {}
	end

	const Prefix = Draft:sub(2):lower()
	const Found = {}

	for _, Command in Chat.Commands() do
		if Command.name:lower():sub(1, #Prefix) == Prefix then
			table.insert(Found, Command)
		end

		if #Found == 8 then
			break
		end
	end

	return Found
end

const function Row(Command: () -> Types.Command, Index: number)
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Suggestion",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Button,
		TextColor3 = Theme.Colors.ButtonText,
		TextSize = Settings.TextSize,
		FontFace = Font.fromEnum(Enum.Font.Code),
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = true,
		LayoutOrder = Index,
		Text = function()
			return `/{Command().name}`
		end,
		Activated = function()
			Chat.Draft(`/{Command().name} `)
		end,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "TextLabel" {
			Name = "Tooltip",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Theme.Colors.Background,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 50,
			Visible = function()
				return Hovered() and Command().description ~= ""
			end,
			Text = function()
				return Command().description
			end,

			Create "UISizeConstraint" {MaxSize = Vector2.new(220, math.huge)},
			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			},
		},
	}
end

return function()
	const Found = Vide.derive(Matches)

	return Create "Frame" {
		Name = "CommandSuggestions",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Visible = function()
			return #Found() > 0
		end,

		Create "UIListLayout" {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Vide.indexes(Found, Row),
	}
end