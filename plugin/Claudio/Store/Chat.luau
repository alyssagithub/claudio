--!strict
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const RunService = game:GetService("RunService")

const Vide = require(script.Parent.Parent.Packages.vide)
const Types = require(script.Parent.Parent.Types)
const Gallery = require(script.Parent.Gallery)
const Connection = require(script.Parent.Connection)
const Error = require(script.Parent.Parent.Client.Error)
const Format = require(script.Parent.Parent.Format)
const Config = require(script.Parent.Parent.Config)
const Changes = require(script.Parent.Parent.Changes)
const Watcher = require(script.Parent.Parent.Watcher)
const Settings = require(script.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Client.Client)
const Pictures = require(script.Parent.Parent.Pictures)
const Breathe = require(script.Parent.Parent.Breathe)
const Context = require(script.Parent.Context)
const Navigate = require(script.Parent.Parent.Navigate)

local Generation = 0
local Stopping = -1
local KnownEnded = 0
local Checkpoint = 0

const Chat = {
	Messages = Vide.source({} :: {Types.Message}),
	Draft = Vide.source(""),
	StreamingText = Vide.source(""),
	StreamingThinking = Vide.source(""),
	StreamingParts = Vide.source({} :: {Types.Piece}),
	Zoomed = Vide.source(nil :: EditableImage?),
	StreamingPick = Vide.source(nil :: {Model: string, Effort: string?}?),
	StreamingImages = Vide.source({} :: {EditableImage}),
	Activity = Vide.source({} :: {string}),
	Permission = Vide.source(nil :: Types.Permission?),
	Question = Vide.source(nil :: Types.Asked?),
	Sending = Vide.source(false),
	Queue = Vide.source({} :: {Types.QueuedMessage}),
	Commands = Vide.source({} :: {Types.Command}),
	Models = Vide.source({} :: {Types.ModelInfo}),
	McpServers = Vide.source({} :: {Types.McpServer}),
	ConversationId = Vide.source(nil :: string?),
	Title = Vide.source("New chat"),
	Conversations = Vide.source({} :: {Types.ConversationSummary}),
	ListOpen = Vide.source(false),
	Listed = Vide.source(false),
	PickerOpen = Vide.source(false),
	EffortOpen = Vide.source(false),
	ModeOpen = Vide.source(false),
	SettingsOpen = Vide.source(false),
	ClipboardReady = Vide.source(false),
	Notice = Vide.source(nil :: string?),
	Restoring = Vide.source(false),
	Calls = Vide.source({} :: {Types.ToolCall}),
	Tasks = Vide.source({} :: {Types.Task}),
	Planning = Vide.source(false),
	Compacting = Vide.source(false),
	Tokens = Vide.source(nil :: Types.Tokens?),
	Elapsed = Vide.source(0),
	Began = Vide.source(0),
	Limits = Vide.source({} :: {Types.Limit}),
	ContextUsed = Vide.source(0),
	ContextWindow = Vide.source(0),
	ContextModel = Vide.source(""),
	ContextParts = Vide.source({} :: {Types.Part}),
	Tip = Vide.source(nil :: {Text: string, Where: Vector2, Side: number, Below: boolean}?),
	MenuFor = Vide.source(nil :: string?),
	MenuFolder = Vide.source(nil :: string?),
	MenuPosition = Vide.source(Vector2.zero),
	Confirming = Vide.source(nil :: string?),
	Rewinding = Vide.source(nil :: number?),
	VersionOpen = Vide.source(false),
	VersionPick = Vide.source(""),
	Renaming = Vide.source(nil :: string?),
	ShowArchived = Vide.source(false),
	ShowHidden = Vide.source(false),
	Opened = Vide.source({} :: {[string]: boolean}),
	Chapters = Vide.source({} :: {Types.Chapter}),
	Versions = Vide.source(nil :: Types.Versions?),
	Updating = Vide.source(false),
	Shown = Vide.source(40),
	Earlier = Vide.source(0),
	Partial = Vide.source(false),
	ChaptersOpen = Vide.source(false),
	Anchors = {} :: {[number]: Instance},
	Window = nil :: DockWidgetPluginGui?,
	Yielding = false,
	ScrollTo = nil :: ((Index: number) -> ())?,
	Insert = nil :: ((string) -> ())?,
	RequestId = nil :: string?,
	CurrentPrompt = "",
	ReplyListener = nil :: ((Text: string) -> ())?,
}

const function With(Record: any, Fields: {[string]: any}): any
	const Changed = table.clone(Record)

	for Key, Value in Fields do
		Changed[Key] = Value
	end

	return Changed
end

const function Replaced(List: {any}, Index: number, Value: any): {any}
	const Changed = table.clone(List)

	Changed[Index] = Value

	return Changed
end

const function Append(Message: Types.Message)
	const Messages = table.clone(Chat.Messages())

	table.insert(Messages, With(Message, {At = os.time()}))
	Chat.Messages(Messages)
end

const function DestroyImages(Images: {EditableImage}?)
	const Held: {EditableImage} = Images or {}

	for _, Image in Held do
		Image:Destroy()
	end
end

const function Reset()
	Generation += 1
	KnownEnded = 0
	Chat.Earlier(0)

	for _, Message in Chat.Messages() do
		DestroyImages(Message.Images)
	end

	DestroyImages(Chat.StreamingImages())

	for _, Queued in Chat.Queue() do
		DestroyImages(Queued.Previews)
	end

	Chat.Messages({})
	Chat.Queue({})
	Chat.StreamingText("")
	Chat.StreamingThinking("")
	Chat.StreamingParts({})
	Chat.StreamingPick(nil)
	Chat.StreamingImages({})
	Chat.Activity({})
	Chat.Calls({})
	Chat.Tokens(nil)
	Chat.Elapsed(0)
	Chat.Permission(nil)
	Chat.Question(nil)
	Chat.Sending(false)
	Chat.Began(0)
	Chat.RequestId = nil
	Chat.ContextParts({})
	Chat.ContextUsed(0)
	Chat.ContextWindow(0)
	Chat.ContextModel("")
	Chat.Opened({})
	table.clear(Chat.Anchors)
	Watcher.Reset()
end

local LintPasses = 0

const WriteTools = {
	"set_script_source",
	"edit_script_lines",
	"insert_script_lines",
	"delete_script_lines",
	"find_and_replace_in_scripts",
	"multi_edit",
}

const function Wrote(Name: string?): boolean
	for _, Tool in WriteTools do
		if Name and Name:find(Tool, 1, true) then
			return true
		end
	end

	return false
end

const function EditedScripts(): {any}
	const Wanted = {}
	const Seen: {[string]: boolean} = {}

	for _, Call in Chat.Calls() do
		const Path = if Call.input then Call.input:match("instancePath: ([^\n]+)") else nil

		if not Path or Seen[Path] or not Wrote(Call.name) then
			continue
		end

		Seen[Path] = true

		const Object = Navigate.Resolve(Path)

		if Object and Object:IsA("LuaSourceContainer") and Object.Source ~= "" then
			table.insert(Wanted, {
				path = Path,
				source = Object.Source,
			})
		end
	end

	return Wanted
end

const Places = {
	game:GetService("Workspace"),
	game:GetService("ReplicatedFirst"),
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	game:GetService("ServerStorage"),
	game:GetService("StarterGui"),
	game:GetService("StarterPack"),
	game:GetService("StarterPlayer"),
	game:GetService("Lighting"),
}

const function ScriptTree(): {any}
	const Found = {}

	for _, Service in Places do
		for _, Object in Service:GetDescendants() do
			if #Found >= 20000 then
				return Found
			end

			Breathe()

			const Parts = {}
			local Step: Instance? = Object

			while Step and Step ~= game do
				table.insert(Parts, 1, Step.Name)
				Step = Step.Parent
			end

			table.insert(Found, {
				path = Object:GetFullName(),
				parts = Parts,
				className = Object.ClassName,
				source = if Object:IsA("LuaSourceContainer") and Object.Source ~= "" then Object.Source else nil,
			})
		end
	end

	return Found
end

const Running: {[string]: boolean} = {}
local Watching = false

const function Resolve(Path: string): Instance?
	local Object: Instance? = game

	for Index, Step in string.split(Path, ".") do
		if Index == 1 and (Step == "game" or Step == "Game") then
			continue
		end

		if not Object then
			return nil
		end

		const Service = if Object == game then pcall(game.GetService, game, Step) else false
		local Next = (Object :: Instance):FindFirstChild(Step)

		if not Next and Service then
			Next = select(2, pcall(game.GetService, game, Step))
		end

		Object = Next
	end

	return Object
end

const function Sources(Root: Instance): {LuaSourceContainer}
	const Found = {}

	if Root:IsA("LuaSourceContainer") then
		table.insert(Found, Root)
	end

	for _, Object in Root:GetDescendants() do
		Breathe()

		if Object:IsA("LuaSourceContainer") then
			table.insert(Found, Object)
		end
	end

	return Found
end

const function Find(Input: any): any
	const Needle = tostring(Input.text or "")

	if Needle == "" then
		return {error = "Give some text to look for."}
	end

	const Root = if Input.path then Resolve(Input.path) else game

	if not Root then
		return {error = `Nothing at "{tostring(Input.path)}", so there was nowhere to search. Leave path out to search the whole place.`}
	end

	const Lower = Needle:lower()
	const Limit = math.clamp(tonumber(Input.limit) or 40, 1, 200)
	const Hits = {}
	local Scanned = 0
	local More = 0

	for _, Script in Sources(Root) do
		const Body = Script.Source

		Breathe()

		if Body == "" then
			continue
		end

		Scanned += 1

		local Line = 0

		for _, Text in string.split(Body, "\n") do
			Line += 1

			if Text:lower():find(Lower, 1, true) then
				if #Hits >= Limit then
					More += 1
				else
					table.insert(Hits, `{Script:GetFullName()}:{Line}: {Text:gsub("^%s+", ""):sub(1, 160)}`)
				end
			end
		end
	end

	return {
		hits = Hits,
		scanned = Scanned,
		more = More,
	}
end

const Seen: {[string]: string} = {}

local Committed = 0

const function Fingerprint(Script: LuaSourceContainer): string
	return game:GetService("EncodingService"):ComputeStringHash(Script.Source, Enum.HashAlgorithm.Sha256)
end

const function Remember(Script: LuaSourceContainer)
	Seen[Script:GetFullName()] = Fingerprint(Script)
end

const function Measured(Before: string, After: string): (number, number)
	const Old = if Before == "" then {} else string.split(Before, "\n")
	const New = if After == "" then {} else string.split(After, "\n")
	local Start = 0

	while Start < #Old and Start < #New and Old[Start + 1] == New[Start + 1] do
		Start += 1
	end

	local OldEnd = #Old
	local NewEnd = #New

	while OldEnd > Start and NewEnd > Start and Old[OldEnd] == New[NewEnd] do
		OldEnd -= 1
		NewEnd -= 1
	end

	return NewEnd - Start, OldEnd - Start
end

