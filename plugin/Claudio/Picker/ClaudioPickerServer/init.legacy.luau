--!strict
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Link = Instance.new("RemoteEvent")

Link.Name = "ClaudioPicker"
Link.Parent = ReplicatedStorage

const function Send(Name: string, Description: string): (boolean, string)
	const Ok, Result = pcall(function()
		HttpService:PostAsync(`http://127.0.0.1:{script:GetAttribute("Port") or 47225}/picker`, HttpService:JSONEncode({
			name = Name:sub(1, 120),
			description = Description:sub(1, 8000),
		}), Enum.HttpContentType.ApplicationJson)
	end)

	return Ok, if Ok then "" else tostring(Result)
end

const function Dress(Player: Player)
	const Gui = Player:WaitForChild("PlayerGui")
	const Existing = Gui:FindFirstChild("ClaudioPickerClient")

	if Existing then
		Existing:Destroy()
	end

	const Copy = script.ClaudioPickerClient:Clone()

	Copy.Disabled = false
	Copy.Parent = Gui
end

Link.OnServerEvent:Connect(function(Player: Player, Name: any, Description: any)
	if type(Name) ~= "string" or type(Description) ~= "string" or Name == "" then
		return
	end

	const Ok, Problem = Send(Name, Description)

	Link:FireClient(Player, Ok, if Ok then Name else Problem)
end)

for _, Player in Players:GetPlayers() do
	task.spawn(Dress, Player)
end

Players.PlayerAdded:Connect(Dress)