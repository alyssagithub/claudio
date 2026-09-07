--!strict
const RunService = game:GetService("RunService")
const Vide = require(script.Parent.Parent.Packages.vide)
const Client = require(script.Parent.Parent.Client.Client)
const Settings = require(script.Parent.Parent.Settings)
const Connection = require(script.Parent.Parent.Store.Connection)
const Chat = require(script.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Theme)
const Toolbar = require(script.Parent.Toolbar)
const Widget = require(script.Parent.Widget)
const Attention = require(script.Parent.Attention)
const Picker = require(script.Parent.Parent.Picker)
const Context = require(script.Parent.Parent.Store.Context)
const Pages = {
	Disconnected = require(script.Parent.Pages.Disconnected),
	Connecting = require(script.Parent.Pages.Connecting),
	Connected = require(script.Parent.Pages.Chat),
	Error = require(script.Parent.Pages.Error),
	Folder = require(script.Parent.Pages.Folder),
}

const App = {}

function App.New(CurrentPlugin: Plugin)
	Theme.Init()

	const Window = Widget.Create(CurrentPlugin)
	const Bar, Button = Toolbar.Create(CurrentPlugin, function()
		Window.Enabled = not Window.Enabled
	end)
	Chat.Window = Window

	Button:SetActive(Window.Enabled)
	Chat.ReplyListener = Attention.Notify

	const EnabledConnection = Window:GetPropertyChangedSignal("Enabled"):Connect(function()
		Button:SetActive(Window.Enabled)

		if Window.Enabled and Connection.Status() ~= "Connected" then
			task.spawn(Client.Connect)
		end
	end)

	const Highlight = Vide.source(false)

	const function FromExplorer(Data: any): boolean
		return typeof(Data) == "table" and Data.Sender == "Explorer"
	end

	const DragEntered = Window.PluginDragEntered:Connect(function(Data)
		if FromExplorer(Data) then
			Highlight(true)
		end
	end)

	const DragLeft = Window.PluginDragLeft:Connect(function()
		Highlight(false)
	end)

	const DragDropped = Window.PluginDragDropped:Connect(function(Data)
		Highlight(false)

		if not FromExplorer(Data) then
			return
		end

		const Token = Context.AddSelection()

		if not Token then
			return
		end

		const Insert: ((string) -> ())? = Chat.Insert

		if Insert and not Chat.Draft():find(Token, 1, true) then
			Insert(Token)
		end
	end)

	const PasteAction = CurrentPlugin:CreatePluginAction("ClaudioPasteImage", "Claudio: paste image", "Attach the image on the clipboard to the Claudio message box", "", true)

	const PasteConnection = PasteAction.Triggered:Connect(function()
		task.spawn(Chat.PasteImage)
	end)

	const Unmount = Vide.mount(function()
		Vide.create "Frame" {
			Name = "DropTarget",
			Parent = Window,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.Accent,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			ZIndex = 500,
			Visible = Highlight,

			Vide.create "UIStroke" {
				Color = Theme.Colors.Accent,
				Thickness = 2,
			},
			Vide.create "TextLabel" {
				Name = "Hint",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Background,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				ZIndex = 501,
				Text = "Drop to attach",

				Vide.create "UICorner" {CornerRadius = UDim.new(0, 6)},
				Vide.create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				},
			},
		}

		return Vide.switch(function()
			const Status = Connection.Status()

			if Status == "Connected" and Settings.Get("WorkingFolder")() == "" then
				return "Folder"
			end

			return Status
		end)(Pages)
	end, Window)

	if Window.Enabled then
		task.spawn(Client.Connect)
	end

	return {
		Destroy = function()
			Chat.ReplyListener = nil
			Chat.Window = nil
			Chat.Unload()
			PasteConnection:Disconnect()
			DragEntered:Disconnect()
			DragLeft:Disconnect()
			DragDropped:Disconnect()
			EnabledConnection:Disconnect()
			Unmount()

			if RunService:IsRunning() then
				Window.Enabled = false
			else
				Window:Destroy()
				Button:Destroy()
				Bar:Destroy()
			end
			Picker.Unwatch()
			Picker.Remove()
			Theme.Destroy()
		end,
	}
end

return App