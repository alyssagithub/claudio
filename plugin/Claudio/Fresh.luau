--!strict
const EncodingService = game:GetService("EncodingService")

const Breathe = require(script.Parent.Breathe)

const Fresh = {}

const Known: {[ModuleScript]: string} = {}

const function Hash(Module: ModuleScript): string
	return EncodingService:ComputeStringHash(Module.Source, Enum.HashAlgorithm.Sha256)
end

function Fresh.Snapshot()
	for _, Object in game:GetDescendants() do
		Breathe()

		if Object:IsA("ModuleScript") then
			Known[Object] = Hash(Object)
		end
	end
end

const function Replace(Module: ModuleScript): ModuleScript
	const Where = Module.Parent
	const Copy = Module:Clone()

	Known[Module] = nil
	Module:Destroy()
	Copy.Parent = Where
	Known[Copy] = Hash(Copy)

	return Copy
end

function Fresh.Load(Module: ModuleScript): any
	const Wanted = Module:GetFullName()

	for Object, Before in table.clone(Known) do
		Breathe()

		if Object ~= Module and Object.Parent and Hash(Object) ~= Before then
			Replace(Object)
		end
	end

	const Current = if Module.Parent then Module else require(script.Parent.Runtime.Scoped).Find(Wanted)

	if not Current or not Current:IsA("ModuleScript") then
		error(`{Wanted} is gone, so it cannot be loaded fresh.`)
	end

	return (require :: any)(Replace(Current))
end

return Fresh
