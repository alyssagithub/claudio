--!strict
const Fresh = {}

const Copies: {Instance} = {}

const function Place(Object: Instance): number
	local Count = 0

	for _, Sibling in (Object.Parent :: Instance):GetChildren() do
		if Sibling.Name == Object.Name and Sibling.Archivable then
			Count += 1
		end

		if Sibling == Object then
			return Count
		end
	end

	return Count
end

function Fresh.Load(Module: ModuleScript): any
	if not Module:IsDescendantOf(game) or Module.Parent == game then
		error(`{Module.Name} is not in the place, so it cannot be loaded fresh.`)
	end

	const Path: {Instance} = {}
	local Step: Instance = Module

	while Step.Parent ~= game do
		if not Step.Archivable then
			error(`{Step:GetFullName()} has Archivable off, so it cannot be copied to load fresh.`)
		end

		table.insert(Path, 1, Step)
		Step = Step.Parent :: Instance
	end

	const Holder = Instance.new("Folder")

	Holder.Name = Step.Name

	for _, Child in Step:GetChildren() do
		const Copy = if Child.Archivable then Child:Clone() else nil

		if Copy then
			Copy.Parent = Holder
		end
	end

	table.insert(Copies, Holder)

	local Current: Instance = Holder

	for _, Original in Path do
		local Count = 0
		local Found: Instance?
		const Wanted = Place(Original)

		for _, Child in Current:GetChildren() do
			if Child.Name == Original.Name then
				Count += 1

				if Count == Wanted then
					Found = Child

					break
				end
			end
		end

		if not Found then
			error(`Could not find the copy of {Original:GetFullName()}.`)
		end

		Current = Found
	end

	return (require :: any)(Current)
end

function Fresh.Clear()
	for _, Holder in Copies do
		Holder:Destroy()
	end

	table.clear(Copies)
end

return Fresh