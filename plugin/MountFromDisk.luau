const HttpService = game:GetService("HttpService")

const Answer = HttpService:RequestAsync({
	Url = `http://127.0.0.1:{plugin:GetSetting("Claudio_Port") or 47225}/testing/tree`,
	Method = "GET",
	Headers = {["X-Claudio-Token"] = plugin:GetSetting("Claudio_BridgeToken") or ""},
})

if not Answer.Success then
	return `The bridge would not hand over the plugin source: {Answer.StatusCode} {Answer.Body}`
end

const function Build(Node: any, Parent: Instance?): Instance
	const Made = Instance.new(Node.class)

	Made.Name = Node.name

	if Node.source then
		(Made :: any).Source = Node.source
	end

	for _, Child in Node.children do
		Build(Child, Made)
	end

	Made.Parent = Parent

	return Made
end

return require((Build(HttpService:JSONDecode(Answer.Body), nil) :: any).Testing).Mount(plugin)