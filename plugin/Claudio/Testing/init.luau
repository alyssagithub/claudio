--!strict
const PluginGuiService = game:GetService("PluginGuiService")
const ServerScriptService = game:GetService("ServerScriptService")

export type Progress = {
	Known: {[string]: boolean},
	Made: {[string]: boolean},
	Snapshotted: boolean,
	Mount: Instance?,
}

const function Import(Target: Instance): any
	const Ok, Module = pcall(require, Target)

	if not Ok then
		error(Module, 0)
	end

	return Module
end

const Testing = {}

const function State(): Progress
	if not _G.ClaudioTestState then
		_G.ClaudioTestState = {
			Known = {},
			Made = {},
			Snapshotted = false,
		}
	end

	return _G.ClaudioTestState :: any
end

const function Beside(): Instance?
	const Mounted = State().Mount

	if Mounted == nil or not (Mounted :: Instance):IsDescendantOf(game) then
		return nil
	end

	return Mounted
end

const function Note()
	const Folder = Beside()
	const Progress = State()

	if not Folder or not Progress.Snapshotted then
		return
	end

	const Id = Import((Folder :: any).Store.Chat).ConversationId()

	if Id and not Progress.Known[Id] then
		Progress.Made[Id] = true
	end
end

function Testing.Refresh(): any
	const Home = script.Parent
	const Fresh = script:Clone()

	script:Destroy()
	Fresh.Parent = Home

	return Import(Fresh)
end

function Testing.Leftovers(): string
	const Found = {}
	const Source = script.Parent :: Instance
	const Mounted = Beside()

	const function Ours(Object: Instance): boolean
		return Object:IsDescendantOf(Source) or Object == Source or (Mounted ~= nil and (Object == Mounted or Object:IsDescendantOf(Mounted :: Instance)))
	end

	const function Walk(Object: Instance)
		for _, Child in Object:GetChildren() do
			if Child == PluginGuiService then
				continue
			end

			if Child.Name:match("^Claudio") and not Ours(Child) then
				table.insert(Found, Child:GetFullName())
			end

			if not Ours(Child) then
				Walk(Child)
			end
		end
	end

	Walk(game)

	const Siblings: {Instance} = if Source.Parent then Source.Parent:GetChildren() else {}

	for _, Child in Siblings do
		if Child.Name:match("Testing$") and Child ~= Mounted then
			table.insert(Found, `extra mount at {Child:GetFullName()}`)
		end
	end

	if ServerScriptService:FindFirstChild("ClaudioPickerServer") then
		table.insert(Found, "the playtest picker is installed in ServerScriptService")
	end

	const Widget = PluginGuiService:FindFirstChild("ClaudioTestWidget")
	local Pages = 0

	const Shown: {Instance} = if Widget then Widget:GetChildren() else {}

	for _, Child in Shown do
		if Child.Name ~= "DropTarget" then
			Pages += 1
		end
	end

	if Pages > 1 then
		table.insert(Found, `{Pages} pages stacked in the test widget`)
	end

	return if #Found == 0 then "Nothing left behind" else table.concat(Found, "\n")
end

function Testing.Open(Title: string): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	const Listed, Result = Import((Folder :: any).Client.Client).ListConversations()

	if not Listed then
		return `Could not list chats: {Result}`
	end

	for _, Summary in Result.conversations do
		if Summary.title:lower():find(Title:lower(), 1, true) then
			Import((Folder :: any).Store.Chat).Open(Summary.id)

			return `Opened "{Summary.title}"`
		end
	end

	return `No chat matches "{Title}"`
end

function Testing.Find(Name: string): Instance?
	const Widget = PluginGuiService:FindFirstChild("ClaudioTestWidget")

	return if Widget then Widget:FindFirstChild(Name, true) else nil
end

function Testing.Discard(): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	Note()

	const Chat = Import((Folder :: any).Store.Chat)
	const Id = Chat.ConversationId()

	if not Id then
		return "No chat is open"
	end

	if not State().Made[Id] then
		return `Left {Id} alone because this mount did not create it`
	end

	const Ok = Import((Folder :: any).Client.Client).DeleteConversation(Id)

	State().Made[Id] = nil

	Chat.New()

	return if Ok then `Deleted {Id}` else `Could not delete {Id}`
end

function Testing.Keep(): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted, so there is nothing to hand over"
	end

	Note()

	const Chat = Import((Folder :: any).Store.Chat)
	local Count = 0

	for _ in State().Made do
		Count += 1
	end

	table.clear(State().Made)
	Chat.SettingsOpen(false)
	Chat.ListOpen(false)

	if Chat.Window then
		Chat.Window.Enabled = true
	end

	return `Left the mount running on "{Chat.Title()}", keeping {Count} chat{if Count == 1 then "" else "s"}`
