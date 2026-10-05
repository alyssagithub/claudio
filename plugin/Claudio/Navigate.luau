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
	const Pieces: {{Name: string, Exact: boolean}} = {}
	local At = 1
	const Given = Path:gsub("^[Gg]ame%.", "")

	while At <= #Given do
		const Quote, Inside = Given:match("^%[([\"'])(.-)%1%]", At)

		if Quote then
			table.insert(Pieces, {
				Name = Inside :: string,
				Exact = true,
			})
			At += #(Inside :: string) + 4
		else
			const Name = Given:match("^[^%.%[]+", At)

			if not Name then
				At += 1

				continue
			end

			table.insert(Pieces, {
				Name = Name,
				Exact = false,
			})
			At += #Name
		end

		if Given:sub(At, At) == "." then
			At += 1
		end
	end

	local Current: Instance = game
	local Resolved = "game"
	local Index = 1

	while Index <= #Pieces do
		local Child: Instance?
		local Used = 1

		if Pieces[Index].Exact then
			Child = Current:FindFirstChild(Pieces[Index].Name)
		else
			local Last = Index

			while Last < #Pieces and not Pieces[Last + 1].Exact do
				Last += 1
			end

			for Stop = Last, Index, -1 do
				const Names = {}

				for Step = Index, Stop do
					table.insert(Names, Pieces[Step].Name)
				end

				const Name = table.concat(Names, ".")

				Child = Current:FindFirstChild(Name)

				if not Child and Current == game and Stop == Index then
					const Found, Service = pcall(game.GetService, game, Name)

					Child = if Found then Service else nil
				end

				if Child then
					Used = Stop - Index + 1

					break
				end
			end
		end

		if not Child then
			return nil, nil
		end

		Current = Child
		Resolved = `{Resolved}.{Child.Name}`
		Index += Used
	end

	if Current == game then
		return nil, nil
	end

	return Current, Resolved
end

local LastText = ""
local LastMentioned: {{Path: string, Line: string}} = {}

function Navigate.FindReferences(Text: string): {Types.Reference}
	if Text ~= LastText then
		const Mentioned = {}

		for _, RootName in RootNames do
			for Path, Line in Text:gmatch(`%f[%w_]({RootName}%.[%w_%.]+):?(%d*)`) do
				table.insert(Mentioned, {
					Path = (Path:gsub("%.+$", "")),
					Line = Line,
				})
			end
		end

		LastText = Text
		LastMentioned = Mentioned
	end

	const Found = {}
	const Seen = {}

	for _, Mention in LastMentioned do
		const Object, Resolved = Navigate.Resolve(Mention.Path)

		if not Object or not Resolved or Seen[Resolved] or Object:IsA("ServiceProvider") or Object.Parent == game then
			continue
		end

		Seen[Resolved] = true
		table.insert(Found, {
			Path = Resolved,
			Line = if Object:IsA("LuaSourceContainer") then tonumber(Mention.Line) else nil,
		})
	end

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