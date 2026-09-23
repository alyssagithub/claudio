--!strict
const RunService = game:GetService("RunService")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Context = require(script.Parent.Parent.Parent.Store.Context)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)
const StatusBar = require(script.Parent.Parent.Components.StatusBar)
const UpdateBanner = require(script.Parent.Parent.Components.UpdateBanner)
const MessageList = require(script.Parent.Parent.Components.MessageList)
const InputBar = require(script.Parent.Parent.Components.InputBar)
const ChatList = require(script.Parent.Parent.Components.ChatList)
const SubagentView = require(script.Parent.Parent.Components.SubagentView)
const PlanBar = require(script.Parent.Parent.Components.PlanBar)
const QuestionCard = require(script.Parent.Parent.Components.QuestionCard)
const GalleryBar = require(script.Parent.Parent.Components.GalleryBar)
const SettingsPage = require(script.Parent.Parent.Components.SettingsPage)
const ContextMenu = require(script.Parent.Parent.Components.ContextMenu)
const Tooltip = require(script.Parent.Parent.Components.Tooltip)
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

	local Styled = false

	Vide.effect(function()
		Settings.Get("OutputStyle")()
		Settings.Get("StepDown")()

		if Styled then
			task.spawn(Client.PushStyle)
		end

		Styled = true
	end)

	if not RunService:IsRunning() and Picker.Installed() then
		Picker.Remove()
	end

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

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			},
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
			}),
			Create "Frame" {
				Name = "Messages",
				Size = UDim2.fromScale(1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Visible = function()
					return not Chat.SettingsOpen() and not Chat.ListOpen()
				end,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				},
				Vide.action(function(Object: Frame)
					Vide.cleanup(Chat.WatchIdle())

					Vide.effect(function()
						const Viewing = Chat.Viewing() ~= nil

						for _, Name in {"MessageList", "InputBar"} do
							const Found = Object:FindFirstChild(Name)

							if Found and Found:IsA("GuiObject") then
								Found.Visible = not Viewing
							end
						end
					end)
				end),
				MessageList(),
				SubagentView(),
				GalleryBar(),
				QuestionCard(),
				PlanBar(),
				InputBar(),
			},
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
		Tooltip(),
		ContextMenu(),
		ModelPicker.Menu(),
		ModelPicker.EffortMenu(),
		ModelPicker.EffortHelp(),
		Create "ImageButton" {
			Name = "Zoom",
			Vide.action(Covers.Add),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.25,
			AutoButtonColor = false,
			ZIndex = 300,
			Visible = function()
				return Chat.Zoomed() ~= nil
			end,
			Activated = function()
				Chat.Zoomed(nil)
			end,

			Create "ImageLabel" {
				Name = "Big",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.94, 0.94),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 301,
				ImageContent = function()
					const Image = Chat.Zoomed()

					return if Image then Content.fromObject(Image) else Content.none
				end,
			},
		},
		ModelPicker.ModeMenu(),
		DeleteDialog(),
		RewindDialog(),
	}
end