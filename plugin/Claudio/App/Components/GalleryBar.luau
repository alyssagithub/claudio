--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Gallery = require(script.Parent.Parent.Parent.Store.Gallery)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

return function()
	const function Live()
		return Gallery.Live()
	end

	const function Working(): boolean
		return Chat.Sending()
	end

	const function ShowWorking(On: boolean)
		if not On then
			Chat.Sending(false)
			Chat.Began(0)
			Chat.Activity({})
			Chat.StreamingText("")
			Chat.StreamingThinking("")

			return
		end

		const Held = Live()

		Chat.Activity(Held.Activity)
		Chat.StreamingText(Held.StreamingText)
		Chat.StreamingThinking(Held.StreamingThinking)
		Chat.Began(os.clock() - 24)
		Chat.Sending(true)
	end

	const Switches = {
		{
			Name = "Working",
			On = Working,
			Set = ShowWorking,
		},
		{
			Name = "Tasks",
			On = function()
				return #Chat.Tasks() > 0
			end,
			Set = function(On: boolean)
				Chat.Tasks(if On then Live().Tasks else {})
			end,
		},
		{
			Name = "Queued",
			On = function()
				return #Chat.Queue() > 0
			end,
			Set = function(On: boolean)
				Chat.Queue(if On then Live().Queue else {})
			end,
		},
		{
			Name = "Permission",
			On = function()
				return Chat.Permission() ~= nil
			end,
			Set = function(On: boolean)
				Chat.Permission(if On then Live().Permission else nil)
			end,
		},
		{
			Name = "Question",
			On = function()
				return Chat.Question() ~= nil
			end,
			Set = function(On: boolean)
				Chat.Question(if On then Live().Question else nil)
			end,
		},
	}

	const function Toggle(Switch: any, Order: number)
		return Create "TextButton" {
			Name = Switch.Name,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = function()
				return if Switch.On() then Theme.Colors.Accent() else Theme.Colors.Button()
			end,
			TextColor3 = function()
				return if Switch.On() then Theme.Colors.AccentText() else Theme.Colors.ButtonText()
			end,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			AutoButtonColor = true,
			LayoutOrder = Order,
			Text = Switch.Name,
			Activated = function()
				Switch.Set(not Switch.On())
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			},
		}
	end

	return Create "Frame" {
		Name = "GalleryBar",
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Visible = function()
			return Gallery.Testing and Chat.ConversationId() == Gallery.Id
		end,

		Create "UIPadding" {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
			Padding = UDim.new(0, 4),
		},
		Vide.indexes(function()
			return Switches
		end, function(Switch: () -> any, Index: number)
			return Toggle(Switch(), Index)
		end),
	}
end