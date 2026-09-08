--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")
const LogService = game:GetService("LogService")

const Remote = ReplicatedStorage:WaitForChild("ClaudioRuntime", 30)

if not Remote or not Remote:IsA("RemoteFunction") then
	return
end

Remote.OnClientInvoke = function(Code: string): any
	const Holder = Instance.new("ModuleScript")

	Holder.Name = "ClaudioRuntimeChunk"
	Holder.Source = `return function()\n{Code}\nend`
	Holder.Parent = ReplicatedStorage

	const Said = {}
	const Listening = LogService.MessageOut:Connect(function(Message: string, Kind: Enum.MessageType)
		if #Said < 200 and Kind ~= Enum.MessageType.MessageInfo then
			table.insert(Said, Message)
		end
	end)

	const Built, Made = pcall(require, Holder)

	if not Built then
		task.wait(0.1)
		Listening:Disconnect()
		Holder:Destroy()

		return {error = "That did not compile.", output = Said}
	end

	const Ok, Result = pcall(Made)

	task.wait(0.1)
	Listening:Disconnect()
	Holder:Destroy()

	const Answer: {[string]: any} = {}

	if not Ok then
		Answer.error = tostring(Result):gsub("[%w_%.]*ClaudioRuntimeChunk:(%d+):?%s*", function(Digits: string): string
			return `line {tonumber(Digits) - 1}: `
		end)
	elseif Result ~= nil then
		if typeof(Result) == "table" then
			const Encoded, Text = pcall(HttpService.JSONEncode, HttpService, Result)

			Answer.result = if Encoded then Text else tostring(Result)
		else
			Answer.result = tostring(Result)
		end
	end

	if #Said > 0 then
		Answer.output = Said
	end

	return Answer
end
