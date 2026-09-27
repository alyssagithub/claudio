const HttpService = game:GetService("HttpService")
const EncodingService = game:GetService("EncodingService")
const SerializationService = game:GetService("SerializationService")

const SaveInstead = false
const Base = `http://127.0.0.1:{plugin:GetSetting("Claudio_Port") or 47225}`
const Headers = {
	["Content-Type"] = "application/json",
	["X-Claudio-Token"] = plugin:GetSetting("Claudio_BridgeToken") or "",
}

const Fetched, Answer = pcall(function()
	return HttpService:RequestAsync({
		Url = `{Base}/testing/tree`,
		Method = "GET",
		Headers = Headers,
	})
end)

if not Fetched then
	return `The bridge could not be reached: {Answer}`
end

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

if not SaveInstead then
	return require((Root :: any).Testing).Mount(plugin)
end

for _, Object in Root:GetDescendants() do
	if Object:IsA("BaseScript") and Object.Name ~= "Plugin" then
		Object.Disabled = true
	end
end

const Serialized, Bytes = pcall(function()
	return SerializationService:SerializeInstancesAsync({Root})
end)

if not Serialized then
	return `Studio could not serialize the plugin: {Bytes}`
end

const Sent, Saved = pcall(function()
	return HttpService:RequestAsync({
		Url = `{Base}/testing/save`,
		Method = "POST",
		Headers = Headers,
		Body = HttpService:JSONEncode({rbxm = buffer.tostring(EncodingService:Base64Encode(Bytes))}),
	})
end)

Root:Destroy()

if not Sent then
	return `The bridge could not be reached: {Saved}`
end

return if Saved.Success then `Saved the plugin built from disk: {Saved.Body}` else `The bridge would not save it: {Saved.StatusCode} {Saved.Body}`
