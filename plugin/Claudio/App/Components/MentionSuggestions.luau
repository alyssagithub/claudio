--!strict
const StudioService = game:GetService("StudioService")

const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

const Places = {
	workspace,
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	game:GetService("ServerStorage"),
	game:GetService("StarterGui"),
	game:GetService("StarterPlayer"),
	game:GetService("Lighting"),
}

const function Matches(): {Instance}
	const Word = Chat.Draft():match("@([%w_%.]*)$")

	if not Word then
		return {}
	end

	const Wanted = Word:lower()
	const Found = {}
	const Active = StudioService.ActiveScript

	if Active and Active.Name:lower():sub(1, #Wanted) == Wanted then
		table.insert(Found, Active)
	end

	local Scanned = 0

	for _, Place in Places do
		for _, Object in Place:GetDescendants() do
			Scanned += 1

			if #Found == 8 or Scanned > 20000 then
				return Found
			end

			if Object ~= Active and Object.Name:lower():sub(1, #Wanted) == Wanted then
				table.insert(Found, Object)
			end
		end
	end

	return Found
end

const function Row(Object: () -> Instance, Index: number)
	return Create "TextButton" {
		Name = "Mention",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Button,
		TextColor3 = Theme.Colors.ButtonText,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoButtonColor = true,
		LayoutOrder = Index,
		Text = function()
			return `{Object().Name}  ·  {Object():GetFullName()}`
		end,
		Activated = function()
			const Token = Context.AddInstance(Object())
			const Draft = Chat.Draft()

			Chat.Draft(`{Draft:gsub("@[%w_%.]*$", "")}{Token} `)
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
	}
end

return function()
	const Found = Vide.derive(Matches)

	return Create "Frame" {
		Name = "MentionSuggestions",
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