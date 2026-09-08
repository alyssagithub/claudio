--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")
const LogService = game:GetService("LogService")

const Remote = ReplicatedStorage:WaitForChild("ClaudioRuntime", 30)

if not Remote or not Remote:IsA("RemoteFunction") then
	return
end

const function Run(Code: string): any
	const Said = {}
	const Listening = LogService.MessageOut:Connect(function(Message: string, Kind: Enum.MessageType)
		if #Said < 200 and Kind ~= Enum.MessageType.MessageInfo then
			table.insert(Said, Message)
		end
	end)

	const function Finish(Answer: {[string]: any}): any
		task.wait(0.1)
		Listening:Disconnect()

		if #Said > 0 then
			Answer.output = Said
		end

		return Answer
	end

	if typeof(loadstring) ~= "function" then
		return Finish({error = "Running code here needs loadstring, which this session does not have."})
	end

	const Made, Trouble = loadstring(`return function()\n{Code}\nend`)

	if not Made then
		return Finish({error = `That did not compile: {tostring(Trouble)}`})
	end

	const Built, Body = pcall(Made)

	if not Built then
		return Finish({error = tostring(Body)})
	end

	const Ok, Result = pcall(Body)

	if not Ok then
		return Finish({error = tostring(Result)})
	end

	const Answer: {[string]: any} = {}

	if Result ~= nil then
		if typeof(Result) == "table" then
			const Encoded, Text = pcall(HttpService.JSONEncode, HttpService, Result)

			Answer.result = if Encoded then Text else tostring(Result)
		else
			Answer.result = tostring(Result)
		end
	end

	return Finish(Answer)
end

Remote.OnClientInvoke = function(Code: string): any
	return Run(Code)
end
