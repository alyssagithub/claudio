--!strict
-- Remembers which script raised each error, so the logs tool can say where an error came from. The log
-- history only keeps the text, but ScriptContext.Error also hands over the script, and an error that
-- never reaches it was raised by Studio itself or by an engine call rather than by a script.
const ScriptContext = game:GetService("ScriptContext")

const Origins = {}

const Kept = 300
const Sources: {[string]: string} = {}
const Order: {string} = {}
local StartedAt = 0
local Listening = false

const function Describe(Source: Instance?, Stack: string): string
	if not Source then
		const First = Stack:match("^%s*([^\n]-)%s*$") or Stack:match("^%s*([^\n]+)")

		return if First and First ~= "" then `from code with no script, at {First}` else "from code with no script"
	end

	if Source:IsDescendantOf(game) then
		return `from {Source:GetFullName()}`
	end

	return `from the plugin {Source:GetFullName()}`
end

function Origins.Start()
	if Listening then
		return
	end

	Listening = true
	StartedAt = os.time()

	ScriptContext.Error:Connect(function(Message: string, Stack: string, Source: Instance?)
		if not Sources[Message] then
			table.insert(Order, Message)

			if #Order > Kept then
				Sources[table.remove(Order, 1) :: string] = nil
			end
		end

		Sources[Message] = Describe(Source, Stack)
	end)
end

-- The note to put after an error line, or nil when there is nothing to say.
function Origins.Label(Message: string, Timestamp: number): string?
	const Found = Sources[Message]

	if Found then
		return Found
	end

	if not Listening or Timestamp <= StartedAt then
		return "source unknown, it was logged before Claudio started watching"
	end

	return "not raised by any script, so it came from Studio or an engine call, often a plugin's, not game code"
end

return Origins
