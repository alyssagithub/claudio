--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerScriptService = game:GetService("ServerScriptService")

const Name = "ClaudioBuild"

const Builder = {}

function Builder.Serve()
	const Where = if RunService:IsServer() then ServerScriptService else ReplicatedStorage
	const Existing = Where:FindFirstChild(Name)

	if Existing then
		Existing:Destroy()
	end

	const Bindable = Instance.new("BindableFunction")

	Bindable.Name = Name

	Bindable.OnInvoke = function(Source: any): any
		if typeof(Source) ~= "string" then
			return nil
		end

		const Payload = Instance.new("ModuleScript")

		Payload.Name = "ClaudioPayload"

		const Written = pcall(function()
			(Payload :: any).Source = Source
		end)

		if not Written then
			Payload:Destroy()

			return nil
		end

		Payload.Parent = Bindable

		return Payload
	end

	Bindable.Parent = Where
end

return Builder