--!strict
const Descriptions = {
	HttpDenied = "Studio blocked HTTP requests for Claudio. Allow them in Plugin Management, then retry.",
	Unreachable = "The bridge is not running. Run `claudio` in a terminal, then retry.",
	Timeout = "The bridge did not answer in time.",
	VersionMismatch = "The bridge and the plugin do not match. Run `claudio install` again.",
	Unknown = "Something went wrong talking to the bridge.",
}

const Error = {}

function Error.Classify(Message: string): string
	const Lowered = Message:lower()

	if Lowered:find("not enabled") or Lowered:find("permission") or Lowered:find("not allowed") then
		return "HttpDenied"
	end

	if Lowered:find("timed out") or Lowered:find("timeout") then
		return "Timeout"
	end

	if Lowered:find("connect") or Lowered:find("httperror") or Lowered:find("curl") then
		return "Unreachable"
	end

	return "Unknown"
end

function Error.Describe(Kind: string): string
	return Descriptions[Kind] or Descriptions.Unknown
end

return Error