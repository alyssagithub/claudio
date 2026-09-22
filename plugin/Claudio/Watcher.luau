--!strict
const Settings = require(script.Parent.Settings)
const Format = require(script.Parent.Format)
const Types = require(script.Parent.Types)
const Breathe = require(script.Parent.Breathe)

export type Entry = {
	Object: Instance?,
	Path: string,
	Verb: string,
	Class: string?,
	Fields: {string},
	Values: {[string]: string},
	Before: string?,
}

export type Bucket = {
	Entries: {Entry},
	Keys: {[string]: Entry},
	Created: {[Instance]: boolean},
	Deleted: {[Instance]: boolean},
}

const Watcher = {}

const Roots = {
	Workspace = true,
	Lighting = true,
	ReplicatedFirst = true,
	ReplicatedStorage = true,
	ServerScriptService = true,
	ServerStorage = true,
	StarterGui = true,
	StarterPack = true,
	StarterPlayer = true,
	SoundService = true,
	Teams = true,
	MaterialService = true,
	TextChatService = true,
}

const Noise = {
	CFrame = true,
	Rotation = true,
	Mass = true,
	AssemblyMass = true,
	AssemblyCenterOfMass = true,
	AssemblyRootPart = true,
	AssemblyLinearVelocity = true,
	AssemblyAngularVelocity = true,
	CenterOfMass = true,
	CurrentPhysicalProperties = true,
	NetworkOwner = true,
	RootPart = true,
	TextBounds = true,
	TextFits = true,
	OpenTypeFeaturesError = true,
	TextureContent = true,
	MeshContent = true,
	CurrentCamera = true,
	AbsoluteSize = true,
	AbsolutePosition = true,
	AbsoluteRotation = true,
	AbsoluteCanvasSize = true,
	AbsoluteContentSize = true,
	AbsoluteCellCount = true,
	AbsoluteCellSize = true,
	ContentText = true,
	Loaded = true,
	LocalTransparencyModifier = true,
	IsLoaded = true,
	ClusterId = true,
	CurrentEditor = true,
	Selected = true,
}

const Cap = 25

const function NewBucket(): Bucket
	return {
		Entries = {},
		Keys = {},
		Created = {},
		Deleted = {},
	}
end

local Watching = false
local Listeners: {[Instance]: RBXScriptConnection} = {}
local Attributes: {[Instance]: RBXScriptConnection} = {}
local Sources: {[Instance]: string} = {}
local Paths: {[Instance]: string} = {}
local Connections: {RBXScriptConnection} = {}
local Turn = NewBucket()
local Idle = NewBucket()
local Recording = false
local Paused = false
local Skipped = false
local Busy = false
local BusyUntil = 0
local Jobs = 0
local JobsUntil = 0

const function CurrentBucket(): Bucket?
	if Recording and (Busy or os.clock() < BusyUntil) then
		return Turn
	end

	if Jobs > 0 or os.clock() < JobsUntil then
		return if Recording then Turn else nil
	end

	return Idle
end

const Own = script.Parent

const Studios: {[string]: {[string]: boolean}} = {
	StarterGui = {
		ProcessUserInput = true,
		ShowDevelopmentGui = true,
	},
	Workspace = {DistributedGameTime = true},
	Lighting = {TimeOfDay = false},
}

const function StudioOwns(Object: Instance, Field: string?): boolean
	const Fields = Studios[Object.Name]

	return Field ~= nil and Fields ~= nil and Fields[Field] == true
end

const function IsWatched(Object: Instance): boolean
	if Object:IsA("Camera") or Object:IsA("Terrain") then
		return false
	end

	if Object == Own or Object:IsDescendantOf(Own) then
		return false
	end

	local Highest = Object
	local Parent = Highest.Parent

	while Parent do
		if Highest.Name:sub(1, 7) == "Claudio" then
			return false
		end

		if Parent == game then
			return Roots[Highest.Name] == true
		end

		Highest = Parent
		Parent = Highest.Parent
	end

	return false
end

const function Shown(Value: any): string
	const Kind = typeof(Value)

	if Kind == "string" then
		return if #Value > 40 then `"{Value:sub(1, 37)}..."` else `"{Value}"`
	end

	if Kind == "Instance" then
		return (Value :: Instance).Name
	end

	if Kind == "EnumItem" then
		return (Value :: EnumItem).Name
	end

	const Text = tostring(Value)

	return if #Text > 40 then `{Text:sub(1, 37)}...` else Text
end

const function Counted(Of: {[Instance]: any}): number
	local Total = 0

	for _ in Of do
		Total += 1
	end

	return Total
end

