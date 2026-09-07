--!strict
const HttpService = game:GetService("HttpService")
const RunService = game:GetService("RunService")

const Relay = require(script.Parent.Relay)
const Settings = require(script.Parent.Parent.Settings)

export type Method = "DELETE" | "GET" | "POST"

const Http = {}

const function Decode(Body: string): (boolean, any)
	const Decoded, Data = pcall(HttpService.JSONDecode, HttpService, Body)

	if not Decoded then
		return false, "The bridge sent a reply that is not JSON"
	end

	return true, Data
end

const function ThroughRelay(Method: Method, Url: string, Body: any?): (boolean, any)
	const Remote = Relay.Find()

	if not Remote then
		return false, "The playtest side of Claudio has not started yet"
	end

	const Encoded = if Body then HttpService:JSONEncode(Body) else nil
	const Nonce = HttpService:GenerateGUID(false)

	const Sent, Reached, Success, Status, Text, Signature = pcall(function()
		return Remote:InvokeServer(Nonce, Relay.Sign(Nonce, Method, Url, Encoded), Method, Url, Encoded)
	end)

	if not Sent then
		return false, tostring(Reached)
	end

	if not Reached then
		return false, tostring(Success)
	end

	if Signature ~= Relay.SignReply(Nonce, Status, Text) then
		return false, "Something in this place answered instead of Claudio, so the reply was ignored"
	end

	if not Success then
		return false, `{Status} {Text}`
	end

	return Decode(Text)
end

function Http.Request(Method: Method, Url: string, Body: any?): (boolean, any)
	if RunService:IsRunning() and not RunService:IsServer() then
		return ThroughRelay(Method, Url, Body)
	end

	const Ok, Response = pcall(function()
		return HttpService:RequestAsync({
			Url = Url,
			Method = Method,
			Headers = {
				["Content-Type"] = "application/json",
				["X-Claudio-Token"] = Settings.Token(),
			},
			Body = if Body then HttpService:JSONEncode(Body) else nil,
			Timeout = 60,
		})
	end)

	if not Ok then
		return false, tostring(Response)
	end

	if not Response.Success then
		return false, `{Response.StatusCode} {Response.Body}`
	end

	return Decode(Response.Body or "")
end

return Http