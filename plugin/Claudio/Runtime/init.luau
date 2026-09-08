--!strict
const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")

const Settings = require(script.Parent.Settings)

const Runtime = {}

const function Scripts(): (Instance?, Instance?)
	return ServerScriptService:FindFirstChild("ClaudioRuntimeServer"), ReplicatedStorage:FindFirstChild("ClaudioRuntimeClient")
end

function Runtime.Installed(): boolean
	const Server, Client = Scripts()

	return Server ~= nil and Client ~= nil
end

function Runtime.Remove()
	const Server, Client = Scripts()

	if Server then
		Server:Destroy()
	end

	if Client then
		Client:Destroy()
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
		return true, nil
	end

	return false, `The play session cannot reach Claudio because HTTP requests are off for this place, and turning them on from here was refused: {if Ok then "the setting did not take" else tostring(Trouble)}. Turn on Allow HTTP Requests in Game Settings, then start the playtest again.`
end

function Runtime.Install()
	Runtime.Remove()

	const Server = (script :: any).ClaudioRuntimeServer:Clone()

	Server:SetAttribute("Port", Settings.Get("Port")())
	Server:SetAttribute("Token", Settings.Token())
	Server.Disabled = false

	pcall(function()
		Server.RunContext = Enum.RunContext.Server
	end)

	Server.Parent = ServerScriptService

	const Client = (script :: any).ClaudioRuntimeClient:Clone()

	Client.Disabled = false

	pcall(function()
		Client.RunContext = Enum.RunContext.Client
	end)

	Client.Parent = ReplicatedStorage

end

return Runtime