const function Record(Object: Instance?, Path: string, Verb: string, Class: string?, Field: string?, Value: string?)
	const Where = CurrentBucket()

	if not Where or #Where.Entries >= 500 then
		return
	end

	const Key = `{if Object then Object:GetDebugId() else Path}|{Verb}`
	const Found = Where.Keys[Key]

	if Found then
		if not Field then
			return
		end

		if Value then
			Found.Values[Field] = Value
		end

		for _, Existing in Found.Fields do
			if Existing == Field then
				return
			end
		end

		table.insert(Found.Fields, Field)

		return
	end

	const Made: Entry = {
		Object = Object,
		Path = Path,
		Verb = Verb,
		Class = Class,
		Fields = if Field then {Field} else {},
		Values = if Field and Value then {[Field] = Value} else {},
	}

	Where.Keys[Key] = Made
	table.insert(Where.Entries, Made)
end

const function AddListener(Object: Instance)
	if Listeners[Object] or Skipped or not IsWatched(Object) then
		return
	end

	if Object:IsA("LuaSourceContainer") then
		Sources[Object] = (Object :: any).Source
	end

	Paths[Object] = Object:GetFullName()
	Listeners[Object] = Object.Changed:Connect(function(Field: string)
		if Field == "Name" or Field == "Parent" then
			Paths[Object] = Object:GetFullName()
		end

		if Paused or Noise[Field] or StudioOwns(Object, Field) then
			return
		end

		const Where = CurrentBucket()

		if not Where or Where.Created[Object] or Where.Deleted[Object] then
			return
		end

		if Field == "Parent" and (Object.Parent == nil or not IsWatched(Object)) then
			return
		end

		const Readable, Value = pcall(function()
			return (Object :: any)[Field]
		end)

		Record(Object, Object:GetFullName(), if Field == "Source" then "Edited" else "Changed", nil, Field, if Readable and Field ~= "Source" and Field ~= "Parent" then Shown(Value) else nil)

		if Field ~= "Source" then
			return
		end

		const Made = Where.Keys[`{Object:GetDebugId()}|Edited`]

		if Made and Made.Before == nil then
			Made.Before = Sources[Object] or ""
		end

		Sources[Object] = (Object :: any).Source
	end)

	Attributes[Object] = Object.AttributeChanged:Connect(function(Name: string)
		if Paused then
			return
		end

		const Where = CurrentBucket()

		if not Where or Where.Created[Object] or Where.Deleted[Object] then
			return
		end

		const Value = Object:GetAttribute(Name)

		Record(Object, Object:GetFullName(), "Changed", nil, `attribute {Name}`, if Value == nil then "nothing" else Shown(Value))
	end)
end

const function OnDescendantAdded(Object: Instance)
	if not IsWatched(Object) then
		return
	end

	AddListener(Object)

	if Paused then
		return
	end

	const Where = CurrentBucket()
	const Parent = Object.Parent

	if not Where then
		return
	end

	Where.Deleted[Object] = nil

	if Counted(Where.Created) >= 500 then
		return
	end

	Where.Created[Object] = true

	if Parent and Where.Created[Parent] then
		return
	end

	Record(Object, Object:GetFullName(), "Created", Object.ClassName)
end

const function OnDescendantRemoving(Object: Instance)
	const Listener = Listeners[Object]
	const Path = Paths[Object]

	if Listener then
		Listener:Disconnect()
		Listeners[Object] = nil
		Sources[Object] = nil
		Paths[Object] = nil
	end

	const Watched = Attributes[Object]

	if Watched then
		Watched:Disconnect()
		Attributes[Object] = nil
	end

	if Paused or (not Path and not IsWatched(Object)) then
		return
	end

	const Where = CurrentBucket()
	const Parent = Object.Parent

	if not Where or Counted(Where.Deleted) >= 500 then
		return
	end

	Where.Deleted[Object] = true

	if Parent and Where.Deleted[Parent] then
		return
	end

	if Where.Created[Object] then
		const Key = `{Object:GetDebugId()}|Created`
		const Made = Where.Keys[Key]

		Where.Keys[Key] = nil

		for Index, Item in Where.Entries do
			if Item == Made then
				table.remove(Where.Entries, Index)

				break
			end
		end

		return
	end

	Record(nil, Path or Object:GetFullName(), "Deleted", Object.ClassName)
end

const function Render(Where: Bucket): {string}
	const Lines = {}

	for _, Item in Where.Entries do
		const Object = Item.Object
		const Path = Format.Path(if Object and Object.Parent then Object:GetFullName() else Item.Path)

		if Item.Verb == "Created" and Item.Class then
			table.insert(Lines, `Created {Path} ({Item.Class})`)
		elseif Item.Verb == "Changed" and #Item.Fields > 0 then
			const Told = {}

			for _, Field in Item.Fields do
				const Value = Item.Values[Field]

				table.insert(Told, if Value then `{Field} to {Value}` else Field)
			end

			table.insert(Lines, `Set {table.concat(Told, ", ")} on {Path}`)
		else
			table.insert(Lines, `{Item.Verb} {Path}`)
		end
	end

	if #Lines <= Cap then
		return Lines
	end

	const Kept = table.move(Lines, 1, Cap, 1, {})

	table.insert(Kept, `and {#Lines - Cap} more changes`)

	return Kept
