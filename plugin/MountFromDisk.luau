const HttpService = game:GetService("HttpService")
const EncodingService = game:GetService("EncodingService")
const SerializationService = game:GetService("SerializationService")

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

const function Descend(From: Instance, Path: string): Instance?
	local At: Instance? = From

	for _, Segment in string.split(Path, "/") do
		if not At then
			return nil
		end

		At = At:FindFirstChild(Segment)
	end

	return At
end

const Tree = HttpService:JSONDecode(Answer.Body)
const Root = Build(Tree, nil)

if Tree.templates then
	const Bytes = EncodingService:Base64Decode(buffer.fromstring(Tree.templates))
	const Ok, Result = pcall(function()
		return SerializationService:DeserializeInstancesAsync(Bytes)
	end)

	if Ok then
		for _, Folder in Result do
			const Target = Descend(Root, Folder.Name)

			if Target then
				for _, Child in Folder:GetChildren() do
					Child.Parent = Target
				end
			end

			Folder:Destroy()
		end
	else
		warn(`Claudio test mount could not deserialize templates: {Result}`)
	end
end

return require((Root :: any).Testing).Mount(plugin)
