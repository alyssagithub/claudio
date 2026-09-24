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

const Shielded = {"Obsidian Vault"}

const function ShieldOver(Folder: string?): string?
	if not Folder then
		return nil
	end

	const Name = Folder:match("[^\\/]+$") or Folder

	return if table.find(Shielded, Name) then Name else nil
end

const function FolderOf(Mounted: Instance, Id: string): string?
	const Listed, Result = Import((Mounted :: any).Client.Client).ListConversations()

	if not Listed then
		return nil
	end

	for _, Summary in Result.conversations do
		if Summary.id == Id then
			return Summary.folder
		end
	end

	return nil
end

const function Kept(Name: string): string
	return `Refused, because this chat works in {Name}, and the testing mount never touches a chat that works there. That folder is where the user's own sessions run, so a test that sends, opens or discards one of them lands in a conversation they are reading and working in. Call Testing.NewChat() with the mount's working folder set somewhere else and test there.`
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

const function Owned(): (boolean, string)
	const Folder = Beside()

	if not Folder then
		return false, "Nothing is mounted"
	end

	const Id = Import((Folder :: any).Store.Chat).ConversationId()

	if Id == nil then
		return true, ""
	end

	const Shield = ShieldOver(FolderOf(Folder, Id))

	if Shield then
		return false, Kept(Shield)
	end

	if State().Made[Id] then
		return true, ""
	end

	return false, "Refused, because this chat was not started by the testing mount. The mount shares one conversation store with the real plugin, so a message sent here lands in a chat the user is reading and working in, and bills them for it. Call Testing.NewChat() to start one the mount owns, then ask again."
end

function Testing.NewChat(): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	const Shield = ShieldOver(Import((Folder :: any).Settings).Get("WorkingFolder")())

	if Shield then
		return `Refused, because the mount's working folder is {Shield}, and the testing mount never starts a chat there. Set the mount's WorkingFolder to a project folder first, then call Testing.NewChat() again.`
	end

	Import((Folder :: any).Store.Chat).New()

	return "Started a chat the testing mount owns, so asking is allowed again"
end

function Testing.RunTests(): string
	const Mounted = Beside()

	if not Mounted then
		return "Nothing is mounted, call Testing.Mount(plugin) first"
	end

	const TestEZ = Import((Mounted :: any).Packages.testez)
	const Results = TestEZ.TestBootstrap:run({(Mounted :: any).Tests}, TestEZ.Reporters.TextReporter)
	const Lines = {`{Results.successCount} passed, {Results.failureCount} failed, {Results.skippedCount} skipped`}

	for _, Message in Results.errors do
		table.insert(Lines, Message)
	end

	return table.concat(Lines, "\n")
end

function Testing.Refresh(): any
	const Fresh = script:Clone()
	const Loaded = Import(Fresh)

	Fresh:Destroy()

	return Loaded
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
			const Shield = ShieldOver(Summary.folder)

			if Shield then
				return Kept(Shield)
			end

			if not State().Made[Summary.id] then
				return `Refused, because "{Summary.title}" was not started by the testing mount. The mount shares one conversation store with the real plugin, so opening a chat the user owns puts the mount inside the conversation they are reading and working in, one send away from posting to it. Call Testing.NewChat() and test in a chat of your own.`
			end

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

	const Shield = ShieldOver(FolderOf(Folder, Id))

	if Shield then
		return `Left {Id} alone because it works in {Shield}`
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
		require(script.ToolbarStub).Retire()
	end)

	const Source = script.Parent :: Instance
	const Siblings: {Instance} = if Source.Parent then Source.Parent:GetChildren() else {}
	local Stale = 0

	for _, Sibling in Siblings do
		if Sibling.Name == `{Source.Name}Testing` and Sibling ~= Folder then
			Sibling:Destroy()
			Stale += 1
		end
	end

	if not Folder then
		return if Stale > 0 then `Removed {Stale} mount{if Stale == 1 then "" else "s"} left by an earlier plugin` else "Nothing was mounted"
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
		Widget = script.WidgetStub,
		Toolbar = script.ToolbarStub,
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

	Import(Copy.Store.Chat).New()

	return `Mounted {Copy:GetFullName()}{if State().Snapshotted then "" else " — the bridge did not answer, so test chats will not be cleaned up automatically"}`
end

function Testing.Paint(Name: string?): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	const Theme = Import((Folder :: any).App.Theme)

	if not Name then
		Theme.Paint(nil)

		return `Painting with Studio's own theme again, which is {(settings().Studio :: any).Theme.Name}`
	end

	const Offered = {}

	for _, Choice in settings().Studio:GetAvailableThemes() do
		if Choice.Name == Name then
			Theme.Paint(Choice)

			return `Painting the mount as {Choice.Name} while Studio stays on {(settings().Studio :: any).Theme.Name}`
		end

		table.insert(Offered, Choice.Name)
	end

	return `No theme called "{Name}", try one of {table.concat(Offered, ", ")}`
end

function Testing.Colours(Name: string?): {string}
	const Widget = PluginGuiService:FindFirstChild("ClaudioTestWidget")

	if not Widget then
		return {"Nothing is mounted"}
	end

	const Root = if Name then Widget:FindFirstChild(Name, true) else Widget

	if not Root then
		return {`Found nothing called "{Name}"`}
	end

	const Counts: {[string]: number} = {}
	const Where: {[string]: string} = {}

	const function Note(Object: Instance, Property: string, Colour: Color3)
		const Key = `{math.round(Colour.R * 255)},{math.round(Colour.G * 255)},{math.round(Colour.B * 255)} {Property}`

		Counts[Key] = (Counts[Key] or 0) + 1
		Where[Key] = Where[Key] or `{Object.Name}`
	end

	for _, Object in Root:GetDescendants() do
		if not Object:IsA("GuiObject") then
			continue
		end

		if Object.BackgroundTransparency < 1 then
			Note(Object, "background", Object.BackgroundColor3)
		end

		if Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
			Note(Object, "text", (Object :: any).TextColor3)
		end

		if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
			Note(Object, "image", (Object :: any).ImageColor3)
		end

		const Stroke = Object:FindFirstChildOfClass("UIStroke")

		if Stroke then
			Note(Object, "stroke", Stroke.Color)
		end
	end

	const Lines = {}

	for Key, Count in Counts do
		table.insert(Lines, `{Key} x{Count} (first on {Where[Key]})`)
	end

	table.sort(Lines)

	return Lines
end

function Testing.Ask(Text: string, Timeout: number?): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	const Allowed, Why = Owned()

	if not Allowed then
		return Why
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

	for Key in Values do
		Before[Key] = Settings.Get(Key)()
	end

	for Key, Value in Values do
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