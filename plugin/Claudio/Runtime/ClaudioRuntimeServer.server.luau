--!strict
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const LogService = game:GetService("LogService")
const RunService = game:GetService("RunService")

if not RunService:IsRunning() then
	return
end

const Port = script:GetAttribute("Port") or 47225
const Token = script:GetAttribute("Token") or ""
const Base = `http://127.0.0.1:{Port}`

const Remote = Instance.new("RemoteEvent")

Remote.Name = "ClaudioRuntime"
Remote.Parent = ReplicatedStorage

const Replies = {}

Remote.OnServerEvent:Connect(function(_, Id: any, Result: any)
	if typeof(Id) == "string" then
		Replies[Id] = if Result == nil then {error = "The client sent nothing back."} else Result
	end
end)

const function AskClient(Player: Player, Kind: string, Body: string): any
	const Id = `{os.clock()}-{math.random(1, 1000000)}`

	Remote:FireClient(Player, Id, Kind, Body)

	const Deadline = os.clock() + 20

	while Replies[Id] == nil and os.clock() < Deadline do
		task.wait(0.1)
	end

	const Answer = Replies[Id]

	Replies[Id] = nil

	if Answer == nil then
		return {error = "The client did not answer within twenty seconds. Its agent may not have loaded."}
	end

	return Answer
end

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

const function CanRun(): boolean
	if typeof(loadstring) ~= "function" then
		return false
	end

	const Ok, Made = pcall(function()
		return loadstring("return 1")
	end)

	return Ok and Made ~= nil
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

	if not CanRun() then
		return Finish({error = "Running code inside the session needs loadstring, which is off for this place. Select ServerScriptService in the Explorer, tick LoadStringEnabled in its Properties, and start the playtest again. Claudio cannot set it, because the property is not readable or writable from any script."})
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

task.spawn(function()
	while RunService:IsRunning() and task.wait(1) do
		const Ok, Reply = Call("GET", `/studio/job?role=server&canRun={CanRun()}`, nil)

		if Ok and Reply and Reply.job then
			const Job = Reply.job
			task.spawn(function()
			const Done, Outcome = pcall(function(): any
				if Job.kind == "playtest" then
					const StudioTestService = game:GetService("StudioTestService")

					if Job.input.action == "stop" then
						Call("POST", "/studio/job", {id = Job.id, result = {text = "Playtest stopped."}})

						task.wait(0.2)

						StudioTestService:EndTest("stopped by Claudio")

						return nil
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

				if Job.kind ~= "execute" and Job.kind ~= "press" then
					return {error = `The runtime agent does not handle "{tostring(Job.kind)}".`}
				end

				if Job.kind == "press" or Job.input.target == "client" then
					const Player = game:GetService("Players"):GetPlayers()[1]

					if not Player then
						return {error = "Nobody is in the session, so there is no client to run on."}
					end

					return AskClient(Player, if Job.kind == "press" then "press" else "execute", if Job.kind == "press" then Job.input.path else Job.input.code)
				end

				return Run(Job.input.code)
			end)

			if not (Done and Outcome == nil) then
				Call("POST", "/studio/job", {id = Job.id, result = if Done then Outcome else {error = tostring(Outcome)}})
			end
			end)
		end
	end
end)
