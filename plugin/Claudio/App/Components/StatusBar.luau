--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Config = require(script.Parent.Parent.Parent.Config)
const IconButton = require(script.Parent.IconButton)
const Button = require(script.Parent.Button)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "StatusBar",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 1,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		},
		Button {
			Text = function()
				return if Chat.ListOpen() or Chat.SettingsOpen() then "Back" else "Chats"
			end,
			LayoutOrder = 1,
			OnClick = function()
				if Chat.SettingsOpen() then
					Chat.SettingsOpen(false)

					return
				end

				if not Chat.ListOpen() then
					task.spawn(Chat.Refresh)
				end

				Chat.ListOpen(not Chat.ListOpen())
			end,
		},
		Create "TextLabel" {
			Name = "Title",
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 2,
			Text = function()
				if Chat.SettingsOpen() then
					return "Settings"
				end

				return if Chat.ListOpen() then "Chats" else Chat.Title()
			end,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		},
		IconButton {
			Icon = Config.Icons.Pin,
			LayoutOrder = 3,
			Tooltip = "Chapters",
			Visible = function()
				return #Chat.Chapters() > 0 and not Chat.ListOpen() and not Chat.SettingsOpen()
			end,
			Active = Chat.ChaptersOpen,
			OnClick = function()
				Chat.ChaptersOpen(not Chat.ChaptersOpen())
			end,
		},
		IconButton {
			Icon = Config.Icons.Settings,
			LayoutOrder = 4,
			OnClick = function()
				Chat.ListOpen(false)
				Chat.SettingsOpen(not Chat.SettingsOpen())
			end,
		},
		Button {
			Text = "New",
			Primary = true,
			LayoutOrder = 5,
			OnClick = Chat.New,
		},
	}
end