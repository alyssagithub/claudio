--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerScriptService = game:GetService("ServerScriptService")

const Settings = require(script.Parent.Parent.Settings)
const Scoped = require(script.Parent.Scoped)

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

	Bindable.OnInvoke = function(Given: any, Source: any, Within: any, Current: any): any
		const Key = Settings.Get("BuildKey")()

		if Key == "" or Given ~= Key then
			return nil
		end

		if typeof(Source) == "table" and typeof(Source.quality) == "number" then
			const Level = math.clamp(math.round(Source.quality), 1, 10)
			const Rendered, Trouble = pcall(function()
				(settings() :: any).Rendering.QualityLevel = (Enum.QualityLevel :: any)[`Level{string.format("%02d", math.clamp(Level * 2 - 1, 1, 21))}`]
			end)

			return if Rendered then {now = tostring((settings() :: any).Rendering.QualityLevel)} else {error = `Studio refused the graphics level: {tostring(Trouble)}`}
		end

		if typeof(Source) ~= "string" then
			return nil
		end

		local Text = Source

		if typeof(Within) == "string" and Within ~= "" then
			const Spliced, _, Trouble = Scoped.Splice(Within, Source, if typeof(Current) == "string" then Current else nil)

			if not Spliced then
				return Trouble
			end

			Text = Spliced
		end

		const Payload = Instance.new("ModuleScript")

		Payload.Name = "ClaudioPayload"

		const Written = pcall(function()
			(Payload :: any).Source = Text
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