const function Source(Input: any): any
	const Object = Resolve(Input.path)

	if not Object or not Object:IsA("LuaSourceContainer") then
		return {error = `Nothing scriptable at "{tostring(Input.path)}".`}
	end

	const Script = Object :: LuaSourceContainer
	const Before = Script.Source
	const Lines = string.split(Script.Source, "\n")
	const Action = Input.action or "get"
	const Path = Script:GetFullName()

	if Action == "get" then
		const From = math.clamp(tonumber(Input.from) or 1, 1, math.max(1, #Lines))
		const To = math.clamp(tonumber(Input.to) or #Lines, From, #Lines)
		const Window = {}

		for Index = From, To do
			table.insert(Window, `{Index}: {Lines[Index]}`)
		end

		Remember(Script)

		return {
			path = Path,
			total = #Lines,
			lines = Window,
		}
	end

	if Action ~= "set" or Script.Source ~= "" then
		const Stamped = Seen[Path]

		if Stamped ~= Fingerprint(Script) then
			return {error = `Read {Path} before editing it, because {if Stamped then "it has changed since you last read it, so the line numbers you are holding point somewhere else now" else "nothing has read it yet, so its line numbers are a guess"}. Studio, Script Sync and other sessions all write to these scripts, and a stale line range edits the wrong lines instead of failing.`}
		end
	end

	const ChangeHistoryService = game:GetService("ChangeHistoryService")
	const Recording = ChangeHistoryService:TryBeginRecording("ClaudioSource", Input.undoName or `Claudio edited {Script.Name}`)

	const Ok, Trouble = pcall(function(): string
		if Action == "set" then
			Script.Source = tostring(Input.text)

			return Script.Source
		end

		const From = math.clamp(tonumber(Input.from) or 1, 1, #Lines + 1)

		if Action == "insert" then
			const Added = string.split(tostring(Input.text), "\n")

			for Offset = #Added, 1, -1 do
				table.insert(Lines, From, Added[Offset])
			end
		elseif Action == "replace" or Action == "delete" then
			const To = math.clamp(tonumber(Input.to) or From, From, #Lines)

			for _ = From, To do
				table.remove(Lines, From)
			end

			if Action == "replace" then
				const Added = string.split(tostring(Input.text), "\n")

				for Offset = #Added, 1, -1 do
					table.insert(Lines, From, Added[Offset])
				end
			end
		else
			error(`Claudio does not know the source action "{tostring(Action)}"`)
		end

		Script.Source = table.concat(Lines, "\n")

		return Script.Source
	end)

	if Recording then
		ChangeHistoryService:FinishRecording(Recording, if Ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end

	if not Ok then
		return {error = tostring(Trouble)}
	end

	Remember(Script)

	if Recording then
		Committed += 1
	end

	const Added, Removed = Measured(Before, Script.Source)

	return {
		text = `{Path} is now {#string.split(Script.Source, "\n")} lines. +{Added} -{Removed}`,
		added = Added,
		removed = Removed,
		undo = Recording ~= nil,
	}
end

const function Selected(Input: any): any
	const Selection = game:GetService("Selection")

	if Input.paths then
		const Wanted = {}
		const Missing = {}

		for _, Path in Input.paths do
			const Object = Resolve(Path)

			if Object then
				table.insert(Wanted, Object)
			else
				table.insert(Missing, Path)
			end
		end

		Selection:Set(Wanted)

		if #Missing > 0 then
			return {text = `Selected {#Wanted}. Could not find: {table.concat(Missing, ", ")}`}
		end

		return {text = `Selected {#Wanted}.`}
	end

	const Paths = {}

	for _, Object in Selection:Get() do
		table.insert(Paths, Object:GetFullName())
	end

	return {paths = Paths}
end

const function Steps(Input: any): any
	const ChangeHistoryService = game:GetService("ChangeHistoryService")
	const Action = Input.action or "status"
	const CanUndo = ChangeHistoryService:GetCanUndo()
	const CanRedo = ChangeHistoryService:GetCanRedo()

	if Action == "status" then
		return {text = `Undo available: {CanUndo}. Redo available: {CanRedo}.`}
	end

	if Action == "undo" then
		if not CanUndo then
			return {error = "There is nothing to undo."}
		end

		ChangeHistoryService:Undo()

		return {text = "Undid one step."}
	end

	if Action == "redo" then
		if not CanRedo then
			return {error = "There is nothing to redo."}
		end

		ChangeHistoryService:Redo()

		return {text = "Redid one step."}
	end

	if Action == "mark" then
		const Name = tostring(Input.name or "mark")

		_G.ClaudioMarks = _G.ClaudioMarks or {}
		;(_G.ClaudioMarks :: any)[Name] = Committed

		return {text = `Marked "{Name}" at {Committed} edits. Undo back to it with action restore.`}
	end

	if Action == "restore" then
		const Name = tostring(Input.name or "mark")
		const Marks = _G.ClaudioMarks :: any
		const At = if Marks then Marks[Name] else nil

		if At == nil then
			return {error = `There is no mark called "{Name}".`}
		end

		local Steps = 0

		while Committed > At and ChangeHistoryService:GetCanUndo() do
			ChangeHistoryService:Undo()

			Committed -= 1
			Steps += 1
		end

		if Committed > At then
			return {error = `Only got {Steps} steps back before Studio ran out of undo history, so "{Name}" was not fully reached. Anything older than Studio's undo limit is gone.`}
		end

		return {text = `Undid {Steps} steps back to "{Name}".`}
	end

	return {error = `Claudio does not know the history action "{tostring(Action)}".`}
end

const function Logs(Input: any): any
	const LogService = game:GetService("LogService")
	const Ok, History = pcall(function(): any
		return LogService:GetLogHistory()
	end)

	if not Ok then
		return {error = `Could not read the log: {tostring(History)}`}
	end

	const Wanted = if typeof(Input.level) == "string" then Input.level:lower() else "all"
	const Needle = if typeof(Input.contains) == "string" and Input.contains ~= "" then Input.contains:lower() else nil
	const Limit = math.clamp(tonumber(Input.limit) or 40, 1, 200)
	const Since = tonumber(Input.since)
	const Oldest = if Since then os.time() - Since else nil

	const Named = {
		[Enum.MessageType.MessageOutput] = "print",
		[Enum.MessageType.MessageInfo] = "info",
		[Enum.MessageType.MessageWarning] = "warn",
		[Enum.MessageType.MessageError] = "error",
	}

	const Kept = {}
	local Seen = 0
	local Skipped = 0

	for Index = #History, 1, -1 do
		const Entry = History[Index]
		const Kind = Named[Entry.messageType] or "print"

		Seen += 1

		if Wanted == "problems" then
			if Kind ~= "warn" and Kind ~= "error" then
				continue
			end
		elseif Wanted ~= "all" and Kind ~= Wanted then
			continue
		end

		if Oldest and Entry.timestamp < Oldest then
			continue
		end

		const Message = tostring(Entry.message)

		if Needle and not Message:lower():find(Needle, 1, true) then
			continue
		end

		if #Kept >= Limit then
			Skipped += 1

			continue
		end

		table.insert(Kept, `{Kind}: {if #Message > 400 then `{Message:sub(1, 400)} [cut]` else Message}`)
	end

	const Lines = {}

	for Index = #Kept, 1, -1 do
		table.insert(Lines, Kept[Index])
	end

	return {
		lines = Lines,
		scanned = Seen,
		skipped = Skipped,
	}
end

const function LintPlace(Paths: {string}?): any
	const Tree = ScriptTree()

	if #Tree == 0 then
		return {
			checked = 0,
			scripts = {},
		}
	end

	local Wanted = Tree

	if Paths and #Paths > 0 then
		Wanted = {}

		for _, Entry in Tree do
			for _, Path in Paths do
				if Entry.path == Path or Entry.path:sub(1, #Path + 1) == `{Path}.` then
					table.insert(Wanted, Entry)

					break
				end
			end
		end
	end

	if #Wanted == 0 then
		return {error = "Nothing in the place matched those paths, so there was nothing to check."}
	end

	const Checked = {}

	for _, Entry in Wanted do
		Checked[Entry] = true
	end

	for _, Entry in Tree do
		if Entry.className ~= "ModuleScript" and not Checked[Entry] then
			Entry.source = nil
		end
	end

	const Ok, Result = Client.Lint(Wanted, Tree)

	if not Ok then
		return {error = `The analyzer could not run: {tostring(Result)}`}
	end

	return {
		checked = #Wanted,
		scripts = Result.scripts,
	}
end

const function Playtest(Input: any): any
	const StudioTestService = game:GetService("StudioTestService")
	const Action = Input.action

	const function Live(): boolean
		const Held = _G.ClaudioPlaytest :: any

		return not StudioTestService.EditModeActive or RunService:IsRunning() or (Held ~= nil and Held.Done == false)
	end

	if Action == "status" then
		const Held = _G.ClaudioPlaytest :: any

		if not Live() then
			return {text = "No playtest is running."}
		end

		return {text = `A {if Held and Held.Mode then Held.Mode else "unknown"} playtest is running. Anything that changes it, including stopping it, has to come from the session itself, so it needs the runtime agent connected.`}
	end

	if Action == "start" then
		if Live() then
			return {error = "A playtest is already running, so it was left alone. Stop it first if you want a fresh run."}
		end

		const Mode = Input.mode or "play"
		const Players = math.clamp(tonumber(Input.players) or 2, 2, 8)

		local Warning

		pcall(function()
			const Runtime = require(script.Parent.Parent.Runtime)
			const Reachable, Why = Runtime.Reachable()

			Runtime.Install()

			if Settings.Get("PlaytestPicker")() then
				require(script.Parent.Parent.Picker).Install()
			end

			if not Reachable then
				Warning = Why
			end
		end)

		_G.ClaudioPlaytest = {
			Mode = Mode,
			Done = false,
			Value = nil,
		}

		task.spawn(function()
			const Ok, Result = pcall(function(): any
				if Mode == "run" then
					return StudioTestService:ExecuteRunModeAsync({})
				end

				if Mode == "multiplayer" then
					return StudioTestService:ExecuteMultiplayerTestAsync(Players, {})
				end

				return StudioTestService:ExecutePlayModeAsync({})
			end)

			const Held = _G.ClaudioPlaytest :: any

			if Held then
				Held.Done = true
				Held.Ok = Ok
				Held.Value = tostring(Result)
			end

			pcall(require(script.Parent.Parent.Runtime).Remove)
			pcall(require(script.Parent.Parent.Picker).Remove)
		end)

		const Held = _G.ClaudioPlaytest :: any
		const Deadline = os.clock() + if Mode == "multiplayer" then 4 else 20

		while os.clock() < Deadline and not Held.Done and StudioTestService.EditModeActive and not RunService:IsRunning() do
			task.wait(0.2)
		end

		if Held.Done then
			return {error = `Studio did not start a {Mode} playtest{if Held.Value and Held.Value ~= "nil" then `: {Held.Value}` else "."}`}
		end

		const Started = if Mode == "multiplayer" then `Multiplayer playtest started with {Players} players.` else `{Mode:sub(1, 1):upper()}{Mode:sub(2)} mode playtest started.`

		return {text = if Warning then `{Started} {Warning}` else Started}
	end

	if Action == "stop" or Action == "players" then
		if not Live() then
			return {error = "No playtest is running, so there was nothing to change."}
		end

		return {
			relay = Action,
			players = tonumber(Input.players),
			text = "Waiting on the play session to do this, because Studio only allows it from inside a running session.",
		}
	end

	return {error = `Claudio does not know the playtest action "{tostring(Action)}".`}
end

const Caveats = "Two things the simulator does not do: it does not resize ScreenGui space to the simulated resolution, so measure AbsoluteSize against the ScreenGui rather than the viewport before calling scale-based UI broken, and UserInputService.TouchEnabled stays false, so a touch-only input path still needs a real device."

const function Device(Input: any): any
	const Simulator = game:GetService("StudioDeviceSimulatorService")
	const Action = Input.action or "status"

	const function Read(Method: string): any
		const Ok, Value = pcall(function()
			return (Simulator :: any)[Method](Simulator)
		end)

		return if Ok then Value else nil
	end

	const function Current(): string
		return tostring(Read("GetDeviceAsync") or "default")
	end

	const function Devices(): {string}
		const Ok, List = pcall(function()
			return Simulator:GetDeviceListAsync()
		end)

		if not Ok then
			return {}
		end

		const Names = {}

		for Index, Entry in List do
			const Id = if typeof(Entry) == "table" then Entry.DeviceId or Entry.Id else Entry

			if Id ~= nil then
				table.insert(Names, tostring(Id))
			end
		end

		table.sort(Names)

		return Names
	end

	const function Describe(): string
		const Now = Current()

		if Now == "default" then
			return "Nothing is being simulated, so the viewport is the editor's own."
		end

		const Size = Read("GetResolutionAsync")
		const Density = Read("GetPixelDensityAsync")
		const Facing = Read("GetOrientationAsync")
		const Scaling = Read("GetScalingModeAsync")
		const Parts = {}

		if Size then
			table.insert(Parts, `{math.floor(Size.X)}x{math.floor(Size.Y)}`)
		end

		if Density then
			table.insert(Parts, `density {string.format("%.1f", Density)}`)
		end

		if Facing then
			table.insert(Parts, tostring(Facing.Name))
		end

		if Scaling then
			table.insert(Parts, `{tostring(Scaling.Name)} scaling`)
		end

		return `Simulating {Now}{if #Parts > 0 then `, {table.concat(Parts, ", ")}` else ""}.`
	end

	if Action == "status" then
		const Known = Devices()

		if #Known == 0 then
			return {text = `{Describe()} Studio did not return a device list, so no profile names can be offered.`}
		end

		return {text = `{Describe()} {#Known} profiles are available: {table.concat(Known, ", ")}`}
	end

	if Action == "stop" then
		if Current() == "default" then
			return {error = "Nothing is being simulated, so there was nothing to stop."}
		end

		const Stopped, Trouble = pcall(function()
			Simulator:StopSimulationAsync()
		end)

		if not Stopped then
			return {error = `Studio refused to stop the simulation: {tostring(Trouble)}`}
		end

		return {text = "Stopped simulating, so the viewport is the editor's own again."}
	end

	if Action == "network" then
		const Settings = settings():GetService("NetworkSettings")
		const Profiles = {
			good = {
				50,
				10,
				0,
			},
			great = {
				15,
				0,
				0,
			},
			off = {
				0,
				0,
				0,
			},
			poor = {
				150,
				100,
				0.5,
			},
		}
		const Wanted = tostring(Input.network or "status")

		if Wanted == "status" then
			return {text = `Network is {(Settings :: any).InboundNetworkMinDelayMs}ms in and {(Settings :: any).OutboundNetworkMinDelayMs}ms out, jitter {(Settings :: any).InboundNetworkJitterMs}ms, loss {(Settings :: any).InboundNetworkLossPercent}%.`}
		end

		const Chosen = Profiles[Wanted]

		if not Chosen then
			return {error = `"{Wanted}" is not a network profile. Studio takes great, good, poor or off.`}
		end

		const Applied, Trouble = pcall(function()
			for Index, Name in {
				"InboundNetworkMinDelayMs",
				"OutboundNetworkMinDelayMs",
			} do
				(Settings :: any)[Name] = Chosen[1]
			end

			for Index, Name in {
				"InboundNetworkJitterMs",
				"OutboundNetworkJitterMs",
			} do
				(Settings :: any)[Name] = Chosen[2]
			end

			for Index, Name in {
				"InboundNetworkLossPercent",
				"OutboundNetworkLossPercent",
			} do
				(Settings :: any)[Name] = Chosen[3]
			end
		end)

		if not Applied then
			return {error = `Studio refused the network profile: {tostring(Trouble)}`}
		end

		return {text = `Network set to {Wanted}: {Chosen[1]}ms delay, {Chosen[2]}ms jitter, {Chosen[3]}% loss, each way. This only shapes a running playtest.`}
	end

	if Action ~= "set" then
		return {error = `Claudio does not know the device action "{tostring(Action)}".`}
	end

	const function Pick(Kind: Enum, Wanted: string, Label: string): (EnumItem?, string?)
		const Names = {}

		for Index, Item in (Kind :: any):GetEnumItems() do
			if Item.Name:lower() == Wanted:lower() then
				return Item, nil
			end

			table.insert(Names, Item.Name)
		end

		return nil, `"{Wanted}" is not a {Label}. Studio takes: {table.concat(Names, ", ")}`
	end

	const Applied = {}

	if Input.device ~= nil then
		const Wanted = tostring(Input.device)
		const Known = Devices()

		if #Known > 0 and not table.find(Known, Wanted) then
			return {error = `"{Wanted}" is not a device Studio knows. It takes: {table.concat(Known, ", ")}`}
		end

		const Set, Trouble = pcall(function()
			Simulator:SetDeviceAsync(Wanted)
		end)

		if not Set then
			return {error = `Studio refused the device {Wanted}: {tostring(Trouble)}`}
		end

		table.insert(Applied, Wanted)
	end

	if Input.orientation ~= nil then
		const Item, Trouble = Pick(Enum.ScreenOrientation, tostring(Input.orientation), "screen orientation")

		if not Item then
			return {error = Trouble}
		end

		const Set, Refused = pcall(function()
			Simulator:SetOrientationAsync(Item)
		end)

		if not Set then
			return {error = `Studio refused the orientation: {tostring(Refused)}`}
		end

		table.insert(Applied, tostring(Item.Name))
	end

	if Input.width ~= nil or Input.height ~= nil then
		const Width = tonumber(Input.width)
		const Height = tonumber(Input.height)

		if not Width or not Height then
			return {error = "A resolution needs both width and height."}
		end

		const Set, Trouble = pcall(function()
			Simulator:SetResolutionAsync(Width, Height)
		end)

		if not Set then
			return {error = `Studio refused the resolution {Width}x{Height}: {tostring(Trouble)}`}
		end

		table.insert(Applied, `{math.floor(Width)}x{math.floor(Height)}`)
	end

	if Input.density ~= nil then
		const Density = tonumber(Input.density)

		if not Density or Density <= 0 then
			return {error = "A pixel density has to be a number above zero."}
		end

		const Set, Trouble = pcall(function()
			Simulator:SetPixelDensityAsync(Density)
		end)

		if not Set then
			return {error = `Studio refused the pixel density {Density}: {tostring(Trouble)}`}
		end

		table.insert(Applied, `density {Density}`)
	end

	if Input.scaling ~= nil then
		const Item, Trouble = Pick(Enum.DeviceSimulatorScalingMode, tostring(Input.scaling), "scaling mode")

		if not Item then
			return {error = Trouble}
		end

		const Set, Refused = pcall(function()
			Simulator:SetScalingModeAsync(Item)
		end)

		if not Set then
			return {error = `Studio refused the scaling mode: {tostring(Refused)}`}
		end

		table.insert(Applied, `{tostring(Item.Name)} scaling`)
	end

	if #Applied == 0 then
		return {error = "Nothing was asked for. Give a device, orientation, width and height, density or scaling, or use stop to end the simulation."}
	end

	return {text = `Set {table.concat(Applied, ", ")}. {Describe()} {Caveats}`}
end

const function Layout(Input: any): any
	const Object = Resolve(Input.path)

	if not Object or not Object:IsA("GuiObject") then
		return {error = `Nothing drawable at "{tostring(Input.path)}". Give the path to a GuiObject.`}
	end

	const Target = Object :: GuiObject
	const Size = Target.AbsoluteSize
	const Lines = {`{math.floor(Size.X)}x{math.floor(Size.Y)} at {math.floor(Target.AbsolutePosition.X)}, {math.floor(Target.AbsolutePosition.Y)}`}

	local Surface: Instance?
	local Hidden: string?
	local Clipped: string?
	local Ancestor: Instance? = Target.Parent

	while Ancestor and Ancestor ~= game do
		if Ancestor:IsA("LayerCollector") then
			Surface = Ancestor

			break
		end

		const Above = Ancestor :: any

		if not Hidden and Above:IsA("GuiObject") and not Above.Visible then
			Hidden = Above.Name
		end

		if not Clipped and Above:IsA("GuiObject") and Above.ClipsDescendants then
			const Edge = Above.AbsolutePosition
			const Reach = Edge + Above.AbsoluteSize
			const Corner = Target.AbsolutePosition + Size

			if Target.AbsolutePosition.X < Edge.X or Target.AbsolutePosition.Y < Edge.Y or Corner.X > Reach.X or Corner.Y > Reach.Y then
				Clipped = Above.Name
			end
		end

		Ancestor = Ancestor.Parent
	end

	if Surface then
		const Space = (Surface :: any).AbsoluteSize

		table.insert(Lines, `inside {Surface.Name} at {math.floor(Space.X)}x{math.floor(Space.Y)}, so {string.format("%.1f", Size.X / math.max(1, Space.X) * 100)}% wide and {string.format("%.1f", Size.Y / math.max(1, Space.Y) * 100)}% tall`)

		if Target.AbsolutePosition.X + Size.X < 0 or Target.AbsolutePosition.Y + Size.Y < 0 or Target.AbsolutePosition.X > Space.X or Target.AbsolutePosition.Y > Space.Y then
			table.insert(Lines, "off screen entirely")
		end
	else
		table.insert(Lines, "no ScreenGui above it, so it is not being drawn anywhere")
	end

	if Size.X < 1 or Size.Y < 1 then
		table.insert(Lines, "no size, so nothing of it is drawn")
	end

	if not Target.Visible then
		table.insert(Lines, "Visible is false")
	end

	if Hidden then
		table.insert(Lines, `hidden by {Hidden}`)
	end

	if Clipped then
		table.insert(Lines, `clipped by {Clipped}`)
	end

	const Read, Simulating = pcall(function()
		return tostring(game:GetService("StudioDeviceSimulatorService"):GetDeviceAsync()) ~= "default"
	end)

	if Read and Simulating and Surface then
		table.insert(Lines, "measured against the ScreenGui, which a simulated device does not resize")
	end

	return {text = `{Target:GetFullName()}: {table.concat(Lines, ", ")}.`}
end

const function Memory(Input: any): any
	const Stats = game:GetService("Stats")

	if not Stats.MemoryTrackingEnabled then
		return {error = "Memory tracking is off for this place, so nothing can be measured."}
	end

	const Least = tonumber(Input.least) or 1
	const Rows = {}

	for _, Tag in Enum.DeveloperMemoryTag:GetEnumItems() do
		const Ok, Used = pcall(function()
			return Stats:GetMemoryUsageMbForTag(Tag)
		end)

		if Ok and Used >= Least then
			table.insert(Rows, {
				Name = Tag.Name,
				Used = Used,
			})
		end
	end

	table.sort(Rows, function(Left, Right)
		return Left.Used > Right.Used
	end)

	const Lines = {}

	for Index, Row in Rows do
		if Index > 15 then
			break
		end

		table.insert(Lines, `{Row.Name} {string.format("%.1f", Row.Used)}`)
	end

	if #Lines == 0 then
		return {text = `{string.format("%.1f", Stats:GetTotalMemoryUsageMb())}MB total, and nothing reaches {Least}MB on its own.`}
	end

	return {text = `{string.format("%.1f", Stats:GetTotalMemoryUsageMb())}MB total, in MB: {table.concat(Lines, ", ")}`}
end

const function Rbxm(Input: any): any
	const SerializationService = game:GetService("SerializationService")
	const EncodingService = game:GetService("EncodingService")

	if Input.base64 then
		const Parent = Resolve(Input.path)

		if not Parent then
			return {error = `Nothing at "{tostring(Input.path)}" to put it under.`}
		end

		const Decoded, Bytes = pcall(function()
			return EncodingService:Base64Decode(buffer.fromstring(Input.base64))
		end)

		if not Decoded then
			return {error = `That file is not valid base64: {tostring(Bytes)}`}
		end

		const Built, Made = pcall(function()
			return SerializationService:DeserializeInstancesAsync(Bytes)
		end)

		if not Built then
			return {error = `Studio could not read that rbxm: {tostring(Made)}`}
		end

		const ChangeHistoryService = game:GetService("ChangeHistoryService")
		const Recording = ChangeHistoryService:TryBeginRecording("ClaudioRbxm", Input.undoName or "Claudio loaded an rbxm")
		const Names = {}

		for _, Object in Made do
			Object.Parent = Parent

			table.insert(Names, Object.Name)
		end

		if Recording then
			ChangeHistoryService:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)

			Committed += 1
		end

		return {text = `Put {#Names} under {Parent:GetFullName()}: {table.concat(Names, ", ")}`}
	end

	const Wanted = {}

	for _, Path in Input.paths or {} do
		const Object = Resolve(Path)

		if not Object then
			return {error = `Nothing at "{tostring(Path)}".`}
		end

		table.insert(Wanted, Object)
	end

	if #Wanted == 0 then
		return {error = "Give paths to save, or base64 and a path to load."}
	end

	const Saved, Bytes = pcall(function()
		return SerializationService:SerializeInstancesAsync(Wanted)
	end)

	if not Saved then
		return {error = `Studio could not write those out: {tostring(Bytes)}`}
	end

	const Encoded, Text = pcall(function()
		return buffer.tostring(EncodingService:Base64Encode(Bytes))
	end)

	if not Encoded then
		return {error = `Encoding failed: {tostring(Text)}`}
	end

	return {
		base64 = Text,
		count = #Wanted,
	}
end

const function Changed(Input: any): any
	const Watcher = require(script.Parent.Parent.Watcher)
	const Mine, Theirs = Watcher.Peek()
	const Limit = math.clamp(tonumber(Input.limit) or 40, 1, 200)
	const Lines = {}

	for _, Bucket in {
		Theirs,
		Mine,
	} do
		for _, Line in Bucket do
			if #Lines >= Limit then
				break
			end

			if not Line:find("Claudio", 1, true) then
				table.insert(Lines, Line)
			end
		end
	end

	if #Lines == 0 then
		return {text = "Nothing has changed in the place since the last turn started."}
	end

	return {lines = Lines}
end

const function ScreenBounds(Object: Instance, Viewport: Vector2): any
	if Object:IsA("GuiObject") then
		const Shown = Object :: GuiObject

		if Shown.AbsoluteSize.X < 1 or Shown.AbsoluteSize.Y < 1 then
			return {error = `{Shown.Name} has no size on screen.`}
		end

		const Inset = game:GetService("GuiService"):GetGuiInset()

		return {
			Left = Shown.AbsolutePosition.X + Inset.X,
			Top = Shown.AbsolutePosition.Y + Inset.Y,
			Right = Shown.AbsolutePosition.X + Inset.X + Shown.AbsoluteSize.X,
			Bottom = Shown.AbsolutePosition.Y + Inset.Y + Shown.AbsoluteSize.Y,
		}
	end

	local Half: Vector3
	local Frame: CFrame

	if Object:IsA("Model") then
		const Box, Size = (Object :: Model):GetBoundingBox()

		Frame = Box
		Half = Size / 2
	elseif Object:IsA("BasePart") then
		const Part = Object :: BasePart

		Frame = Part.CFrame
		Half = Part.Size / 2
	else
		return {error = `{Object.Name} is neither a GuiObject nor something with a position, so there is nothing to crop to.`}
	end

	const Camera = workspace.CurrentCamera
	local Left, Top = math.huge, math.huge
	local Right, Bottom = -math.huge, -math.huge
	local Seen = false

	for _, Corner in {
		Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
		Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
	} do
		const World = Frame:PointToWorldSpace(Corner * Half)
		const Point, OnScreen = Camera:WorldToViewportPoint(World)

		if Point.Z > 0 then
			Seen = Seen or OnScreen
			Left = math.min(Left, Point.X)
			Top = math.min(Top, Point.Y)
			Right = math.max(Right, Point.X)
			Bottom = math.max(Bottom, Point.Y)
		end
	end

	if Left == math.huge then
		return {error = `{Object.Name} is behind the camera, so it cannot be cropped to. Frame it first.`}
	end

	if not Seen and (Right < 0 or Bottom < 0 or Left > Viewport.X or Top > Viewport.Y) then
		return {error = `{Object.Name} is off screen, so it cannot be cropped to. Frame it first.`}
	end

	return {
		Left = Left,
		Top = Top,
		Right = Right,
		Bottom = Bottom,
	}
end

const function Shoot(Input: any): any
	const CaptureService = game:GetService("CaptureService")
	const AssetService = game:GetService("AssetService")
	const Base64 = require(script.Parent.Parent.Base64)

	local Captured: any
	local Done = false

	CaptureService:CaptureScreenshot(function(Content: any)
		Captured = Content
		Done = true
	end)

	const Deadline = os.clock() + 8

	while not Done and os.clock() < Deadline do
		task.wait(0.05)
	end

	if not Captured then
		return {error = "Studio did not return a screenshot."}
	end

	const Made, Image = pcall(function(): any
		return AssetService:CreateEditableImageAsync(Content.fromUri(Captured))
	end)

	if not Made then
		return {error = `Could not read the screenshot: {tostring(Image)}`}
	end

	const Whole = (Image :: any).Size
	local Corner = Vector2.zero
	local Span = Whole
	local Around

	if Input.width and Input.height then
		const Left = math.clamp(tonumber(Input.x) or 0, 0, Whole.X - 1)
		const Top = math.clamp(tonumber(Input.y) or 0, 0, Whole.Y - 1)

		Corner = Vector2.new(Left, Top)
		Span = Vector2.new(math.clamp(tonumber(Input.width) or 1, 1, Whole.X - Left), math.clamp(tonumber(Input.height) or 1, 1, Whole.Y - Top))
	elseif Input.around then
		const Object = Resolve(Input.around)

		if not Object then
			return {error = `Nothing at "{tostring(Input.around)}" to crop to.`}
		end

		if Object:IsA("GuiObject") and Object:FindFirstAncestorWhichIsA("PluginGui") then
			return {error = `{Object:GetFullName()} is inside a plugin window, which the viewport never draws. Capture with of window and widget set to that window's title instead.`}
		end

		const Edges = ScreenBounds(Object, Whole)

		if Edges.error then
			return {error = Edges.error}
		end

		const Pad = tonumber(Input.padding) or 8
		const Left = math.clamp(math.floor(Edges.Left - Pad), 0, Whole.X - 1)
		const Top = math.clamp(math.floor(Edges.Top - Pad), 0, Whole.Y - 1)

		Corner = Vector2.new(Left, Top)
		Span = Vector2.new(
			math.clamp(math.ceil(Edges.Right + Pad) - Left, 1, Whole.X - Left),
			math.clamp(math.ceil(Edges.Bottom + Pad) - Top, 1, Whole.Y - Top)
		)
		Around = Object:GetFullName()
	end

	const Read, Pixels = pcall(function(): any
		return (Image :: any):ReadPixelsBuffer(Corner, Span)
	end)

	if not Read then
		return {error = `Could not read those pixels: {tostring(Pixels)}`}
	end

	const Answer = {
		width = math.floor(Span.X),
		height = math.floor(Span.Y),
		viewport = `{math.floor(Whole.X)}x{math.floor(Whole.Y)}`,
		around = Around,
		pixels = Base64.Encode(buffer.tostring(Pixels)),
	}

	return Answer
end

const function Mark(Input: any): any
	const Wanted = string.lower(tostring(Input.widget or ""))
	const Titles = {}
	local Found: PluginGui?

	for _, Window in game:GetService("PluginGuiService"):GetChildren() do
		if not Window:IsA("PluginGui") then
			continue
		end

		table.insert(Titles, Window.Title)

		if Window.Enabled and Wanted ~= "" and string.lower(Window.Title):find(Wanted, 1, true) then
			Found = Window
		end
	end

	if not Found then
		return {error = if Wanted == "" then "Give part of the window's title in widget." else `No open plugin window has "{Input.widget}" in its title. Open ones: {table.concat(Titles, ", ")}.`}
	end

	const Window = Found :: PluginGui
	const Marker = Instance.new("Frame")

	Marker.Name = "ClaudioMarker"
	Marker.Size = UDim2.fromOffset(16, 8)
	Marker.BackgroundColor3 = Color3.fromRGB(255, 0, 254)
	Marker.BorderSizePixel = 0
	Marker.ZIndex = 100000
	Marker.Parent = Window

	const Half = Instance.new("Frame")

	Half.Name = "Half"
	Half.Size = UDim2.fromOffset(8, 8)
	Half.Position = UDim2.fromOffset(8, 0)
	Half.BackgroundColor3 = Color3.fromRGB(1, 255, 254)
	Half.BorderSizePixel = 0
	Half.ZIndex = 100001
	Half.Parent = Marker

	task.delay(10, function()
		Marker:Destroy()
	end)

	return {
		width = Window.AbsoluteSize.X,
		height = Window.AbsoluteSize.Y,
		title = Window.Title,
	}
end

const function Unmark(): any
	for _, Window in game:GetService("PluginGuiService"):GetChildren() do
		const Marker = Window:FindFirstChild("ClaudioMarker")

		if Marker then
			Marker:Destroy()
		end
	end

	return {text = "Unmarked."}
end

const function Frame(Input: any): any
	const Camera = workspace.CurrentCamera

	if Input.restore then
		const Saved = _G.ClaudioFrameCamera :: any

		if Saved then
			Camera.CFrame = Saved.CFrame
			Camera.FieldOfView = Saved.FieldOfView
			_G.ClaudioFrameCamera = nil

			return {text = "Camera put back."}
		end

		return {text = "The camera had not been moved."}
	end

	const Object = if Input.path then Resolve(Input.path) else nil

	if Input.path and not Object then
		return {error = `Nothing at "{tostring(Input.path)}".`}
	end

	const Viewport = Camera.ViewportSize
	const Answer: {[string]: any} = {viewport = `{math.floor(Viewport.X)}x{math.floor(Viewport.Y)}`}

	if Object then
		if not _G.ClaudioFrameCamera then
			_G.ClaudioFrameCamera = {
				CFrame = Camera.CFrame,
				FieldOfView = Camera.FieldOfView,
			}
		end

		const Model = if Object:IsA("Model") then Object :: Model else nil
		local Middle: Vector3
		local Reach: number

		if Model then
			const Box, Size = Model:GetBoundingBox()

			Middle = Box.Position
			Reach = Size.Magnitude
		elseif Object:IsA("BasePart") then
			Middle = (Object :: BasePart).Position
			Reach = (Object :: BasePart).Size.Magnitude
		else
			return {error = `{Object.Name} is not something with a position, so the camera cannot frame it.`}
		end

		const Away = math.max(Reach, 1) / (2 * math.tan(math.rad(Camera.FieldOfView / 2))) * 1.6

		Camera.CFrame = CFrame.lookAt(Middle + Vector3.new(Away, Away * 0.5, Away), Middle)

		task.wait(0.2)

		Answer.framed = Object:GetFullName()
		Answer.restore = true
	end

	return Answer
end

const function TypeName(Given: any): string
	if typeof(Given) ~= "table" then
		return "any"
	end

	return tostring(Given.ScriptType or Given.EngineType or "any")
end

const function Signature(Entry: any, Kind: string): string
	const Parts = {}

	for _, Parameter in Entry.Parameters or {} do
		table.insert(Parts, `{tostring(Parameter.Name)}: {TypeName(Parameter.Type)}`)
	end

	const Call = `{tostring(Entry.Name)}({table.concat(Parts, ", ")})`

	if Kind == "event" then
		return Call
	end

	const Returns = TypeName(Entry.ReturnType)

	return if Returns == "Void" or Returns == "any" then Call else `{Call} -> {Returns}`
end

const function Marks(Entry: any, Owner: string?, Kind: string?): string
	const Notes = {}
	const Display = Entry.Display or {}

	if Display.DeprecationMessage ~= nil then
		table.insert(Notes, if Display.DeprecationMessage ~= "" then `deprecated, {Display.DeprecationMessage}` else "deprecated")
	end

	const Permits = Entry.Permits or {}

	if Kind == "property" then
		if Permits.Read == nil then
			table.insert(Notes, "cannot be read from here")
		elseif Permits.Write == nil then
			table.insert(Notes, "read only")
		end
	end

	for _, Name in {
		"Read",
		"Write",
		"Call",
		"Listen",
		"New",
	} do
		const Level = Permits[Name]

		if Level ~= nil and tostring(Level) ~= "" then
			table.insert(Notes, `{Name:lower()} needs {tostring(Level)}`)
		end
	end

	if Entry.Owner and Owner and Entry.Owner ~= Owner then
		table.insert(Notes, `from {tostring(Entry.Owner)}`)
	end

	return if #Notes == 0 then "" else ` [{table.concat(Notes, ", ")}]`
end

const function Api(Input: any): any
	const Reflection = game:GetService("ReflectionService")

	if Input.enumName then
		const Wanted = tostring(Input.enumName)

		for _, Given in Enum:GetEnums() do
			if tostring(Given) == Wanted then
				const Items = {}

				for _, Item in Given:GetEnumItems() do
					table.insert(Items, `{Item.Name} = {Item.Value}`)
				end

				return {
					enumName = Wanted,
					items = Items,
				}
			end
		end

		return {error = `There is no enum called "{Wanted}".`}
	end

	if Input.search then
		const Needle = tostring(Input.search):lower()
		const Hits = {}

		for _, Class in Reflection:GetClasses({}) do
			const Name = tostring(Class.Name)

			if Name:lower():find(Needle, 1, true) then
				table.insert(Hits, `class {Name}`)
			end

			if #Hits >= 60 then
				break
			end
		end

		for _, Given in Enum:GetEnums() do
			if tostring(Given):lower():find(Needle, 1, true) and #Hits < 80 then
				table.insert(Hits, `enum {tostring(Given)}`)
			end
		end

		if Input.className then
			for _, Method in {
				"GetPropertiesOfClass",
				"GetMethodsOfClass",
				"GetEventsOfClass",
			} do
				const Ok, Listed = pcall(function(): any
					return (Reflection :: any)[Method](Reflection, Input.className, {})
				end)

				if Ok then
					for _, Entry in Listed do
						if tostring(Entry.Name):lower():find(Needle, 1, true) and #Hits < 120 then
							table.insert(Hits, `{Input.className}.{tostring(Entry.Name)}`)
						end
					end
				end
			end
		end

		return {
			search = Input.search,
			hits = Hits,
		}
	end

	const Class = Input.className

	if not Class or Class == "" then
		const Names = {}

		for _, Entry in Reflection:GetClasses({}) do
			table.insert(Names, tostring(Entry.Name))
		end

		table.sort(Names)

		return {classes = Names}
	end

	const Known, Described = pcall(function(): any
		return Reflection:GetClass(Class, {})
	end)

	if not Known or typeof(Described) ~= "table" or Described.Name == nil then
		return {error = `The engine does not know a class called "{Class}".`}
	end

	local Shared = 0

	const function Gather(Method: string, Kind: string): {string}
		const Ok, Listed = pcall(function(): any
			return (Reflection :: any)[Method](Reflection, Class, {})
		end)

		if not Ok then
			return {}
		end

		const Lines = {}

		for _, Entry in Listed do
			const Name = tostring(Entry.Name)

			if Input.member and Name:lower() ~= tostring(Input.member):lower() then
				continue
			end

			const From = tostring(Entry.Owner)

			if not Input.member and Input.inherited ~= true and (From == "Instance" or From == "Object") then
				Shared += 1

				continue
			end

			const Noted = Marks(Entry, Class, Kind)

			if Input.deprecated == true and not Noted:lower():find("deprecated", 1, true) then
				continue
			end

			if Kind == "property" then
				table.insert(Lines, `{Name}: {TypeName(Entry.Type)}{Noted}`)
			else
				table.insert(Lines, `{Signature(Entry, Kind)}{Noted}`)
			end
		end

		table.sort(Lines)

		return Lines
	end

	const Chain = {}
	local Walking = Described

	while Walking and Walking.Superclass do
		table.insert(Chain, tostring(Walking.Superclass))

		const More, Next = pcall(function(): any
			return Reflection:GetClass(tostring(Walking.Superclass), {})
		end)

		Walking = if More and typeof(Next) == "table" then Next else nil
	end

	const Subclasses = {}

	for _, Sub in Described.Subclasses or {} do
		table.insert(Subclasses, tostring(Sub))
	end

	table.sort(Subclasses)

	return {
		className = Class,
		inherits = Chain,
		subclasses = Subclasses,
		creatable = (Described.Permits or {}).New ~= nil,
		category = (Described.Display or {}).Category,
		properties = Gather("GetPropertiesOfClass", "property"),
		methods = Gather("GetMethodsOfClass", "method"),
		events = Gather("GetEventsOfClass", "event"),
		member = Input.member,
		shared = Shared,
	}
end

const function Properties(Input: any): any
	const Object = Resolve(Input.path)

	if not Object then
		return {error = `Nothing at "{tostring(Input.path)}".`}
	end

	local Names = Input.names

	if not Names then
		const Asked, Listed = pcall(function(): any
			return game:GetService("ReflectionService"):GetPropertiesOfClass(Object.ClassName, {})
		end)

		if not Asked then
			return {error = `Could not ask the engine what a {Object.ClassName} has: {tostring(Listed)}. Name the properties you want instead.`}
		end

		const Found = {}

		for _, Entry in Listed do
			const Name = tostring(Entry.Name)

			if Name:sub(1, 1) == Name:sub(1, 1):upper() then
				table.insert(Found, Name)
			end
		end

		table.sort(Found)

		Names = Found
	end

	const Values = {}
	const Unreadable = {}

	for _, Name in Names do
		const Ok, Value = pcall(function(): any
			return (Object :: any)[Name]
		end)

		if not Ok then
			table.insert(Unreadable, Name)

			continue
		end

		if typeof(Value) == "Instance" then
			table.insert(Values, `{Name} = {Value:GetFullName()}`)
		elseif typeof(Value) == "EnumItem" then
			table.insert(Values, `{Name} = {tostring(Value)}`)
		elseif typeof(Value) == "string" then
			table.insert(Values, `{Name} = {if #Value > 200 then `{Value:sub(1, 200)}...` else Value}`)
		else
			table.insert(Values, `{Name} = {tostring(Value)}`)
		end
	end

	return {
		className = Object.ClassName,
		path = Object:GetFullName(),
		values = Values,
		unreadable = Unreadable,
	}
end

const function ReadPlace(Input: any): any
	const Root = Resolve(Input.path or "game")

	if not Root then
		return {error = `Nothing at "{tostring(Input.path)}".`}
	end

	const Depth = tonumber(Input.depth) or 3
	const Wanted = if typeof(Input.contains) == "string" and Input.contains ~= "" then Input.contains:lower() else nil
	const Tree = {}
	const Sources = {}
	local Counted = 0
	local Cut = false

	const function Walk(Object: Instance, Level: number, Indent: string)
		if Level > Depth then
			return
		end

		for _, Child in Object:GetChildren() do
			if Counted >= 400 then
				Cut = true

				return
			end

			Counted += 1

			table.insert(Tree, `{Indent}{Child.Name} [{Child.ClassName}]`)

			if Child:IsA("LuaSourceContainer") and Child.Source ~= "" then
				const Body = Child.Source

				if not Wanted or Body:lower():find(Wanted, 1, true) or Child.Name:lower():find(Wanted, 1, true) then
					table.insert(Sources, {
						path = Child:GetFullName(),
						source = Body,
					})
					Remember(Child :: LuaSourceContainer)
				end
			end

			Walk(Child, Level + 1, `{Indent}  `)
		end
	end

	table.insert(Tree, `{Root.Name} [{Root.ClassName}]`)

	if Root:IsA("LuaSourceContainer") and Root.Source ~= "" then
		table.insert(Sources, {
			path = Root:GetFullName(),
			source = Root.Source,
		})
		Remember(Root :: LuaSourceContainer)
	end

	Walk(Root, 1, "  ")

	return {
		tree = Tree,
		sources = Sources,
		truncated = Cut,
	}
end

const function Modify(Input: any): any
	const ChangeHistoryService = game:GetService("ChangeHistoryService")
	const Recording = ChangeHistoryService:TryBeginRecording("ClaudioModify", Input.undoName or "Claudio changed the place")

	const Ok, Result = pcall(function(): any
		const Action = Input.action

		if Action == "set" then
			const Object = Resolve(Input.path)

			if not Object then
				return {error = `Nothing at "{tostring(Input.path)}".`}
			end

			const Changed = {}

			for Name, Value in Input.properties or {} do
				const Applied, Trouble = pcall(function()
					(Object :: any)[Name] = Value
				end)

				table.insert(Changed, if Applied then `{Name} set` else `{Name} refused: {tostring(Trouble)}`)
			end

			return {text = `{Object:GetFullName()}: {table.concat(Changed, ", ")}`}
		end

		if Action == "create" then
			const Parent = Resolve(Input.parent)

			if not Parent then
				return {error = `No parent at "{tostring(Input.parent)}".`}
			end

			const Made = Instance.new(Input.className)

			Made.Name = Input.name or Input.className

			for Name, Value in Input.properties or {} do
				pcall(function()
					(Made :: any)[Name] = Value
				end)
			end

			Made.Parent = Parent

			return {text = `Created {Made:GetFullName()}`}
		end

		if Action == "delete" then
			const Object = Resolve(Input.path)

			if not Object then
				return {error = `Nothing at "{tostring(Input.path)}".`}
			end

			const Where = Object:GetFullName()

			Object.Parent = nil

			return {text = `Deleted {Where}`}
		end

		if Action == "rename" then
			const Object = Resolve(Input.path)

			if not Object then
				return {error = `Nothing at "{tostring(Input.path)}".`}
			end

			const Was = Object.Name

			Object.Name = Input.name

			return {text = `Renamed {Was} to {Object.Name}`}
		end

		if Action == "reparent" then
			const Object = Resolve(Input.path)
			const Parent = Resolve(Input.parent)

			if not Object or not Parent then
				return {error = "Give a path and a parent that both exist."}
			end

			Object.Parent = Parent

			return {text = `Moved {Object.Name} into {Parent:GetFullName()}`}
		end

		return {error = `Claudio does not know the action "{tostring(Action)}".`}
	end)

	if Recording then
		ChangeHistoryService:FinishRecording(Recording, if Ok and not (Result :: any).error then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)

		if Ok and not (Result :: any).error then
			Committed += 1
		end
	end

	if not Ok then
		return {error = tostring(Result)}
	end

	const Answer = Result :: any

	if Recording and not Answer.error then
		Answer.undo = true
	end

	return Answer
end

const function Execute(Input: any): any
	const Code = Input.code

	if typeof(Code) ~= "string" or Code == "" then
		return {error = "Give some Luau to run."}
	end

	const LogService = game:GetService("LogService")
	const ChangeHistoryService = game:GetService("ChangeHistoryService")
	const Said = {}

	const function Placed(Message: string): string
		return (Message:gsub("[%w_%.]*ClaudioExecute:(%d+):?%s*", function(Digits: string): string
			return `line {(tonumber(Digits) or 1) - 1}: `
		end))
	end

	const Listening = LogService.MessageOut:Connect(function(Message: string, Kind: Enum.MessageType)
		if #Said >= 200 then
			return
		end

		if Kind == Enum.MessageType.MessageOutput then
			table.insert(Said, Placed(Message))
		elseif Kind == Enum.MessageType.MessageWarning then
			table.insert(Said, `warn: {Placed(Message)}`)
		elseif Kind == Enum.MessageType.MessageError then
			table.insert(Said, `error: {Placed(Message)}`)
		end
	end)

	local Recording: string?

	if Input.readOnly ~= true then
		Recording = ChangeHistoryService:TryBeginRecording("ClaudioExecute", Input.undoName or "Claudio ran a script")
	end

	_G.ClaudioFresh = function(Module: ModuleScript): any
		const Where = Module.Parent
		const Copy = Module:Clone()

		Module:Destroy()

		Copy.Parent = Where

		return (require :: any)(Copy)
	end

	const Holder = Instance.new("ModuleScript")

	Holder.Name = "ClaudioExecute"
	Holder.Source = `return function(plugin)\n{Code}\nend`

	const function Finish(): ()
		task.wait(0.15)

		Holder:Destroy()
		Listening:Disconnect()

		_G.ClaudioFresh = nil
	end

	const function Trouble(Broke: any): any
		return {
			Message = tostring(Broke),
			Trace = debug.traceback(nil, 2),
		}
	end

	const Built, Made = xpcall(function()
		return (require :: any)(Holder)
	end, Trouble)

	if not Built then
		Finish()

		if Recording then
			ChangeHistoryService:FinishRecording(Recording, Enum.FinishRecordingOperation.Cancel)
		end

		const Failed: {[string]: any} = {error = "That did not compile."}

		if #Said > 0 then
			Failed.output = Said
		end

		return Failed
	end

	const Ok, Result = xpcall(Made :: any, Trouble, Settings.Plugin())

	Finish()

	if Recording then
		ChangeHistoryService:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)

		if Ok then
			Committed += 1
		end
	end

	const Answer: {[string]: any} = {}

	if not Ok then
		const Broke = Result :: any
		const Message = tostring(Broke.Message)

		Answer.error = (Message:gsub("[%w_%.]*ClaudioExecute:(%d+):?%s*", function(Digits: string): string
			return `line {(tonumber(Digits) or 1) - 1}: `
		end))

		const Where = tonumber(Message:match("ClaudioExecute:(%d+)"))

		if Where then
			const Lines = string.split(Code, "\n")
			const Real = Where - 1

			if Lines[Real] then
				Answer.line = `line {Real}: {Lines[Real]}`
			end
		end

		const Frames = {}

		for _, Frame in string.split(tostring(Broke.Trace), "\n") do
			const Numbered = Frame:match("ClaudioExecute:(%d+)")

			if Numbered then
				table.insert(Frames, `line {(tonumber(Numbered) or 1) - 1}`)
			end
		end

		if #Frames > 1 then
			Answer.trace = table.concat(Frames, " from ")
		end
	elseif Result ~= nil then
		if typeof(Result) == "table" then
			const Encoded, Text = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), Result)

			Answer.result = if Encoded then Text else tostring(Result)
		else
			Answer.result = tostring(Result)
		end
	end

	if #Said > 0 then
		Answer.output = Said
	end

	if Ok and Recording then
		Answer.undo = true
	end

	return Answer
end

const function RunStudioJob(Job: any)
	if typeof(Job) ~= "table" or typeof(Job.id) ~= "string" then
		return
	end

	if Running[Job.id] then
		return
	end

	Running[Job.id] = true
	Watcher.BeginJob()

	task.spawn(function()
		const Ok, Outcome = pcall(function()
			if Job.kind == "find" then
				return Find(Job.input)
			end

			if Job.kind == "source" then
				return Source(Job.input)
			end

			if Job.kind == "select" then
				return Selected(Job.input)
			end

			if Job.kind == "history" then
				return Steps(Job.input)
			end

			if Job.kind == "logs" then
				return Logs(Job.input)
			end

			if Job.kind == "lint" then
				return LintPlace(if Job.input then Job.input.paths else nil)
			end

			if Job.kind == "playtest" then
				return Playtest(Job.input)
			end

			if Job.kind == "device" then
				return Device(Job.input)
			end

			if Job.kind == "layout" then
				return Layout(Job.input)
			end

			if Job.kind == "memory" then
				return Memory(Job.input)
			end

			if Job.kind == "changes" then
				return Changed(Job.input)
			end

			if Job.kind == "rbxm" then
				return Rbxm(Job.input)
			end

			if Job.kind == "execute" then
				return Execute(Job.input)
			end

			if Job.kind == "read" then
				return ReadPlace(Job.input)
			end

			if Job.kind == "properties" then
				return Properties(Job.input)
			end

			if Job.kind == "api" then
				return Api(Job.input)
			end

			if Job.kind == "frame" then
				return Frame(Job.input)
			end

			if Job.kind == "shoot" then
				return Shoot(Job.input)
			end

			if Job.kind == "mark" then
				return Mark(Job.input)
			end

			if Job.kind == "unmark" then
				return Unmark()
			end

			if Job.kind == "modify" then
				return Modify(Job.input)
			end

			return {error = `Claudio does not know how to do "{Job.kind}" in Studio.`}
		end)

		Client.AnswerStudio(Job.id, if Ok then Outcome else {error = tostring(Outcome)})

		Running[Job.id] = nil
		Watcher.EndJob()
	end)
end

function Chat.WatchStudioJobs()
	if Watching then
		return
	end

	Watching = true

	const Mounted = script:IsDescendantOf(game)
	local Asked = 0
	local Checked = 0

	task.spawn(function()
		while Watching and task.wait(1) do
			if Connection.Status() == "Connected" and os.clock() - Asked > 60 then
				Asked = os.clock()
				task.spawn(Chat.RefreshUsage)
			end

			if Connection.Status() == "Connected" and os.clock() - Checked > 3 then
				Checked = os.clock()
				task.spawn(Chat.Sync)
			end

			if not Mounted or script:IsDescendantOf(game) then
				task.spawn(Chat.ResumeAfterLimit)
			end

			if Mounted and not script:IsDescendantOf(game) then
				Watching = false

				break
			end

			if Mounted then
				(script.Parent.Parent :: Instance):SetAttribute("ClaudioMountSeen", DateTime.now().UnixTimestampMillis / 1000)
			else
				const Mount = game:GetService("ServerStorage"):FindFirstChild("ClaudioTesting")
				const Seen = if Mount then Mount:GetAttribute("ClaudioMountSeen") else nil
				const Yield = typeof(Seen) == "number" and math.abs(DateTime.now().UnixTimestampMillis / 1000 - Seen) < 5

				if Yield ~= Chat.Yielding then
					Chat.Yielding = true

					if Chat.Window then
						Chat.Window.Enabled = if Yield then false else Settings.Get("WidgetOpen")() == true
					end

					task.delay(1, function()
						Chat.Yielding = Yield
					end)
				end

				if Yield then
					continue
				end
			end

			if RunService:IsRunning() then
				continue
			end

			const Polled, Trouble = pcall(function(): boolean
				const Ok, Result = Client.TakeStudioJob()

				if not Ok then
					if Connection.Status() == "Connected" then
						Connection.Fail(Error.Classify(tostring(Result)))
					end

					return false
				end

				if Result and Result.job then
					RunStudioJob(Result.job)
				end

				return true
			end)

			if not Polled then
				warn(`Claudio could not take a Studio job: {tostring(Trouble)}`)
			end
		end
	end)
end

const function CheckEdited(Wanted: {any})
	if #Wanted == 0 or LintPasses >= 1 then
		return
	end

	const Ok, Result = Client.Lint(Wanted, ScriptTree())

	if not Ok or #Result.scripts == 0 then
		return
	end

	const Lines = {"<studio_lint>"}

	for _, Entry in Result.scripts do
		table.insert(Lines, Entry.path)

		for _, Warning in Entry.lines do
			table.insert(Lines, `  {Warning}`)
		end
	end

	table.insert(Lines, "</studio_lint>")

	Chat.Send("Fix these script warnings, then stop.", table.concat(Lines, "\n"))

	LintPasses = 1
end

const function ReadParts(Given: any): {Types.Piece}
	const Parts: {Types.Piece} = {}

	for _, Part in (if typeof(Given) == "table" then Given else {}) :: {any} do
		table.insert(Parts, {
			Kind = Part.kind,
			Text = Part.text,
			Call = Part.call,
		})
	end

	return Parts
end

const function FetchImage(RequestId: string, Index: number, CurrentGeneration: number, Pending: {[number]: boolean})
	const Ok, Image = Client.GetImage(RequestId, Index)

	Pending[Index] = nil

	if not Ok or CurrentGeneration ~= Generation then
		return
	end

	const Built, Picture = pcall(Pictures.Build, Image.width, Image.height, Image.pixels)

	if not Built then
		return
	end

	const Images = table.clone(Chat.StreamingImages() :: {EditableImage})

	Images[Index] = Picture
	Chat.StreamingImages(Images)
end

const function Poll(Turn: Types.Turn, CurrentGeneration: number): (string, string, Types.Turn?)
	local Version = -1
	local Fetched = 0

	const Pending: {[number]: boolean} = {}

	while task.wait() do
		const Polled, State = Client.PollTurn(Turn.requestId, Version)

		if CurrentGeneration ~= Generation then
			return "cancelled", "", nil
		end

		if not Polled then
			return "error", `Lost the bridge while waiting: {State}`, nil
		end

		Version = State.version
		Chat.StreamingText(State.text or "")
		Chat.StreamingThinking(State.thinking or "")
		Chat.StreamingParts(ReadParts(State.parts))
		Chat.StreamingPick(if State.auto and State.model then {
			Model = State.model,
			Effort = State.effort,
		} else nil)
		Chat.Limits(State.limits or Chat.Limits())
		Chat.Tasks(State.tasks or {})
		Chat.Planning(State.planning == true)
		Chat.Compacting(State.compacting == true)

		if State.tokens then
			Chat.ContextUsed(State.tokens.input + State.tokens.cached)
		end

		if State.contextWindow and State.contextWindow > 0 then
			Chat.ContextWindow(State.contextWindow)
			Chat.ContextModel(State.contextModel or "")
		end

		if State.context then
			Chat.ContextParts(State.context.categories)
			Chat.ContextUsed(State.context.total)
			Chat.ContextWindow(State.context.max)
		end

		Chat.Activity(State.activity or {})
		Chat.Calls(State.calls or {})

		Watcher.SetBusy(#(State.calls or {}) > 0)

		Chat.Tokens(State.tokens)
		Chat.Elapsed(State.milliseconds or 0)
		Chat.Permission(State.permission)
		Chat.Question(State.question)

		if State.conversationId and Chat.ConversationId() ~= State.conversationId then
			Chat.ConversationId(State.conversationId)
			Settings.Set("LastChat", State.conversationId)
		end

		while Fetched < (State.imageCount or 0) do
			Fetched += 1
			Pending[Fetched] = true
			task.spawn(FetchImage, Turn.requestId, Fetched, CurrentGeneration, Pending)
		end

		if State.status == "running" then
			continue
		end

		local Waited = 0

		while next(Pending) and CurrentGeneration == Generation and Waited < 30 and task.wait(0.1) do
			Waited += 0.1
		end

		if State.status == "error" then
			return "error", State.text or "", State
		end

		if State.status == "cancelled" and State.text == "" then
			return "cancelled", "Stopped.", State
		end

		return State.status, State.text or "", State
	end

	return "cancelled", "", nil
end

local Start: (Types.QueuedMessage) -> ()
local Attach: (string) -> ()

const function Ended(Id: string): (number?, boolean)
	const Ok, Result = Client.ActiveTurn(Id)

	if not Ok or typeof(Result) ~= "table" then
		return nil, false
	end

	return if typeof(Result.endedAt) == "number" then Result.endedAt else 0, typeof(Result.turn) == "table"
end

const function Finish(Status: string, Text: string, State: Types.Turn?)
	Append({
		Role = "assistant",
		Text = Text,
		Activity = if State then State.activity else nil,
		Thinking = if State then State.thinking else nil,
		Parts = if State then ReadParts(State.parts) else nil,
		Calls = if State then State.calls else nil,
		Edits = Watcher.GetTurnChanges(),
		Tokens = if State then State.tokens else nil,
		Milliseconds = if State then State.milliseconds else nil,
		Failed = Status == "error",
		Error = if Status == "error" then (if State and State.error then State.error else Text) else nil,
		Cost = if State then State.cost else nil,
		Prompt = Chat.CurrentPrompt,
		Images = Chat.StreamingImages(),
		Model = if State then State.model else nil,
		Effort = if State then State.effort else nil,
		Auto = if State then State.auto else nil,
	})
	if State and State.tokens and State.tokens.input > 0 then
		const History = Chat.Messages()

		for Index = #History, 1, -1 do
			if History[Index].Role == "user" then
				Chat.Messages(Replaced(History, Index, With(History[Index], {Tokens = State.tokens})))

				break
			end
		end
	end

	Chat.StreamingText("")
	Chat.StreamingThinking("")
	Chat.StreamingParts({})
	Chat.StreamingPick(nil)
	Chat.StreamingImages({})
	Chat.Activity({})
	Chat.Permission(nil)
	Chat.Question(nil)
	Chat.Sending(false)
	Chat.Began(0)
	Chat.RequestId = nil

	task.spawn(function()
		const Id = Chat.ConversationId()

		if Id then
			KnownEnded = Ended(Id) or KnownEnded
		end
	end)

	if Settings.Get("FixLint")() then
		const Edited = EditedScripts()

		task.spawn(CheckEdited, Edited)
	end

	if Settings.Get("UndoPoint")() then
		ChangeHistoryService:SetWaypoint(`Claudio {Checkpoint} done`)
	end

	task.spawn(Chat.Refresh)
	task.spawn(Chat.RefreshUsage)

	if Chat.ReplyListener then
		Chat.ReplyListener(Text)
	end

	if Status == "cancelled" then
		for _, Entry in Chat.Queue() do
			DestroyImages(Entry.Previews)
		end

		Chat.Queue({})

		return
	end

	if Status == "error" then
		return
	end

	const Queue = table.clone(Chat.Queue() :: {Types.QueuedMessage})
	const Next = table.remove(Queue, 1)

	if not Next then
		return
	end

	Chat.Queue(Queue)
	assert(Start)(Next)
end

local Flushing = false

function Chat.Flush()
	if Flushing then
		return
	end

	Flushing = true

	while Chat.Sending() do
		const Waiting = Chat.Queue() :: {Types.QueuedMessage}
		const Entry = Waiting[1]

		if not Entry then
			break
		end

		if not Chat.RequestId then
			task.wait(0.05)

			continue
		end

		const Rest = table.clone(Waiting)

		table.remove(Rest, 1)
		Chat.Queue(Rest)

		if not Client.SendNow(Entry.Full, Chat.ConversationId(), Chat.RequestId, Entry.Images) then
			const Back = table.clone(Chat.Queue() :: {Types.QueuedMessage})

			table.insert(Back, 1, Entry)
			Chat.Queue(Back)

			break
		end

		DestroyImages(Entry.Previews)
	end

	Flushing = false
end

Attach = function(ConversationId: string)
	const Found, Result = Client.ActiveTurn(ConversationId)

	if not Found or typeof(Result) ~= "table" or typeof(Result.turn) ~= "table" or Result.turn.requestId == Chat.RequestId then
		return
	end

	Generation += 1

	const CurrentGeneration = Generation
	const Turn = Result.turn :: Types.Turn

	Chat.Began(os.clock() - (Turn.milliseconds or 0) / 1000)
	Chat.Sending(true)
	Chat.RequestId = Turn.requestId

	task.spawn(Chat.Flush)

	for Index = #Chat.Messages(), 1, -1 do
		if Chat.Messages()[Index].Role == "user" then
			Chat.CurrentPrompt = Chat.Messages()[Index].Text
			Chat.Messages(table.move(Chat.Messages(), 1, Index, 1, {}))

			break
		end
	end

	task.spawn(function()
		const Ok, Status, Reply, State = pcall(Poll, Turn, CurrentGeneration)

		if CurrentGeneration ~= Generation then
			return
		end

		if Ok then
			Finish(Status, Reply, State)
		else
			Finish("error", `The plugin hit an error: {Status}`, nil)
		end
	end)
end

Start = function(Entry: Types.QueuedMessage)
	Generation += 1

	const CurrentGeneration = Generation

	Checkpoint += 1

	if Settings.Get("UndoPoint")() then
		ChangeHistoryService:SetWaypoint(`Claudio {Checkpoint} open`)
	end

	Watcher.BeginTurn()
	Chat.Began(os.clock())
	Append({
		Role = "user",
		Text = Entry.Display,
		Attachments = Entry.Attachments,
		Images = Entry.Previews,
		Edits = Entry.Edits,
		Checkpoint = if Settings.Get("UndoPoint")() then Checkpoint else nil,
	})
	Chat.Sending(true)
	Chat.CurrentPrompt = Entry.Display

	if Chat.Title() == "New chat" then
		Chat.Title(Entry.Display:gsub("%s+", " "):sub(1, 60))
	end

	task.spawn(function()
		const Ok, Status, Reply, State = pcall(function(): (string, string, Types.Turn?)
			const Started, Turn = Client.StartTurn(Entry.Full, Chat.ConversationId(), Entry.Images, Entry.Escalate)

			if not Started then
				return "error", `Could not reach the bridge: {Turn}`, nil
			end

			if CurrentGeneration ~= Generation then
				task.spawn(Client.CancelTurn, Turn.requestId)

				return "cancelled", "", nil
			end

			Chat.RequestId = Turn.requestId

			task.spawn(Chat.Flush)

			if Stopping == CurrentGeneration then
				task.spawn(Client.CancelTurn, Turn.requestId)
			end

			return Poll(Turn, CurrentGeneration)
		end)

		if CurrentGeneration ~= Generation then
			return
		end

		if Ok then
			Finish(Status, Reply, State)
		else
			Finish("error", `The plugin hit an error: {Status}`, nil)
		end
	end)
end

local NoticeToken = 0

function Chat.Say(Text: string)
	NoticeToken += 1

	const Token = NoticeToken

	Chat.Notice(Text)
	task.delay(6, function()
		if NoticeToken == Token then
			Chat.Notice(nil)
		end
	end)
end

function Chat.LoadCommands()
	const Ok, Result = Client.GetCommands(Settings.Get("WorkingFolder")(), Chat.ConversationId())

	if not Ok then
		return
	end

	const Described = {}

	for _, Entry in Result.commands or {} do
		Described[Entry.name] = Entry.description
	end

	const Found: {Types.Command} = {}
	const Seen = {}

	for _, List in {
		Result.slashCommands or {},
		Result.skills or {},
	} do
		for _, Name in List do
			if Seen[Name] then
				continue
			end

			Seen[Name] = true
			table.insert(Found, {
				name = Name,
				description = Described[Name] or "",
			})
		end
	end

	table.sort(Found, function(Left: Types.Command, Right: Types.Command)
		return Left.name < Right.name
	end)
	Chat.Commands(Found)
end

function Chat.LoadModels()
	const Ok, Result = Client.GetModels()

	if not Ok then
		return
	end

	Chat.Models(Result.models or {})
end

function Chat.Thinking(Value: boolean?): boolean
	if Value ~= nil then
		Settings.Set("TranscriptView", if Value then "Thinking" else "Normal")
	end

	return Settings.Get("TranscriptView")() == "Thinking"
end

function Chat.CheckVersions()
	const Ok, Result = Client.GetVersions()

	if not Ok then
		return
	end

	Chat.Versions(Result)
end

const function Newer(Candidate: string, Than: string): boolean
	const Left = string.split(Candidate, ".")
	const Right = string.split(Than, ".")

	for Index = 1, 3 do
		const One = tonumber(Left[Index]) or 0
		const Two = tonumber(Right[Index]) or 0

		if One ~= Two then
			return One > Two
		end
	end

	return false
end

function Chat.Installed(): string
	return Config.Version
end

function Chat.UpdateWanted(): boolean
	const Found = Chat.Versions()

	if not Found or not Found.latest or not Newer(Found.latest, Config.Version) then
		return false
	end

	if Found.current == Found.latest then
		return false
	end

	return Settings.Get("DeclinedVersion")() ~= Found.latest
end

function Chat.DeclineUpdate()
	const Found = Chat.Versions()

	if Found and Found.latest then
		Settings.Set("DeclinedVersion", Found.latest)
	end
end

function Chat.InstallVersion(Version: string)
	if Chat.Updating() then
		return
	end

	Chat.Updating(true)

	const Ok, Result = Client.InstallVersion(Version)

	Chat.Updating(false)

	if not Ok then
		Chat.Say(`Could not install {Version}: {Result}`)

		return
	end

	Settings.Set("DeclinedVersion", "")
	Chat.Say(`Installed {Version}. Restart Studio to load it.`)
	task.spawn(Chat.CheckVersions)
end

function Chat.LoadMcpServers()
	const Ok, Result = Client.GetMcpServers()

	if not Ok then
		return
	end

	Chat.McpServers(Result.servers or {})
end

function Chat.RefreshUsage()
	const Ok, Result = Client.GetUsage(Chat.ConversationId())

	if not Ok then
		return
	end

	Chat.Limits(Result.limits or Chat.Limits())

	if not Result.context then
		Chat.ContextParts({})
		Chat.ContextUsed(0)
		Chat.ContextWindow(0)
		Chat.ContextModel("")

		return
	end

	Chat.ContextParts(Result.context.categories)
	Chat.ContextUsed(Result.context.total)
	Chat.ContextWindow(Result.context.max)
	Chat.ContextModel(Result.context.model or "")
end

function Chat.Refresh()
	const Ok, Result = Client.ListConversations()

	Chat.Listed(true)

	if not Ok then
		Chat.Say(`Could not list chats: {Result}`)

		return
	end

	const Listing = table.clone(Result.conversations)

	if Gallery.Testing then
		table.insert(Listing, 1, Gallery.Summary())
	end

	Chat.Conversations(Listing)

	const Current = Chat.ConversationId()
	local Listed = false

	for _, Summary in Result.conversations do
		if Summary.id == Current then
			Listed = true
			Chat.Title(Summary.title)
		end
	end

	if Current and not Listed and not Chat.Sending() and not Client.ConversationExists(Current) and Chat.ConversationId() == Current then
		Chat.New()
		Chat.Say("That chat was deleted, so this is a new one.")

		return
	end

	if #Chat.Commands() == 0 then
		Chat.LoadCommands()
	end

	if #Chat.Models() == 0 then
		Chat.LoadModels()
	end

	Chat.WatchStudioJobs()
end

const Requested: {[number]: boolean} = {}

const function LoadImagesFor(Index: number, CurrentGeneration: number)
	const Message = Chat.Messages()[Index]
	const Id = Chat.ConversationId()

	if Requested[Index] or not Id or not Message or not Message.ImageIds or #Message.ImageIds == 0 then
		return
	end

	Requested[Index] = true

	const Fetched = {}
	local Running = 0

	for Slot, ImageIndex in Message.ImageIds do
		while Running >= 4 and task.wait() do
		end

		Running += 1

		task.spawn(function()
			const Ok, Image = Client.GetConversationImage(Id, ImageIndex)

			if Ok and CurrentGeneration == Generation then
				const Built, Picture = pcall(Pictures.Build, Image.width, Image.height, Image.pixels)

				if Built then
					Fetched[Slot] = Picture
				end
			end

			Running -= 1
		end)
	end

	while Running > 0 and task.wait() do
	end

	const Loaded = {}

	for Slot = 1, #Message.ImageIds do
		if Fetched[Slot] then
			table.insert(Loaded, Fetched[Slot])
		end
	end

	if CurrentGeneration ~= Generation or #Loaded == 0 or Chat.Messages()[Index] ~= Message then
		DestroyImages(Loaded)

		return
	end

	Chat.Messages(Replaced(Chat.Messages(), Index, With(Message, {Images = Loaded})))
end

function Chat.RequestImages(Index: number)
	task.spawn(LoadImagesFor, Index, Generation)
end

const function Loaded(Given: {any}): {Types.Message}
	const Messages: {Types.Message} = {}

	for _, Message in Given do
		table.insert(Messages, {
			Role = if Message.role == "user" then "user" else "assistant",
			Text = Message.text,
			Activity = Message.activity,
			Parts = ReadParts(Message.parts),
			Calls = Message.calls,
			ImageIds = Message.images,
			At = Message.at,
			Tokens = Message.tokens,
			Cost = Message.cost,
			Estimated = Message.estimated,
		})
	end

	return Messages
end

const Allowance = 7000

const function Weight(Message: Types.Message): number
	const Calls: {Types.ToolCall} = Message.Calls or {}
	const Edits: {Types.Change} = Message.Edits or {}
	const Pictures: {number} = Message.ImageIds or {}
	local Cost = 140 + #(Message.Text or "")

	for _, Call in Calls do
		Cost += 180 + math.min(#Call.name, 60)
	end

	Cost += #Edits * 70
	Cost += #Pictures * 420

	return Cost
end

function Chat.Fits(Messages: {Types.Message}, Upto: number): number
	local Spent = 0
	local Taken = 0

	for Index = Upto, 1, -1 do
		const Entry = Messages[Index]

		if not Entry then
			break
		end

		Spent += Weight(Entry)
		Taken += 1

		if Spent >= Allowance then
			break
		end
	end

	return math.max(1, Taken)
end

function Chat.Open(Id: string)
	if Id == Gallery.Id then
		Chat.Stop()
		Reset()
		Context.Clear()
		Chat.Shown(40)
		table.clear(Requested)
		Chat.ConversationId(Gallery.Id)
		Chat.Title(Gallery.Title)
		Chat.Shown(Chat.Fits(Gallery.Messages(), #Gallery.Messages()))
		Chat.Messages(Gallery.Messages())
		Chat.ListOpen(false)

		return
	end

	const Ok, Conversation = Client.GetConversation(Id, nil, 14)

	if not Ok then
		Chat.Say(`Could not open that chat: {Conversation}`)

		return
	end

	Chat.Stop()
	Reset()
	Context.Clear()
	Chat.Shown(40)
	table.clear(Requested)
	Settings.Set("LastChat", Id)

	const Messages = Loaded(Conversation.messages)

	Chat.Partial(Conversation.partial == true)
	Chat.Earlier((Conversation.first or 1) - 1)

	Chat.Shown(Chat.Fits(Messages, #Messages))
	Chat.Messages(Messages)
	Chat.ConversationId(Conversation.id)
	Chat.Title(Conversation.title)
	Chat.LoadChapters()
	Chat.ListOpen(false)
	KnownEnded = Ended(Conversation.id) or 0
	Attach(Conversation.id)
end

function Chat.Sync()
	const Id = Chat.ConversationId()

	if not Id or Id == Gallery.Id or Chat.Sending() or Chat.Yielding then
		return
	end

	const EndedAt, Running = Ended(Id)

	if not EndedAt or Chat.ConversationId() ~= Id or Chat.Sending() then
		return
	end

	if Running then
		Attach(Id)

		return
	end

	if EndedAt == KnownEnded then
		return
	end

	KnownEnded = EndedAt
	Chat.Open(Id)
end

function Chat.LoadEarlier()
	const Id = Chat.ConversationId()
	const Missing = Chat.Earlier()

	if not Id or (Missing == 0 and not Chat.Partial()) then
		return
	end

	if Chat.Partial() then
		const Whole, Everything = Client.GetConversation(Id, nil, nil)

		if not Whole or Chat.ConversationId() ~= Id then
			return
		end

		const All = Loaded(Everything.messages)
		const Kept = #Chat.Messages()

		Chat.Partial(false)
		Chat.Earlier((Everything.first or 1) - 1)
		Chat.Shown(Chat.Shown() + Chat.Fits(All, math.max(0, #All - Kept)))
		Chat.Messages(All)
		table.clear(Chat.Anchors)

		return
	end

	const Ok, Conversation = Client.GetConversation(Id, Missing, 40)

	if not Ok or Chat.ConversationId() ~= Id then
		return
	end

	const Messages = Loaded(Conversation.messages)
	const Anchors = table.clone(Chat.Anchors)

	for _, Message in Chat.Messages() do
		table.insert(Messages, Message)
	end

	table.clear(Chat.Anchors)

	for Index, Anchor in Anchors do
		Chat.Anchors[Index + #Conversation.messages] = Anchor
	end

	Chat.Messages(Messages)
	Chat.Partial(Conversation.partial == true)
	Chat.Earlier((Conversation.first or 1) - 1)
	Chat.Shown(Chat.Shown() + #Conversation.messages)
end

function Chat.Resume()
	const Last = Settings.Get("LastChat")()

	if Last == "" or Chat.ConversationId() then
		return
	end

	if not Client.ConversationExists(Last) then
		Settings.Set("LastChat", "")

		return
	end

	Chat.Open(Last)
end

function Chat.New()
	Chat.Stop()
	Reset()
	Chat.Shown(40)
	table.clear(Requested)
	Chat.Chapters({})
	Chat.ConversationId(nil)
	Chat.Title("New chat")
	Settings.Set("LastChat", "")
	Chat.ListOpen(false)
	Chat.SettingsOpen(false)
	Chat.VersionOpen(false)
	Chat.VersionPick("")
	Context.Clear()
end

function Chat.Rename(Id: string, Title: string)
	Chat.Renaming(nil)

	const Ok, Result = Client.RenameConversation(Id, Title)

	if not Ok then
		Chat.Say(`Could not rename that chat: {Result}`)

		return
	end

	if Chat.ConversationId() == Id then
		Chat.Title(Title)
	end

	Chat.Refresh()
end

function Chat.SetFlag(Id: string, Flag: string, Value: boolean)
	Chat.MenuFor(nil)

	const Ok, Result = Client.SetConversationFlag(Id, Flag, Value)

	if not Ok then
		Chat.Say(`Could not update that chat: {Result}`)

		return
	end

	Chat.Refresh()
end

function Chat.SetFolderHidden(Folder: string, Value: boolean)
	Chat.MenuFolder(nil)

	const Ok, Result = Client.SetFolderHidden(Folder, Value)

	if not Ok then
		Chat.Say(`Could not update that folder: {Result}`)

		return
	end

	Chat.Refresh()
end

function Chat.Fork(Id: string)
	Chat.MenuFor(nil)

	const Ok, Result = Client.ForkConversation(Id)

	if not Ok then
		Chat.Say(`Could not fork that chat: {Result}`)

		return
	end

	Chat.Refresh()
	Chat.Open(Result.id)
end

function Chat.Delete(Id: string)
	if Id == Gallery.Id then
		Chat.Say("The design gallery is not a real chat, so it cannot be deleted.")

		return
	end

	const Ok, Result = Client.DeleteConversation(Id)

	if not Ok then
		Chat.Say(`Could not delete that chat: {Result}`)

		return
	end

	if Chat.ConversationId() == Id then
		Chat.New()
	end

	Chat.Refresh()
end

function Chat.Send(Text: string, Quiet: string?)
	LintPasses = 0
	Chat.Draft("")

	if not Text:match("%S") then
		return
	end

	if Chat.ConversationId() == Gallery.Id then
		Chat.Say("This is the design gallery, not a real chat. Press New to start one.")

		return
	end

	if Text:lower():match("^%s*aun%s*$") then
		Append({
			Role = "user",
			Text = Text,
		})

		task.spawn(function()
			const Ok, Found = Client.Aun()

			if not Ok then
				Append({
					Role = "assistant",
					Text = "aun isn't answering right now. Try again in a moment.",
				})

				return
			end

			const Built, Picture = pcall(Pictures.Build, Found.width, Found.height, Found.pixels)

			Append({
				Role = "assistant",
				Text = Found.name,
				Images = if Built then {Picture} else nil,
			})
		end)

		return
	end

	local Full = Text

	if Settings.Get("AttachSelection")() then
		const Token = Context.AddSelection()

		if Token and not Full:find(Token, 1, true) then
			Full = `{Full} {Token}`
		end
	end

	const Block, Labels, Images, Previews = Context.Take(Full)
	local Sent = if Block == "" then Full else `{Full}\n\n{Block}`
	local Edits: {Types.Change}?

	if Quiet then
		Sent = `{Sent}\n\n{Quiet}`
	end

	if Settings.Get("ShareEdits")() then
		const Mine = Watcher.GetUserChanges()

		if #Mine > 0 then
			const Lines = {}

			for _, Change in Mine do
				table.insert(Lines, Change.Text)
			end

			Edits = Mine
			Sent = `{Sent}\n\n<studio_edits>\nI changed these in Studio myself since my last message:\n- {table.concat(Lines, "\n- ")}\n</studio_edits>`
		end
	end

	const Entry: Types.QueuedMessage = {
		Display = Full,
		Full = Sent,
		Extra = Sent:sub(#Full + 1),
		Attachments = Labels,
		Images = Images,
		Previews = Previews,
		Edits = Edits,
	}

	if not Chat.Sending() then
		assert(Start)(Entry)

		return
	end

	const Queue = table.clone(Chat.Queue() :: {Types.QueuedMessage})

	table.insert(Queue, Entry)
	Chat.Queue(Queue)
	task.spawn(Chat.Flush)
end

function Chat.Undoing(Index: number): {string}
	const Found = {}

	for Position = Index, #Chat.Messages() do
		const Message = Chat.Messages()[Position]

		if Message.Role == "assistant" then
			for _, Change in Changes.For(Message) do
				table.insert(Found, Change.Text)
			end
		end
	end

	return Found
end

function Chat.UndoPoint(Index: number): number?
	const History = Chat.Messages()

	for At = math.min(Index, #History), 1, -1 do
		if History[At].Checkpoint then
			return At
		end
	end

	return nil
end

function Chat.Restore(Position: number)
	const Message = Chat.Messages()[Position]
	const Point = if Message then Message.Checkpoint else nil

	if Chat.Restoring() or not Point then
		return
	end

	Chat.Restoring(true)
	Watcher.Pause(true)

	const Target = `Claudio {Point} open`
	local Steps = 0
	local Reached = false

	const Undone, Failure = pcall(function()
		while Steps < 500 do
			const CanUndo, Name = ChangeHistoryService:GetCanUndo()

			if not CanUndo or not Name then
				break
			end

			if Name == Target then
				Reached = true

				break
			end

			ChangeHistoryService:Undo()
			Steps += 1
		end
	end)

	if not Undone then
		Watcher.Pause(false)
		Chat.Restoring(false)
		Chat.Say(`Could not finish rewinding: {Failure}`)

		return
	end

	if not Reached then
		Watcher.Pause(false)
		Chat.Restoring(false)
		Chat.Say(`Undid {Steps} step{if Steps == 1 then "" else "s"} but couldn't get back to this message, so the chat wasn't changed. Studio may have trimmed its undo history.`)

		return
	end

	const Kept = {}

	for Index = 1, Position - 1 do
		table.insert(Kept, Chat.Messages()[Index])
	end

	const Dropped = #Chat.Messages() - #Kept

	for Index = Position, #Chat.Messages() do
		DestroyImages(Chat.Messages()[Index].Images)
	end

	Chat.Messages(Kept)
	table.clear(Requested)
	Watcher.Pause(false)
	Watcher.Reset()
	Chat.Restoring(false)
	Chat.Say(`Rolled back {Steps} Studio step{if Steps == 1 then "" else "s"} and removed {Dropped} message{if Dropped == 1 then "" else "s"}.`)
end

function Chat.PasteImage()
	const Ok, Image = Client.GetClipboardImage()

	if not Ok then
		Chat.Say("Could not reach the bridge to read the clipboard.")

		return
	end

	if not Image.data then
		Chat.Say("There is no image on the clipboard.")

		return
	end

	const Token = Context.AddImage("Image", Image.data, Image.mediaType)
	const Draft = Chat.Draft()
	const Spacer = if Draft ~= "" and Draft:sub(-1) ~= " " then " " else ""

	Chat.Draft(`{Draft}{Spacer}{Token} `)
end

function Chat.LoadChapters()
	const Id = Chat.ConversationId()

	if not Id then
		Chat.Chapters({})

		return
	end

	const Ok, Result = Client.GetChapters(Id)

	if Ok then
		Chat.Chapters(Result.chapters or {})
	end
end

function Chat.IsChapter(Index: number): boolean
	for _, Chapter in Chat.Chapters() do
		if Chapter.index == Index + Chat.Earlier() then
			return true
		end
	end

	return false
end

function Chat.ToggleChapter(Index: number, Title: string)
	const Id = Chat.ConversationId()

	if not Id then
		Chat.Say("Send a message before pinning a chapter.")

		return
	end

	const Chapters: {Types.Chapter} = {}

	for _, Chapter in Chat.Chapters() do
		if Chapter.index ~= Index + Chat.Earlier() then
			table.insert(Chapters, Chapter)
		end
	end

	if #Chapters == #Chat.Chapters() then
		table.insert(Chapters, {
			index = Index + Chat.Earlier(),
			title = Title:gsub("%s+", " "):sub(1, 60),
		})
		table.sort(Chapters, function(Left: Types.Chapter, Right: Types.Chapter)
			return Left.index < Right.index
		end)
	end

	Chat.Chapters(Chapters)

	const Ok, Result = Client.SetChapters(Id, Chapters)

	if not Ok then
		Chat.Say(`Could not save that chapter: {Result}`)
	end
end

function Chat.Copy(Text: string)
	const Ok = Client.WriteClipboard(Text)

	Chat.Say(if Ok then "Copied to the clipboard." else "Could not reach the bridge to copy that.")
end

function Chat.ForkHere()
	const Id = Chat.ConversationId()

	if not Id then
		return
	end

	Chat.Fork(Id)
end

function Chat.ResumeAfterLimit()
	if Chat.Sending() or Settings.Get("AutoContinue")() ~= true then
		return
	end

	const Last = Chat.Messages()[#Chat.Messages()]

	if not Last or not Last.Failed or not Last.Error or not Format.IsLimit(Last.Error) then
		return
	end

	for _, Limit in Chat.Limits() do
		if Limit.resetsAt and Limit.utilization and Limit.utilization >= 0.99 and Limit.resetsAt > os.time() then
			return
		end
	end

	Chat.Continue(Last.Prompt)
end

function Chat.Continue(Prompt: string?)
	if Chat.Sending() then
		return
	end

	const Again = if typeof(Prompt) == "string" and Prompt ~= "" then Prompt else "Continue"

	assert(Start)({
		Display = Again,
		Full = Again,
		Attachments = {},
		Images = {},
		Previews = {},
	} :: Types.QueuedMessage)
end

function Chat.MoveQueued(Index: number, Delta: number)
	const Queue = Chat.Queue()
	const Target = Index + Delta

	if not Queue[Index] or not Queue[Target] then
		return
	end

	Chat.Queue(Replaced(Replaced(Queue, Index, Queue[Target]), Target, Queue[Index]))
end

function Chat.EditQueued(Index: number, Text: string)
	const Entry = Chat.Queue()[Index]

	if not Entry or not Text:match("%S") or Text == Entry.Display then
		return
	end

	Chat.Queue(Replaced(Chat.Queue(), Index, With(Entry, {
		Display = Text,
		Full = `{Text}{Entry.Extra or ""}`,
	})))
end

function Chat.Retry(Index: number)
	const Message = Chat.Messages()[Index]

	if not Message or Message.Role ~= "user" or Message.Text == "" then
		return
	end

	Chat.Send(Message.Text)
end

function Chat.InterruptWith(Index: number)
	const Queue = table.clone(Chat.Queue() :: {Types.QueuedMessage})
	const Entry = table.remove(Queue, Index)

	if not Entry then
		return
	end

	Chat.Queue(Queue)

	if Chat.Sending() and Chat.RequestId then
		const Sent = Client.SendNow(Entry.Full, Chat.ConversationId(), Chat.RequestId, Entry.Images)

		if Sent then
			DestroyImages(Entry.Previews)

			return
		end

		Chat.Stop()
	end

	assert(Start)(Entry)
end

function Chat.RemoveQueued(Index: number)
	const Queue = table.clone(Chat.Queue() :: {Types.QueuedMessage})
	const Entry = table.remove(Queue, Index)

	Chat.Queue(Queue)

	if not Entry then
		return
	end

	DestroyImages(Entry.Previews)

	const Draft = Chat.Draft()

	Chat.Draft(if Draft == "" then Entry.Display else `{Draft}\n{Entry.Display}`)
end

function Chat.Reply(Answers: {[string]: string}?)
	const Asked = Chat.Question()

	if not Asked then
		return
	end

	if not Chat.RequestId then
		Chat.Question(nil)

		return
	end

	const Answering = Chat.RequestId :: string

	task.spawn(function()
		const Ok = Client.AnswerQuestion(Answering, Asked.id, Answers)

		if Ok and Chat.Question() == Asked then
			Chat.Question(nil)
		end
	end)
end

function Chat.Answer(Allow: boolean, Always: boolean)
	const Permission = Chat.Permission()

	if not Permission or not Chat.RequestId then
		return
	end

	const Answering = Chat.RequestId :: string

	task.spawn(function()
		const Ok = Client.AnswerPermission(Answering, Permission.id, Allow, Always)

		if Ok and Chat.Permission() == Permission then
			Chat.Permission(nil)
		end
	end)
end

function Chat.Stop()
	const RequestId = Chat.RequestId

	if not RequestId then
		Stopping = Generation
		Chat.Sending(false)

		return
	end

	Chat.Sending(false)
	task.spawn(Client.CancelTurn, RequestId)
end

function Chat.Unload()
	Watching = false
	Chat.RequestId = nil

	Chat.Sending(false)
	Watcher.Stop()
	Reset()
end

return Chat