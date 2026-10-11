--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Covers = require(script.Parent.Parent.Covers)
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
	return Create "TextButton" {
		Name = "Suggestion",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Button,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = Index,
		Activated = function()
			Chat.Draft(`/{Command().name} `)
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
		Create "TextLabel" {
			Name = "Name",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.ButtonText,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = 1,
			Text = function()
				return `/{Command().name}`
			end,
		},
		Create "TextLabel" {
			Name = "Detail",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = 2,
			Visible = function()
				return Command().description ~= ""
			end,
			Text = function()
				return Command().description
			end,
		},
	}
end

return function()
	local Loaded: string?

	Vide.effect(function()
		const Wanted = `{Chat.ConversationId() or ""}|{Settings.Get("WorkingFolder")()}`

		if Wanted == Loaded then
			return
		end

		Loaded = Wanted
		task.spawn(Chat.LoadCommands)
	end)

	const Found = Vide.derive(Matches)

	return Create "Frame" {
		Name = "CommandSuggestions",
		Vide.action(Covers.Add),
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