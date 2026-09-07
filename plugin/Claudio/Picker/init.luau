--!strict
const ServerScriptService = game:GetService("ServerScriptService")
const HttpService = game:GetService("HttpService")

const Vide = require(script.Parent.Packages.vide)
const Settings = require(script.Parent.Settings)
const Client = require(script.Parent.Client.Client)

const Picker = {
	Active = Vide.source(false),
}

local Watching = 0

function Picker.Installed(): boolean
	return ServerScriptService:FindFirstChild("ClaudioPickerServer") ~= nil
end

function Picker.Install()
	const Existing = ServerScriptService:FindFirstChild("ClaudioPickerServer")

	if Existing then
		Existing:Destroy()
	end

	const Copy = script.ClaudioPickerServer:Clone()

	Copy:SetAttribute("Port", Settings.Get("Port")())
	Copy.Disabled = false
	Copy.Parent = ServerScriptService

	pcall(function()
		HttpService.HttpEnabled = true
	end)
end

function Picker.Remove()
	const Existing = ServerScriptService:FindFirstChild("ClaudioPickerServer")

	if Existing then
		Existing:Destroy()
	end
end

function Picker.Watch(OnPick: (string, string) -> ())
	Watching += 1

	const Mine = Watching

	task.spawn(function()
		while Watching == Mine and task.wait(2) do
			if not Settings.Get("PlaytestPicker")() then
				continue
			end

			const Ok, State = Client.GetPicker()

			if not Ok or typeof(State) ~= "table" or typeof(State.picks) ~= "table" then
				continue
			end

			for _, Pick in State.picks do
				if typeof(Pick) ~= "table" then
					continue
				end

				const Name = Pick.name

				if typeof(Name) ~= "string" then
					continue
				end

				const Description = Pick.description

				OnPick(Name:sub(1, 120), if typeof(Description) == "string" then Description:sub(1, 2000) else "")
			end
		end
	end)
end

function Picker.Unwatch()
	Watching += 1
end

return Picker