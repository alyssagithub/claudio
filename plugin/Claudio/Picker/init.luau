--!strict
const ServerScriptService = game:GetService("ServerScriptService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Vide = require(script.Parent.Packages.vide)
const Settings = require(script.Parent.Settings)
const Client = require(script.Parent.Client.Client)
const Runtime = require(script.Parent.Runtime)
const Theme = require(script.Parent.App.Theme)

const Picker = {
	Active = Vide.source(false),
}

local Watching = 0

function Picker.Installed(): boolean
	return ServerScriptService:FindFirstChild("ClaudioPickerServer") ~= nil
end

function Picker.Start(CurrentPlugin: Plugin)
	if not Settings.Get("PlaytestPicker")() then
		return
	end

	if RunService:IsServer() then
		const Key = Client.PlaytestKey() or ""
		const Copy = script.ClaudioPickerServer:Clone()

		Runtime.Fill(Copy, Key)
		Copy.Disabled = false
		Copy.Parent = ServerScriptService

		if Key ~= "" then
			CurrentPlugin.Unloading:Connect(function()
				Client.RevokePlaytestKey(Key)
			end)
		end

		return
	end

	const Player = Players.LocalPlayer
	const Deadline = os.clock() + 120

	local Gui = if Player then Player:FindFirstChildOfClass("PlayerGui") else nil

	while not Gui and os.clock() < Deadline and task.wait(0.25) do
		Gui = if Player then Player:FindFirstChildOfClass("PlayerGui") else nil
	end

	if not Gui then
		return
	end

	const Copy = script.ClaudioPickerServer.ClaudioPickerClient:Clone()

	for _, Name in {
		"Background",
		"Panel",
		"Text",
		"DimText",
		"Button",
		"ButtonText",
		"Accent",
		"AccentText",
		"Border",
		"Error",
	} do
		Copy:SetAttribute(Name, Theme.Colors[Name]())
	end

	Copy.Disabled = false
	Copy.Parent = Gui
end

function Picker.Remove()
	const Existing = ServerScriptService:FindFirstChild("ClaudioPickerServer")

	if Existing then
		Runtime.Revoke(Existing)
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