--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Changes = require(script.Parent.Parent.Parent.Changes)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)

const Create = Vide.create

const function Planned(): boolean
	if Settings.Get("Mode")() ~= "plan" or Chat.Sending() then
		return false
	end

	const Messages = Chat.Messages()
	const Last = Messages[#Messages]

	return Last ~= nil and Last.Role == "assistant" and Last.Text ~= ""
end

const function Untouched(): boolean
	for _, Message in Chat.Messages() do
		if #Changes.For(Message) > 0 then
			return false
		end
	end

	return true
end

return function()
	return Create "Frame" {
		Name = "PlanBar",
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 3,
		Visible = function()
			return Planned()
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Button},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
		Create "TextLabel" {
			Name = "Note",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = 1,
			Text = "Nothing has been changed yet",
			Visible = function()
				return Untouched()
			end,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		},
		Button {
			Text = "Run this plan",
			Primary = true,
			LayoutOrder = 2,
			OnClick = function()
				Settings.Set("Mode", "auto")
				Chat.Send("Carry out that plan now.")
			end,
		},
	}
end