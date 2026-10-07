--!strict
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const LogService = game:GetService("LogService")
const RunService = game:GetService("RunService")

if not RunService:IsRunning() then
	return
end

const Token = "{{Token}}"

if Token:sub(1, 2) == "{{" then
	return
end

script.Parent = nil

const BuildKey = "{{BuildKey}}"
const Base = `http://127.0.0.1:{tonumber("{{Port}}") or 47225}`

const Remote = Instance.new("RemoteEvent")

Remote.Name = "ClaudioRuntime"
Remote.Parent = ReplicatedStorage

const Asked: {[string]: Player} = {}
const Replies = {}
const Loaded: {[Player]: boolean} = {}
const Settled: {[Player]: boolean} = {}

game:GetService("Players").PlayerRemoving:Connect(function(Player: Player)
	Loaded[Player] = nil
	Settled[Player] = nil
end)

Remote.OnServerEvent:Connect(function(Sender: Player, Id: any, Result: any)
	if Id == "ready" or Id == "settled" then
		Loaded[Sender] = true

		if Id == "settled" then
			Settled[Sender] = true
		end

		return
	end

	if typeof(Id) ~= "string" or Asked[Id] ~= Sender then
		return
	end

	Asked[Id] = nil
	Replies[Id] = if Result == nil then {error = "The client sent nothing back."} else Result
end)

const function AskClient(Player: Player, Kind: string, Body: string, Seconds: number?): any
	const Id = HttpService:GenerateGUID(false)

	Asked[Id] = Player
	Remote:FireClient(Player, Id, Kind, Body)

	const Limit = Seconds or 20
	const Deadline = os.clock() + Limit

	while Replies[Id] == nil and os.clock() < Deadline do
		task.wait(0.1)
	end

	const Answer = Replies[Id]

	Asked[Id] = nil
	Replies[Id] = nil

	if Answer == nil then
		return {error = if Seconds then `Stopped waiting for the client after {Limit} seconds, the time limit for this call. Raise timeout if the code really needs longer.` else "The client didn't answer within 20 seconds. Claudio's client script may not have loaded."}
	end

	return Answer
end

const function Call(Method: string, Where: string, Body: any): (boolean, any)
	if Body and typeof(Body.id) == "string" and not pcall(HttpService.JSONEncode, HttpService, Body) then
		Body = {
			id = Body.id,
			result = {error = "The answer had text that is not valid UTF-8, often a string cut in the middle of a character such as • or an emoji, so it could not be sent. Use utf8 functions to cut strings, or return less."},
		}
	end

	const Ok, Result = pcall(function()
		return HttpService:RequestAsync({
			Url = `{Base}{Where}`,
			Method = Method,
			Headers = {
				["Content-Type"] = "application/json",
				["x-claudio-token"] = Token,
			},
			Body = if Body then HttpService:JSONEncode(Body) else nil,
		})
	end)

	if not Ok or not Result.Success then
		return false, nil
	end

	const Read, Decoded = pcall(HttpService.JSONDecode, HttpService, Result.Body)

	return Read, Decoded
end

local Held: BindableFunction?

const function Builder(): BindableFunction?
	if Held then
		return Held
	end

	const Found = ServerScriptService:FindFirstChild("ClaudioBuild")

	if not Found or not Found:IsA("BindableFunction") then
		return nil
	end

	Held = Found :: BindableFunction
	Found.Parent = nil

	return Held
end

Builder()

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

const function Run(Code: string, Within: string?): any
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

	const Payload = Making:Invoke(BuildKey, `return function(breathe)\n{Code}\nend`, Within)

	if typeof(Payload) == "string" then
		return Finish({error = Payload})
	end

	if not Payload then
		return Finish({error = "Claudio could not turn that code into a module to run it."})
	end

	const Built, Body = pcall(require, Payload)

	Payload:Destroy()

	if not Built then
		return Finish({error = Explain(tostring(Body), Said)})
	end

	local LastYield = os.clock()
	const Ok, Result = pcall(Body, function()
		if os.clock() - LastYield < 0.008 then
			return
		end

		task.wait()
		LastYield = os.clock()
	end)

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
		local Ready = 0
		local Games = 0

		for Player in Loaded do
			if Player.Parent then
				Ready += 1
			end
		end

		for Player in Settled do
			if Player.Parent then
				Games += 1
			end
		end

		const Ok, Reply = Call("GET", `/studio/job?role=server&canRun={Builder() ~= nil}&clients={#game:GetService("Players"):GetPlayers()}&ready={Ready}&games={Games}`, nil)

		if Ok and Reply and Reply.job then
			const Job = Reply.job
			task.spawn(function()
			const Done, Outcome = pcall(function(): any
				if Job.kind == "playtest" then
					const StudioTestService = game:GetService("StudioTestService")

					if Job.input.action == "stop" then
						Call("POST", "/studio/job", {
							id = Job.id,
							result = {text = "Playtest stopped."},
						})

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

					return {error = `Claudio does not know the playtest action "{tostring(Job.input.action)}".`}
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

					local Skipped = 0

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
							Skipped += 1

							continue
						end

						table.insert(Kept, `{Kind}: {if #Message > 400 then `{Message:sub(1, 400)} [cut]` else Message}`)
					end

					const Lines = {}

					for Index = #Kept, 1, -1 do
						table.insert(Lines, Kept[Index])
					end

					return {
						lines = Lines,
						scanned = #History,
						skipped = Skipped,
					}
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
							table.insert(Rows, {
								Name = Tag.Name,
								Used = Used,
							})
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

				if Job.kind ~= "execute" and Job.kind ~= "input" and Job.kind ~= "quality" then
					return {error = `Claudio does not handle "{tostring(Job.kind)}" in a playtest.`}
				end

				if Job.kind == "input" or Job.kind == "quality" or Job.input.target == "client" then
					const Everyone = game:GetService("Players"):GetPlayers()
					const Wanted = Job.input.player

					if #Everyone == 0 then
						return {error = "Nobody is in the session, so there is no client to run on."}
					end

					local Player: Player? = Everyone[1]

					if typeof(Wanted) == "string" and Wanted ~= "" then
						Player = Everyone[tonumber(Wanted) or 0]

						for _, Someone in Everyone do
							if Someone.Name:lower() == Wanted:lower() then
								Player = Someone
							end
						end
					end

					if not Player then
						const Names = {}

						for Index, Someone in Everyone do
							table.insert(Names, `{Index} {Someone.Name}`)
						end

						return {error = `No player matches "{Wanted}". In the session: {table.concat(Names, ", ")}.`}
					end

					if Job.kind == "quality" then
						return AskClient(Player, "quality", tostring(Job.input.level))
					end

					if Job.kind == "execute" and typeof(Job.input.within) == "string" then
						return AskClient(Player, "scoped", HttpService:JSONEncode(Job.input), math.clamp(tonumber(Job.input.timeout) or 300, 1, 1800))
					end

					if Job.kind == "input" then
						return AskClient(Player, "input", HttpService:JSONEncode(Job.input), 20 + math.clamp(tonumber(Job.input.times) or 1, 1, 100) * math.clamp(tonumber(Job.input.gap) or 0.6, 0.05, 10))
					end

					return AskClient(Player, "execute", Job.input.code, math.clamp(tonumber(Job.input.timeout) or 300, 1, 1800))
				end

				return Run(Job.input.code, Job.input.within)
			end)

			if not (Done and Outcome == nil) then
				Call("POST", "/studio/job", {
					id = Job.id,
					result = if Done then Outcome else {error = tostring(Outcome)},
				})
			end
			end)
		end
	end
end)