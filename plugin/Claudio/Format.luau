--!strict
const Format = {}

function Format.Path(Path: string?): string
	if not Path then
		return "something"
	end

	return (Path:gsub("^game%.", ""))
end

function Format.Duration(Milliseconds: number): string
	if Milliseconds < 1000 then
		return `{Milliseconds}ms`
	end

	if Milliseconds < 60000 then
		return `{string.format("%.1f", Milliseconds / 1000)}s`
	end

	const Minutes = Milliseconds // 60000
	const Seconds = math.floor((Milliseconds % 60000) / 1000)

	if Minutes < 60 then
		return `{Minutes}m {Seconds}s`
	end

	return `{Minutes // 60}h {Minutes % 60}m`
end

function Format.Clock(Seconds: number): string
	if Seconds < 60 then
		return `{Seconds}s`
	end

	return `{Seconds // 60}m {Seconds % 60}s`
end

function Format.Model(Name: string): string
	if Name == "" then
		return ""
	end

	const Family, Version = Name:match("^claude%-(%a+)%-(%d+%-?%d*)")

	if Family and Version then
		return `{Family:sub(1, 1):upper()}{Family:sub(2)} {(Version:gsub("%-", "."))}`
	end

	const Base, Suffix = Name:match("^(%a+)%[(%w+)%]$")

	if Base and Suffix then
		return `{Base:sub(1, 1):upper()}{Base:sub(2)} {Suffix:upper()}`
	end

	return `{Name:sub(1, 1):upper()}{Name:sub(2)}`
end

function Format.Large(Value: number): string
	if Value >= 1000000 then
		return `{(string.format("%.1f", Value / 1000000):gsub("%.0$", ""))}M`
	end

	if Value >= 1000 then
		return `{(string.format("%.1f", Value / 1000):gsub("%.0$", ""))}k`
	end

	return tostring(Value)
end

function Format.Until(At: number): string
	const Left = At - os.time()

	if Left <= 60 then
		return "Resets in under a minute"
	end

	if Left < 3600 then
		return `Resets in {Left // 60} min`
	end

	if Left < 79200 then
		return `Resets in {Left // 3600} hr {(Left % 3600) // 60} min`
	end

	return `Resets {os.date("%a %I:%M %p", At):gsub(" 0", " ")}`
end

function Format.Ago(At: number): string
	const Passed = os.time() - At

	if Passed < 45 then
		return "just now"
	end

	if Passed < 3600 then
		return `{math.max(1, Passed // 60)}m ago`
	end

	if Passed < 79200 then
		return `{Passed // 3600}h ago`
	end

	return os.date("%b %d, %I:%M %p", At)
end

function Format.Amount(Tokens: number): string
	if Tokens < 1000 then
		return tostring(Tokens)
	end

	if Tokens < 10000 then
		return `{(string.format("%.1f", Tokens / 1000):gsub("%.0$", ""))}k`
	end

	return `{math.floor(Tokens / 1000 + 0.5)}k`
end

const Verbs: {[string]: {string}} = {
	api = {"Looking up", "Looked up", "look up"},
	capture = {"Taking a screenshot", "Took a screenshot", "take a screenshot"},
	changes = {"Checking what changed", "Checked what changed", "check what changed"},
	device = {"Simulating a device", "Simulated a device", "simulate a device"},
	execute = {"Running code", "Ran code", "run code"},
	find = {"Searching for", "Searched for", "search for"},
	history = {"Stepping through history", "Stepped through history", "step through history"},
	instances = {"Checking Studio", "Checked Studio", "check Studio"},
	layout = {"Measuring", "Measured", "measure"},
	lint = {"Checking the analyzer", "Checked the analyzer", "check the analyzer"},
	logs = {"Reading the log", "Read the log", "read the log"},
	memory = {"Reading memory", "Read memory", "read memory"},
	modify = {"Changing", "Changed", "change"},
	profile = {"Reading memory", "Read memory", "read memory"},
	playtest = {"Starting a playtest", "Started a playtest", "start a playtest"},
	press = {"Pressing", "Pressed", "press"},
	properties = {"Reading properties of", "Read properties of", "read properties of"},
	read = {"Reading", "Read", "read"},
	rbxm = {"Saving", "Saved", "save"},
	select = {"Selecting", "Selected", "select"},
	source = {"Editing", "Edited", "edit"},
	type = {"Typing", "Typed", "type"},
}

const Actions: {[string]: {[string]: {string}}} = {
	device = {
		status = {"Checking the device simulator", "Checked the device simulator", "check the device simulator"},
		stop = {"Stopping the simulation", "Stopped the simulation", "stop the simulation"},
	},
	history = {
		redo = {"Redoing a step", "Redid a step", "redo a step"},
		status = {"Checking history", "Checked history", "check history"},
		undo = {"Undoing a step", "Undid a step", "undo a step"},
	},
	playtest = {
		players = {"Adding players", "Added players", "add players"},
		status = {"Checking the playtest", "Checked the playtest", "check the playtest"},
		stop = {"Stopping the playtest", "Stopped the playtest", "stop the playtest"},
	},
	source = {
		get = {"Reading", "Read", "read"},
	},
}

function Format.Tool(Name: string, Action: string?, Subject: string, Status: string): string
	const Chosen = if Action and Actions[Name] and Actions[Name][Action] then Actions[Name][Action] else Verbs[Name]
	const Tail = if Subject == "" then "" else ` {Subject}`

	if not Chosen then
		const Words = (Name:gsub("_", " "))

		return `{Words:sub(1, 1):upper()}{Words:sub(2)}{Tail}`
	end

	if Status == "error" then
		return `Failed to {Chosen[3]}{Tail}`
	end

	return `{Chosen[if Status == "running" then 1 else 2]}{Tail}`
end

return Format