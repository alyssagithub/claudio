--!strict
const RunService = game:GetService("RunService")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Theme = require(script.Parent.Parent.Theme)
const StatusBar = require(script.Parent.Parent.Components.StatusBar)
const UpdateBanner = require(script.Parent.Parent.Components.UpdateBanner)
const MessageList = require(script.Parent.Parent.Components.MessageList)
const InputBar = require(script.Parent.Parent.Components.InputBar)
const ChatList = require(script.Parent.Parent.Components.ChatList)
const TaskList = require(script.Parent.Parent.Components.TaskList)
const PlanBar = require(script.Parent.Parent.Components.PlanBar)
const SettingsPage = require(script.Parent.Parent.Components.SettingsPage)
const ContextMenu = require(script.Parent.Parent.Components.ContextMenu)
const ModelPicker = require(script.Parent.Parent.Components.ModelPicker)
const ChapterList = require(script.Parent.Parent.Components.ChapterList)
const Picker = require(script.Parent.Parent.Parent.Picker)
const DeleteDialog = require(script.Parent.Parent.Components.DeleteDialog)
const RewindDialog = require(script.Parent.Parent.Components.RewindDialog)

const Create = Vide.create

return function()
	task.spawn(Chat.Resume)
	task.spawn(Chat.Refresh)
	task.spawn(Chat.RefreshUsage)
	task.spawn(Chat.CheckVersions)

	Vide.effect(function()
		if RunService:IsRunning() then
			return
		end

		if Settings.Get("PlaytestPicker")() then
			Picker.Install()
		elseif Picker.Installed() then
			Picker.Remove()
		end
	end)

	Picker.Watch(function(Label: string, Description: string)
		const Token = Context.AddRuntime(Label, Description)

		const Insert: ((string) -> ())? = Chat.Insert

		if Insert and not Chat.Draft():find(Token, 1, true) then
			Insert(Token)
		end

		Chat.Say(`Added {Label} from the playtest.`)
	end)

	Vide.cleanup(Picker.Unwatch)

	Vide.effect(function()
		const Message = Context.Notice()

		if not Message then
			return
		end

		Chat.Say(Message)
		task.defer(Context.Notice, nil)
	end)

	return Create "Frame" {
		Name = "ChatPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,

		Create "Frame" {
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
			StatusBar(),
			UpdateBanner(),
			Vide.switch(function()
				if Chat.SettingsOpen() then
					return "Settings"
				end

				return if Chat.ListOpen() then "List" else "Messages"
			end)({
				Settings = SettingsPage,
				List = ChatList,
				Messages = function()
					return {
						MessageList(),
						TaskList(),
						PlanBar(),
						InputBar(),
					}
				end,
			}),
			Create "TextLabel" {
				Name = "Notice",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 4,
				Visible = function()
					return Chat.Notice() ~= nil
				end,
				Text = function()
					return Chat.Notice() or ""
				end,

				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				},
			},
		},
		ChapterList(),
		ContextMenu(),
		ModelPicker.Menu(),
		ModelPicker.EffortMenu(),
		ModelPicker.ModeMenu(),
		DeleteDialog(),
		RewindDialog(),
	}
end