--!strict
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Token = "{{Token}}"

const Link = Instance.new("RemoteEvent")

Link.Name = "ClaudioPicker"
Link.Parent = ReplicatedStorage

const function Send(Name: string, Description: string): (boolean, string)
	const Ok, Result = pcall(function()
		return HttpService:RequestAsync({
			Url = `http://127.0.0.1:{tonumber("{{Port}}") or 47225}/picker`,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["X-Claudio-Token"] = Token,
			},
			Body = HttpService:JSONEncode({
				name = Name:sub(1, 120),
				description = Description:sub(1, 8000),
			}),
		})
	end)

	if not Ok then
		return false, tostring(Result)
	end

	return Result.Success, if Result.Success then "" else `{Result.StatusCode} {Result.Body}`
end

const function Dress(Player: Player)
	local Gui = Player:FindFirstChildOfClass("PlayerGui")

	while not Gui and Player.Parent and Player.ChildAdded:Wait() do
		Gui = Player:FindFirstChildOfClass("PlayerGui")
	end

	if not Gui then
		return
	end

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