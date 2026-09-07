--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const EncodingService = game:GetService("EncodingService")
const HttpService = game:GetService("HttpService")

const Settings = require(script.Parent.Parent.Settings)

const Name = "ClaudioBridgeRelay"

const Methods: {[string]: "DELETE" | "GET" | "POST"} = {
	DELETE = "DELETE",
	GET = "GET",
	POST = "POST",
}

const Relay = {}

const function Digest(Secret: string, Message: string): string
	const Inner = EncodingService:ComputeStringHash(Secret .. Message, Enum.HashAlgorithm.Sha256)

	return EncodingService:ComputeStringHash(Secret .. Inner, Enum.HashAlgorithm.Sha256)
end

function Relay.Sign(Nonce: string, Method: string, Url: string, Body: string?): string
	const Secret = Settings.Get("RelayToken")()

	if Secret == "" then
		return ""
	end

	return Digest(Secret, `ask|{Nonce}|{Method}|{Url}|{Body or ""}`)
end

function Relay.SignReply(Nonce: string, Status: number?, Body: string?): string
	const Secret = Settings.Get("RelayToken")()

	if Secret == "" then
		return ""
	end

	return Digest(Secret, `answer|{Nonce}|{tostring(Status)}|{Body or ""}`)
end

function Relay.Serve()
	const Existing = ReplicatedStorage:FindFirstChild(Name)

	if Existing then
		Existing:Destroy()
	end

	const Remote = Instance.new("RemoteFunction")
	const Used = {}
	local Count = 0

	Remote.Name = Name

	Remote.OnServerInvoke = function(_, Nonce: string, Signature: string, Method: string, Url: string, Body: string?): (boolean, ...(boolean | number | string)?)
		if typeof(Nonce) ~= "string" or typeof(Signature) ~= "string" or Signature == "" then
			return false, "That request did not come from Claudio"
		end

		if Used[Nonce] then
			return false, "That request was already made"
		end

		if typeof(Url) ~= "string" or not Url:match("^http://127%.0%.0%.1:%d+/") then
			return false, "That address is not the local bridge"
		end

		const Verb = Methods[Method]

		if not Verb then
			return false, "Claudio does not send that kind of request"
		end

		if Signature ~= Relay.Sign(Nonce, Method, Url, Body) then
			return false, "That request did not come from Claudio"
		end

		if Count > 5000 then
			table.clear(Used)
			Count = 0
		end

		Used[Nonce] = true
		Count += 1

		const Ok, Response = pcall(function()
			return HttpService:RequestAsync({
				Url = Url,
				Method = Verb,
				Headers = {
					["Content-Type"] = "application/json",
					["X-Claudio-Token"] = Settings.Token(),
				},
				Body = Body,
				Timeout = 60,
			})
		end)

		if not Ok then
			return false, tostring(Response)
		end

		return true, Response.Success, Response.StatusCode, Response.Body, Relay.SignReply(Nonce, Response.StatusCode, Response.Body)
	end

	Remote.Parent = ReplicatedStorage
end

function Relay.Find(): RemoteFunction?
	for _ = 1, 20 do
		const Found = ReplicatedStorage:FindFirstChild(Name)

		if Found then
			return Found :: RemoteFunction
		end

		task.wait(0.1)
	end

	return nil
end

return Relay