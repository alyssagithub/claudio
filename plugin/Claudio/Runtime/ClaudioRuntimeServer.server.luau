--!strict
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
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

const function Builder(): BindableFunction?
	const Found = ServerScriptService:FindFirstChild("ClaudioBuild")

	return if Found and Found:IsA("BindableFunction") then Found :: BindableFunction else nil
end

const function Placed(Message: string): string
	return (Message:gsub("[%w_%.]*ClaudioPayload:(%d+):?%s*", function(Digits: string): string
		return `line {math.max(1, (tonumber(Digits) or 2) - 1)}: `
	end))
end

const function Explain(Trouble: string, Said: {string}): string
	if not Trouble:find("experienced an error while loading", 1, true) then
		return Placed(Trouble)
	end

	task.wait(0.05)

	for Index = #Said, 1, -1 do
		const Line, Rest = Said[Index]:match("ClaudioPayload:(%d+): (.+)$")

		if Line then
			return `Line {math.max(1, (tonumber(Line) or 2) - 1)}: {Rest}`
		end
	end

	return Trouble
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

	const Making = Builder()

	if not Making then
		return Finish({error = "Claudio's plugin is not running inside this play session, so there is nothing to build the code with. Stop the playtest and start it again, and if that does not help, reinstall the plugin."})
	end

	const Payload = Making:Invoke(`return function()\n{Code}\nend`)

	if not Payload then
		return Finish({error = "Claudio could not turn that code into a module to run it."})
	end

	const Built, Body = pcall(require, Payload)

	Payload:Destroy()

	if not Built then
		return Finish({error = Explain(tostring(Body), Said)})
	end

	const Ok, Result = pcall(Body)

	if not Ok then
		return Finish({error = Placed(tostring(Result))})
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
		const Ok, Reply = Call("GET", `/studio/job?role=server&canRun={Builder() ~= nil}&clients={#game:GetService("Players"):GetPlayers()}`, nil)

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

				if Job.kind == "logs" then
					const Named = {
						[Enum.MessageType.MessageOutput] = "print",
						[Enum.MessageType.MessageInfo] = "info",
						[Enum.MessageType.MessageWarning] = "warn",
						[Enum.MessageType.MessageError] = "error",
					}
					const History = LogService:GetLogHistory()
					const Limit = math.clamp(tonumber(Job.input.limit) or 40, 1, 200)
					const Wanted = if typeof(Job.input.level) == "string" then Job.input.level:lower() else "all"
					const Needle = if typeof(Job.input.contains) == "string" and Job.input.contains ~= "" then Job.input.contains:lower() else nil
					const Kept = {}

					for Index = #History, 1, -1 do
						const Entry = History[Index]
						const Kind = Named[Entry.messageType] or "print"

						if Wanted == "problems" then
							if Kind ~= "warn" and Kind ~= "error" then
								continue
							end
						elseif Wanted ~= "all" and Kind ~= Wanted then
							continue
						end

						const Message = tostring(Entry.message)

						if Needle and not Message:lower():find(Needle, 1, true) then
							continue
						end

						if #Kept >= Limit then
							break
						end

						table.insert(Kept, `{Kind}: {if #Message > 400 then `{Message:sub(1, 400)} [cut]` else Message}`)
					end

					const Lines = {}

					for Index = #Kept, 1, -1 do
						table.insert(Lines, Kept[Index])
					end

					return {lines = Lines, scanned = #History, skipped = 0}
				end

				if Job.kind == "memory" then
					const Stats = game:GetService("Stats")

					if not Stats.MemoryTrackingEnabled then
						return {error = "Memory tracking is off for this place, so nothing can be measured."}
					end

					const Least = tonumber(Job.input.least) or 1
					const Rows = {}

					for _, Tag in Enum.DeveloperMemoryTag:GetEnumItems() do
						const Ok, Used = pcall(function()
							return Stats:GetMemoryUsageMbForTag(Tag)
						end)

						if Ok and Used >= Least then
							table.insert(Rows, {Name = Tag.Name, Used = Used})
						end
					end

					table.sort(Rows, function(Left, Right)
						return Left.Used > Right.Used
					end)

					const Lines = {}

					for Index, Row in Rows do
						if Index > 15 then
							break
						end

						table.insert(Lines, `{Row.Name} {string.format("%.1f", Row.Used)}`)
					end

					if #Lines == 0 then
						return {text = `{string.format("%.1f", Stats:GetTotalMemoryUsageMb())}MB total, and nothing reaches {Least}MB on its own.`}
					end

					return {text = `{string.format("%.1f", Stats:GetTotalMemoryUsageMb())}MB total, in MB: {table.concat(Lines, ", ")}`}
				end

				if Job.kind ~= "execute" and Job.kind ~= "press" and Job.kind ~= "type" then
					return {error = `The runtime agent does not handle "{tostring(Job.kind)}".`}
				end

				if Job.kind == "press" or Job.kind == "type" or Job.input.target == "client" then
					const Player = game:GetService("Players"):GetPlayers()[1]

					if not Player then
						return {error = "Nobody is in the session, so there is no client to run on."}
					end

					return AskClient(Player, if Job.kind == "press" or Job.kind == "type" then Job.kind else "execute", if Job.kind == "press" then Job.input.path elseif Job.kind == "type" then Job.input.text else Job.input.code)
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