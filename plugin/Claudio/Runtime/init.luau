--!strict
const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")
const RunService = game:GetService("RunService")

const Settings = require(script.Parent.Settings)
const Client = require(script.Parent.Client.Client)

const Runtime = {}

local Switched = false

const function Scripts(): (Instance?, Instance?)
	return ServerScriptService:FindFirstChild("ClaudioRuntimeServer"), ReplicatedStorage:FindFirstChild("ClaudioRuntimeClient")
end

function Runtime.Fill(Script: Instance, Key: string)
	const Values = {
		Port = tostring(Settings.Get("Port")()),
		Token = Key,
		BuildKey = Settings.Get("BuildKey")(),
	}

	(Script :: any).Source = ((Script :: any).Source :: string):gsub("{{(%a+)}}", Values)
end

function Runtime.Revoke(Script: Instance)
	const Key = ((Script :: any).Source :: string):match('const Token = "([^"]*)"')

	if Key and Key ~= "" and Key ~= "{{Token}}" then
		task.spawn(Client.RevokePlaytestKey, Key)
	end
end

function Runtime.Remove()
	const Server, Relay = Scripts()

	if Server then
		Runtime.Revoke(Server)
		Server:Destroy()
	end

	if Relay then
		Relay:Destroy()
	end

	if Switched then
		Switched = false
		HttpService.HttpEnabled = false
	end
end

function Runtime.Reachable(): (boolean, string?)
	if HttpService.HttpEnabled then
		return true, nil
	end

	const Ok, Trouble = pcall(function()
		HttpService.HttpEnabled = true
	end)

	if HttpService.HttpEnabled then
		Switched = true

		return true, nil
	end

	return false, `The play session cannot reach Claudio because HTTP requests are off for this place, and turning them on from here was refused: {if Ok then "the setting did not take" else tostring(Trouble)}. Turn on Allow HTTP Requests in Game Settings, then start the playtest again.`
end

function Runtime.Start(CurrentPlugin: Plugin)
	const OnServer = RunService:IsServer()

	if Settings.Get("BuildKey")() == "" then
		Settings.Set("BuildKey", HttpService:GenerateGUID(false))
	end

	if OnServer then
		pcall(function()
			HttpService.HttpEnabled = true
		end)
	end

	const Key = if OnServer then Client.PlaytestKey() or "" else ""

	const function Launch(): Instance
		const Copy = (if OnServer then (script :: any).ClaudioRuntimeServer else (script :: any).ClaudioRuntimeClient):Clone()

		Runtime.Fill(Copy, Key)
		Copy.RunContext = if OnServer then Enum.RunContext.Server else Enum.RunContext.Client
		Copy.Disabled = false
		Copy.Parent = if OnServer then ServerScriptService else ReplicatedStorage

		return Copy
	end

	local Running = Launch()

	if OnServer then
		task.spawn(function()
			while task.wait(2) do
				const Beat = ServerScriptService:GetAttribute("ClaudioRuntimeBeat")

				if not RunService:IsRunning() or typeof(Beat) ~= "number" or os.clock() - Beat < 8 then
					continue
				end

				warn("Claudio's play session agent stopped, most likely because code it ran hit Roblox's script time limit, so it was started again.")
				Running:Destroy()
				require(script.Builder).Serve()
				ServerScriptService:SetAttribute("ClaudioRuntimeBeat", os.clock())
				Running = Launch()
			end
		end)
	end

	if Key ~= "" then
		CurrentPlugin.Unloading:Connect(function()
			Client.RevokePlaytestKey(Key)
		end)
	end
end

return Runtime