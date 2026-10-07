--!nocheck
--!nolint DeprecatedApi
const Fresh = {}

local Loaded: {[ModuleScript]: {any}} = {}
const Loading: {[ModuleScript]: boolean} = {}

local Load: (any) -> any

Load = function(Target: any): any
	if typeof(Target) ~= "Instance" or not Target:IsA("ModuleScript") then
		return require(Target)
	end

	const Held = Loaded[Target]

	if Held then
		return Held[1]
	end

	if Loading[Target] then
		error(`{Target:GetFullName()} requires itself through a loop of modules, so it cannot finish loading.`, 2)
	end

	const Chunk, Problem = loadstring(Target.Source, `={Target:GetFullName()}`)

	if not Chunk then
		error(Problem, 2)
	end

	setfenv(Chunk, setmetatable({
		script = Target,
		require = Load,
	}, {__index = getfenv(0)}))

	Loading[Target] = true

	const Results = table.pack(xpcall(Chunk, function(Trouble: any): any
		return Trouble
	end))

	Loading[Target] = nil

	if not Results[1] then
		error(Results[2], 0)
	end

	if Results.n ~= 2 then
		error(`{Target:GetFullName()} returned {Results.n - 1} values; a module must return exactly one.`, 2)
	end

	Loaded[Target] = {Results[2]}

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