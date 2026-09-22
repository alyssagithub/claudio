--!strict
const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")

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
		Secret = Settings.Get("RelayToken")(),
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

function Runtime.Install()
	Runtime.Remove()

	const Server = (script :: any).ClaudioRuntimeServer:Clone()

	Runtime.Fill(Server, Client.PlaytestKey() or "")
	Server.Disabled = false

	pcall(function()
		Server.RunContext = Enum.RunContext.Server
	end)

	Server.Parent = ServerScriptService

	const Relay = (script :: any).ClaudioRuntimeClient:Clone()

	Runtime.Fill(Relay, "")
	Relay.Disabled = false

	pcall(function()
		Relay.RunContext = Enum.RunContext.Client
	end)

	Relay.Parent = ReplicatedStorage
end

return Runtime