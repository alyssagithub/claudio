--!strict
const Descriptions = {
	HttpDenied = "Studio blocked HTTP requests for Claudio. Allow them in Plugin Management, then retry.",
	Unreachable = "The bridge is not running. Run `claudio` in a terminal, then retry.",
	Timeout = "The bridge didn't answer in time. Check it's still running, then retry.",
	VersionMismatch = "The bridge and the plugin do not match. Run `claudio install` again.",
	Unknown = "Couldn't talk to the bridge. Check it's running, then retry.",
}

const Error = {}

function Error.Classify(Message: string): string
	const Lowered = Message:lower()

	if Lowered:find("not enabled") or Lowered:find("permission") or Lowered:find("not allowed") then
		return "HttpDenied"
	end

	if Lowered:find("timed out") or Lowered:find("timedout") or Lowered:find("timeout") then
		return "Timeout"
	end

	if Lowered:find("connect") or Lowered:find("httperror") or Lowered:find("curl") then
		return "Unreachable"
	end

	return "Unknown"
end

function Error.Describe(Kind: string, Reason: string?): string
	if Descriptions[Kind] and Kind ~= "Unknown" then
		return Descriptions[Kind]
	end

	return if Reason and Reason ~= "" then `Couldn't talk to the bridge: {Reason}. Check it's running, then retry.` else Descriptions.Unknown
end

return Error