end

const function CountLines(Before: string, After: string): (number, number)
	const Old = if Before == "" then {} else Before:split("\n")
	const New = if After == "" then {} else After:split("\n")
	local Start = 1

	while Start <= #Old and Start <= #New and Old[Start] == New[Start] do
		Start += 1
	end

	local OldEnd = #Old
	local NewEnd = #New

	while OldEnd >= Start and NewEnd >= Start and Old[OldEnd] == New[NewEnd] do
		OldEnd -= 1
		NewEnd -= 1
	end

	const Removed = OldEnd - Start + 1
	const Added = NewEnd - Start + 1

	if Removed == 0 or Added == 0 or Removed * Added > 4000000 then
		return Added, Removed
	end

	local Row = table.create(Added + 1, 0)

	for Left = Start, OldEnd do
		Breathe()

		const Next = table.create(Added + 1, 0)

		for Right = Start, NewEnd do
			const At = Right - Start + 2

			Next[At] = if Old[Left] == New[Right] then Row[At - 1] + 1 else math.max(Row[At], Next[At - 1])
		end

		Row = Next
	end

	return Added - Row[Added + 1], Removed - Row[Added + 1]
end

const function Describe(Where: Bucket): {Types.Change}
	const Found: {Types.Change} = {}

	for Index, Item in Where.Entries do
		if Index > Cap then
			table.insert(Found, {
				Kind = "changed",
				Text = `and {#Where.Entries - Cap} more changes`,
			} :: Types.Change)

			break
		end

		const Object = Item.Object
		const Path = Format.Path(if Object and Object.Parent then Object:GetFullName() else Item.Path)
		const Change: Types.Change = {
			Kind = if Item.Verb == "Created" then "added" elseif Item.Verb == "Deleted" then "removed" else "changed",
			Text = Render({
				Entries = {Item},
				Keys = {},
				Created = {},
				Deleted = {},
			})[1],
			Path = Path,
		}

		if Object and Object:IsA("LuaSourceContainer") and (Item.Before or Item.Verb == "Created") then
			Change.Added, Change.Removed = CountLines(Item.Before or "", (Object :: any).Source)
		end

		table.insert(Found, Change)
	end

	return Found
end

const function Clear(Where: Bucket)
	table.clear(Where.Entries)
	table.clear(Where.Keys)
	table.clear(Where.Created)
	table.clear(Where.Deleted)
end

function Watcher.Start()
	if Watching then
		return
	end

	Watching = true
	Paused = false

	local Total = 0

	for Name in Roots do
		const Service = game:FindFirstChild(Name)

		if Service then
			Total += #Service:GetDescendants()
		end
	end

	Skipped = Total > 60000

	if not Skipped then
		for Name in Roots do
			const Service = game:FindFirstChild(Name)

			if Service then
				AddListener(Service)

				for _, Object in Service:GetDescendants() do
					Breathe()
					AddListener(Object)
				end
			end
		end
	end

	table.insert(Connections, game.DescendantAdded:Connect(OnDescendantAdded))
	table.insert(Connections, game.DescendantRemoving:Connect(OnDescendantRemoving))
end

function Watcher.Stop()
	Watching = false
	Recording = false
	Paused = false
	Busy = false
	Jobs = 0

	for _, Connection in Connections do
		Connection:Disconnect()
	end

	for _, Listener in Listeners do
		Listener:Disconnect()
	end

	for _, Watched in Attributes do
		Watched:Disconnect()
	end

	table.clear(Connections)
	table.clear(Listeners)
	table.clear(Attributes)
	table.clear(Paths)
	table.clear(Sources)
	Clear(Turn)
	Clear(Idle)
end

function Watcher.Pause(Value: boolean)
	Paused = Value
end

function Watcher.BeginTurn()
	Clear(Turn)
	Recording = true
	Busy = false
end

function Watcher.SetBusy(Value: boolean)
	if Busy and not Value then
		BusyUntil = os.clock() + 2
	end

	Busy = Value
end

function Watcher.BeginJob()
	Jobs += 1
end

function Watcher.EndJob()
	Jobs = math.max(0, Jobs - 1)
	JobsUntil = os.clock() + 2
end

function Watcher.GetTurnChanges(): {Types.Change}?
	Recording = false
	Busy = false

	const Found = if Settings.Get("WatchChanges")() then Describe(Turn) else nil

	Clear(Turn)

	return Found
end

function Watcher.GetUserChanges(): {Types.Change}
	const Found = if Settings.Get("WatchChanges")() then Describe(Idle) else {}

	Clear(Idle)

	return Found
end

function Watcher.Peek(): ({string}, {string})
	return Render(Turn), Render(Idle)
end

function Watcher.Reset()
	Recording = false
	Busy = false
	Jobs = 0
	Clear(Turn)
	Clear(Idle)
end

return Watcher