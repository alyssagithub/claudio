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

	Copy:ClearAllChildren()

	for _, Child in Module:GetChildren() do
		Child.Parent = Copy
	end

	Known[Module] = nil
	Module:Destroy()
	Copy.Parent = Where
	Known[Copy] = Hash(Copy)

	return Copy
end

function Fresh.Load(Module: ModuleScript): any
	for Object, Before in table.clone(Known) do
		Breathe()

		if Object ~= Module and Object.Parent and Hash(Object) ~= Before then
			Replace(Object)
		end
	end

	if not Module.Parent then
		error(`{Module.Name} was deleted, so it cannot be loaded fresh.`)
	end

	return (require :: any)(Replace(Module))
end

return Fresh
