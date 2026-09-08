--!strict
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

if not RunService:IsRunning() then
	return
end

const Port = script:GetAttribute("Port") or 47225
const Token = script:GetAttribute("Token") or ""
const Base = `http://127.0.0.1:{Port}`

const Remote = Instance.new("RemoteFunction")

Remote.Name = "ClaudioRuntime"
Remote.Parent = ReplicatedStorage

const function Call(Method: string, Where: string, Body: any): (boolean, any)
	const Ok, Result = pcall(function()
		return HttpService:RequestAsync({
			Url = `{Base}{Where}`,
			Method = Method,
			Headers = {["Content-Type"] = "application/json", ["x-claudio-token"] = Token},
			Body = if Body then HttpService:JSONEncode(Body) else nil,
		})
	end)

	if not Ok or not Result.Success then
		return false, nil
	end

	const Read, Decoded = pcall(HttpService.JSONDecode, HttpService, Result.Body)

	return Read, Decoded
end

const function Run(Code: string): any
	const Holder = Instance.new("ModuleScript")

	Holder.Name = "ClaudioRuntimeChunk"
	Holder.Source = `return function()\n{Code}\nend`
	Holder.Parent = ReplicatedStorage

	const Said = {}
	const Listening = game:GetService("LogService").MessageOut:Connect(function(Message: string, Kind: Enum.MessageType)
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

task.spawn(function()
	while RunService:IsRunning() and task.wait(1) do
		const Ok, Reply = Call("GET", "/studio/job?role=server", nil)

		if Ok and Reply and Reply.job then
			const Job = Reply.job
			const Done, Outcome = pcall(function(): any
				if Job.kind == "playtest" then
					const StudioTestService = game:GetService("StudioTestService")

					if Job.input.action == "stop" then
						StudioTestService:EndTest("stopped by Claudio")

						return {text = "Playtest stopped."}
					end

					if Job.input.action == "players" then
						const Wanted = math.clamp(tonumber(Job.input.players) or 1, 1, 8)
						const Before = #game:GetService("Players"):GetPlayers()
						const Added, Trouble = pcall(function()
							StudioTestService:AddPlayers(Wanted)
						end)

						if not Added then
							return {error = `Studio refused to add players: {tostring(Trouble)}. This only works in a multiplayer playtest.`}
						end

						task.wait(2)

						return {text = `Players went from {Before} to {#game:GetService("Players"):GetPlayers()}.`}
					end

					return {error = `The runtime agent does not know the playtest action "{tostring(Job.input.action)}".`}
				end

				if Job.kind ~= "execute" then
					return {error = `The runtime agent only runs execute, not "{tostring(Job.kind)}".`}
				end

				if Job.input.target == "client" then
					const Player = game:GetService("Players"):GetPlayers()[1]

					if not Player then
						return {error = "Nobody is in the session, so there is no client to run on."}
					end

					return Remote:InvokeClient(Player, Job.input.code)
				end

				return Run(Job.input.code)
			end)

			Call("POST", "/studio/job", {id = Job.id, result = if Done then Outcome else {error = tostring(Outcome)}})
		end
	end
end)