end

function Testing.Unmount(): string
	Note()

	const Folder = Beside()
	const Removed = {}

	if Folder then
		const Client = Import((Folder :: any).Client.Client)

		for Id in State().Made do
			table.insert(Removed, if Client.DeleteConversation(Id) then Id else `{Id} (failed)`)
		end
	end

	table.clear(State().Made)
	table.clear(State().Known)
	State().Snapshotted = false

	if _G.ClaudioTestApp then
		pcall((_G.ClaudioTestApp :: {Destroy: () -> ()}).Destroy)

		_G.ClaudioTestApp = nil
	end

	const Widget = PluginGuiService:FindFirstChild("ClaudioTestWidget")

	const Open: {Instance} = if Widget then Widget:GetChildren() else {}

	for _, Child in Open do
		Child:Destroy()
	end

	if Widget then
		(Widget :: DockWidgetPluginGui).Enabled = false
	end

	pcall(function()
		require((script :: any).ToolbarStub).Retire()
	end)

	if not Folder then
		return "Nothing was mounted"
	end

	pcall(function()
		Import((Folder :: any).Watcher).Stop()
	end)
	pcall(function()
		Import((Folder :: any).Store.Chat).Unload()
	end)

	const Where = Folder:GetFullName()

	Folder:Destroy()
	State().Mount = nil

	return `Unmounted {Where}, deleted {#Removed} test chat{if #Removed == 1 then "" else "s"}`
end

function Testing.Mount(CurrentPlugin: Plugin): string
	Testing.Unmount()

	const Source = script.Parent :: Instance
	const Home = Source.Parent

	if not Home then
		return "Claudio needs a parent folder so the test copy can sit beside it"
	end

	const Copy = Source:Clone() :: any
	const Session = math.random(10000000, 99999999)

	Copy.Name = `{Source.Name}Testing`
	Copy.Plugin:Destroy()
	Copy.Testing:Destroy()
	Copy.App.App.Source = Copy.App.App.Source:gsub('"ClaudioPasteImage"', `"ClaudioPasteImage{Session}"`)

	for _, Call in {
		"Window",
		"Button",
		"Bar",
	} do
		Copy.App.App.Source = Copy.App.App.Source:gsub(`{Call}:Destroy%(%)`, "")
	end

	const Stubs: {[string]: Instance} = {
		Widget = (script :: any).WidgetStub,
		Toolbar = (script :: any).ToolbarStub,
	}

	for Name, Replacement in Stubs do
		const Stub = Replacement:Clone()

		Copy.App[Name]:Destroy()
		Stub.Name = Name
		Stub.Parent = Copy.App
	end

	Copy.Parent = Home
	State().Mount = Copy

	Import(Copy.Settings).Load(CurrentPlugin)
	Import(Copy.Watcher).Start()

	_G.ClaudioTestApp = Import(Copy.App.App).New(CurrentPlugin)

	const Listed, Result = Import(Copy.Client.Client).ListConversations()

	if Listed then
		for _, Summary in Result.conversations do
			State().Known[Summary.id] = true
		end

		State().Snapshotted = true
	end

	return `Mounted {Copy:GetFullName()}{if State().Snapshotted then "" else " — the bridge did not answer, so test chats will not be cleaned up automatically"}`
end

function Testing.Ask(Text: string, Timeout: number?): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	const Chat = Import((Folder :: any).Store.Chat)
	const Deadline = os.clock() + (Timeout or 180)

	Chat.Send(Text)

	while Chat.Sending() and os.clock() < Deadline and task.wait(0.2) do
	end

	Note()

	if Chat.Sending() then
		return "Timed out waiting for a reply"
	end

	const Messages = Chat.Messages()
	const Last = Messages[#Messages]

	return if Last and Last.Role == "assistant" then Last.Text else ""
end

function Testing.Transcript(): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	const Lines = {}

	for _, Message in Import((Folder :: any).Store.Chat).Messages() do
		table.insert(Lines, `{Message.Role}: {Message.Text}`)
	end

	return if #Lines == 0 then "No messages" else table.concat(Lines, "\n")
end

function Testing.With(Values: {[string]: any}, Run: () -> ())
	const Folder = Beside()

	if not Folder then
		error("Mount before changing settings, so the test copy is the one being changed")
	end

	const Settings = Import((Folder :: any).Settings)
	const Before = {}

	for Key, Value in Values do
		Before[Key] = Settings.Get(Key)()
		Settings.Set(Key, Value)
	end

	const Outcome = table.pack(pcall(Run))

	for Key, Value in Before do
		Settings.Set(Key, Value)
	end

	if not Outcome[1] then
		error(Outcome[2])
	end
end

return Testing