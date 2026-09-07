--!strict
const Settings = require(script.Parent.Settings)
const Format = require(script.Parent.Format)

export type Entry = {
	Object: Instance?,
	Path: string,
	Verb: string,
	Class: string?,
	Fields: {string},
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

const Verbs = {
	Name = "Renamed",
	Parent = "Moved",
	Size = "Resized",
	Scale = "Resized",
	CFrame = "Moved",
	Position = "Moved",
	Orientation = "Moved",
	Rotation = "Moved",
	PivotOffset = "Moved",
	Source = "Edited",
	Color = "Restyled",
	Color3 = "Restyled",
	BrickColor = "Restyled",
	Material = "Restyled",
	MaterialVariant = "Restyled",
	Transparency = "Restyled",
	Reflectance = "Restyled",
	TextureID = "Restyled",
	Image = "Restyled",
	BackgroundColor3 = "Restyled",
	TextColor3 = "Restyled",
	Text = "Retyped",
	Anchored = "Changed physics on",
	CanCollide = "Changed physics on",
	CanTouch = "Changed physics on",
	CanQuery = "Changed physics on",
	Massless = "Changed physics on",
	Enabled = "Toggled",
	Disabled = "Toggled",
	Visible = "Toggled",
	Value = "Set",
}

const Noise = {
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
local Connections: {RBXScriptConnection} = {}
local Turn = NewBucket()
local Idle = NewBucket()
local Recording = false
local Paused = false
local Skipped = false
local Busy = false

const function CurrentBucket(): Bucket
	return if Recording and Busy then Turn else Idle
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
		if Parent == game then
			return Roots[Highest.Name] == true
		end

		Highest = Parent
		Parent = Highest.Parent
	end

	return false
end

const function Counted(Of: {[Instance]: any}): number
	local Total = 0

	for _ in Of do
		Total += 1
	end

	return Total
end

const function Record(Object: Instance?, Path: string, Verb: string, Class: string?, Field: string?)
	const Where = CurrentBucket()

	if #Where.Entries >= 500 then
		return
	end

	const Key = `{if Object then Object:GetDebugId() else Path}|{Verb}`
	const Found = Where.Keys[Key]

	if Found then
		if not Field then
			return
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
	}

	Where.Keys[Key] = Made
	table.insert(Where.Entries, Made)
end

const function AddListener(Object: Instance)
	if Listeners[Object] or Skipped or not IsWatched(Object) then
		return
	end

	Listeners[Object] = Object.Changed:Connect(function(Field: string)
		if Paused or Noise[Field] or StudioOwns(Object, Field) then
			return
		end

		const Where = CurrentBucket()

		if Where.Created[Object] or Where.Deleted[Object] then
			return
		end

		if Field == "Parent" and (Object.Parent == nil or not IsWatched(Object)) then
			return
		end

		Record(Object, Object:GetFullName(), Verbs[Field] or "Changed", nil, Field)
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

	if Listener then
		Listener:Disconnect()
		Listeners[Object] = nil
	end

	if Paused or not IsWatched(Object) then
		return
	end

	const Where = CurrentBucket()
	const Parent = Object.Parent

	if Counted(Where.Deleted) >= 500 then
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

	Record(nil, Object:GetFullName(), "Deleted", Object.ClassName)
end

const function Render(Where: Bucket): {string}
	const Lines = {}

	for _, Item in Where.Entries do
		const Object = Item.Object
		const Path = Format.Path(if Object and Object.Parent then Object:GetFullName() else Item.Path)

		if Item.Verb == "Created" and Item.Class then
			table.insert(Lines, `Created {Path} ({Item.Class})`)
		elseif Item.Verb == "Changed" and #Item.Fields > 0 then
			table.insert(Lines, `Changed {table.concat(Item.Fields, ", ")} on {Path}`)
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

	for _, Connection in Connections do
		Connection:Disconnect()
	end

	for _, Listener in Listeners do
		Listener:Disconnect()
	end

	table.clear(Connections)
	table.clear(Listeners)
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
	Busy = Value
end

function Watcher.GetTurnChanges(): {string}?
	Recording = false
	Busy = false

	const Lines = if Settings.Get("WatchChanges")() then Render(Turn) else nil

	Clear(Turn)

	return Lines
end

function Watcher.GetUserChanges(): {string}
	const Lines = if Settings.Get("WatchChanges")() then Render(Idle) else {}

	Clear(Idle)

	return Lines
end

function Watcher.Reset()
	Recording = false
	Busy = false
	Clear(Turn)
	Clear(Idle)
end

return Watcher