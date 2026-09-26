--!strict
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Token = "{{Token}}"

script.Parent = nil

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

Link.OnServerEvent:Connect(function(Player: Player, Name: any, Description: any)
	if type(Name) ~= "string" or type(Description) ~= "string" or Name == "" then
		return
	end

	const Ok, Problem = Send(Name, Description)

	Link:FireClient(Player, Ok, if Ok then Name else Problem)
end)