--!strict
const Scoped = {}

function Scoped.Find(Path: string): Instance?
	local Object: Instance? = game

	for Index, Step in string.split(Path, ".") do
		if Index == 1 and (Step == "game" or Step == "Game") then
			continue
		end

		if not Object then
			return nil
		end

		Object = (Object :: Instance):FindFirstChild(Step)
	end

	return Object
end

function Scoped.Splice(Path: string, Wrapped: string, Current: string?): (string?, number, string?)
	const Module = Scoped.Find(Path)

	if not Module or not Module:IsA("ModuleScript") then
		return nil, 0, `Nothing at "{Path}" is a ModuleScript, so there is no scope to run inside.`
	end

	const Read, Source = pcall(function(): string
		return Current or (Module :: any).Source
	end)

	if not Read then
		return nil, 0, `Could not read the source of {Module:GetFullName()}: {tostring(Source)}`
	end

	const Lines = string.split(Source, "\n")
	local Last = 0

	for Index, Line in Lines do
		if Line:match("^return[%s%({]") or Line:match("^return$") then
			Last = Index
		end
	end

	if Last == 0 then
		return nil, 0, `{Module:GetFullName()} has no top-level return line, so Claudio cannot tell where its body ends.`
	end

	return `{table.concat(Lines, "\n", 1, Last - 1)}\n{Wrapped}`, Last - 1, nil
end

return Scoped
