--!strict
const Selection = game:GetService("Selection")
const ScriptEditorService = game:GetService("ScriptEditorService")

const Types = require(script.Parent.Types)

const RootNames = {
	"game",
	"Workspace",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPlayer",
	"StarterPack",
	"ReplicatedFirst",
	"Lighting",
	"SoundService",
	"Players",
	"Teams",
	"TextChatService",
}

const Navigate = {}

function Navigate.Resolve(Path: string): (Instance?, string?)
	local Current: Instance = game
	local Resolved = "game"

	for Name in Path:gsub("^game%.", ""):gmatch("[^%.]+") do
		const Child = Current:FindFirstChild(Name)

		if not Child then
			return nil, nil
		end

		Current = Child
		Resolved = `{Resolved}.{Name}`
	end

	if Current == game then
		return nil, nil
	end

	return Current, Resolved
end

local LastText = ""
local LastFound: {Types.Reference} = {}

function Navigate.FindReferences(Text: string): {Types.Reference}
	if Text == LastText then
		return LastFound
	end

	const Found = {}
	const Seen = {}

	for _, RootName in RootNames do
		for Path, Line in Text:gmatch(`%f[%w_]({RootName}%.[%w_%.]+):?(%d*)`) do
			const Object, Resolved = Navigate.Resolve((Path:gsub("%.+$", "")))

			if not Object or not Resolved or Seen[Resolved] or Object:IsA("ServiceProvider") or Object.Parent == game then
				continue
			end

			Seen[Resolved] = true
			table.insert(Found, {
				Path = Resolved,
				Line = if Object:IsA("LuaSourceContainer") then tonumber(Line) else nil,
			})
		end
	end

	LastText = Text
	LastFound = Found

	return Found
end

function Navigate.Go(Reference: Types.Reference): boolean
	const Object = Navigate.Resolve(Reference.Path)

	if not Object then
		return false
	end

	Selection:Set({Object})

	if not Object:IsA("LuaSourceContainer") then
		return true
	end

	pcall(function()
		ScriptEditorService:OpenScriptDocumentAsync(Object)
	end)

	const Document = ScriptEditorService:FindScriptDocument(Object)
	const Line = Reference.Line

	if Line and Document then
		pcall(function()
			Document:ForceSetSelectionAsync(Line, 1)
		end)
	end

	return true
end

return Navigate