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

return Format