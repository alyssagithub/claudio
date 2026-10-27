--!nocheck
--!nolint DeprecatedApi
const Pacing = require(script.Parent.Pacing)

const Fresh = {}

local Loaded: {[ModuleScript]: {Value: any, Source: string}} = {}
const Loading: {[ModuleScript]: boolean} = {}

local Load: (any, Instance?) -> any
local Rested = os.clock()
local Depth = 0

const function Pace()
	if os.clock() - Rested < 0.03 or not coroutine.isyieldable() then
		return
	end

	task.wait()
	Rested = os.clock()
end

const function Resolve(Path: string, From: Instance?): Instance
	if not From then
		error(`Cannot follow "{Path}" because it was not required from a module.`, 3)
	end

	const Parts = string.split(Path, "/")
	local At: Instance? = nil
	local Start = 1

	if Parts[1] == "@self" then
		At = From
		Start = 2
	elseif Parts[1] == "@game" then
		At = game
		Start = 2
	elseif Parts[1] == "." then
		At = From.Parent
		Start = 2
	elseif Parts[1] == ".." then
		At = if From.Parent then From.Parent.Parent else nil
		Start = 2
	else
		error(`Cannot follow "{Path}" from {From:GetFullName()}: paths must start with ./, ../, @self or @game.`, 3)
	end

	for Index = Start, #Parts do
		const Part = Parts[Index]

		if not At then
			break
		end

		if Part == ".." then
			At = At.Parent
		elseif Part ~= "." and Part ~= "" then
			const Next = At:FindFirstChild(Part)

			if not Next then
				error(`Cannot follow "{Path}" from {From:GetFullName()}: {At:GetFullName()} has no child named "{Part}".`, 3)
			end

			At = Next
		end
	end

	if not At or not At:IsA("ModuleScript") then
		error(`"{Path}" from {From:GetFullName()} does not lead to a ModuleScript.`, 3)
	end

	return At
end

Load = function(Target: any, From: Instance?): any
	if typeof(Target) == "string" then
		Target = Resolve(Target, From)
	end

	if typeof(Target) ~= "Instance" or not Target:IsA("ModuleScript") then
		return require(Target)
	end

	const Held = Loaded[Target]

	if Held and Held.Source == Target.Source then
		return Held.Value
	end

	if Loading[Target] then
		error(`{Target:GetFullName()} requires itself through a loop of modules, so it cannot finish loading.`, 2)
	end

	const Chunk, Problem = loadstring(Pacing.Insert(Target.Source, "__ClaudioPace"), `={Target:GetFullName()}`)

	if not Chunk then
		error(Problem, 2)
	end

	setfenv(Chunk, setmetatable({
		script = Target,
		__ClaudioPace = Pace,
		require = function(Wanted: any): any
			return Load(Wanted, Target)
		end,
	}, {__index = getfenv(0)}))

	Loading[Target] = true
	Depth += 1

	const Mine = Depth
	const Began = os.clock()
	local Results: any
	const function Execute()
		Results = table.pack(xpcall(Chunk, function(Trouble: any): any
			return Trouble
		end))
	end
	const Worker = if coroutine.isyieldable() then task.spawn(Execute) else nil

	if not Worker then
		Execute()
	end

	while not Results and Worker do
		if Depth == Mine and os.clock() - math.max(Rested, Began) > 5 and coroutine.status(Worker) == "suspended" then
			const Where = {}

			for Line in debug.traceback(Worker :: thread):gmatch("[^\n]+") do
				table.insert(Where, Line)
			end

			task.cancel(Worker :: thread)
			Loading[Target] = nil
			Depth -= 1

			error(`{Target:GetFullName()} did not finish loading: its top-level code has been waiting for over 5 seconds, most likely for something that only exists in a running game, such as an instance or remote the server creates. Load it in a playtest instead, or test the parts that do not need it. It was waiting at:\n{table.concat(Where, "\n")}`, 0)
		end

		task.wait(0.1)
	end

	Loading[Target] = nil
	Depth -= 1

	if not Results[1] then
		error(Results[2], 0)
	end

	if Results.n ~= 2 then
		error(`{Target:GetFullName()} returned {Results.n - 1} values; a module must return exactly one.`, 2)
	end

	Loaded[Target] = {Value = Results[2], Source = Target.Source}

	return Results[2]
end

function Fresh.Load(Module: ModuleScript): any
	return Load(Module)
end

function Fresh.Clear()
	Loaded = {}
	table.clear(Loading)
end

return Fresh