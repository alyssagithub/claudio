--!strict
const Types = require(script.Parent.Types)
const Format = require(script.Parent.Format)

const Changes = {}

const function Field(Input: string, Name: string): string?
	for _, Line in string.split(Input, "\n") do
		const Key, Value = Line:match("^([%w_]+): (.+)$")

		if Key == Name then
			return Value
		end
	end

	return nil
end

const function Line(Call: Types.ToolCall): string?
	const Name = (Call.name:gsub("^mcp__.-__", ""))
	const Input = Call.input

	if Name == "set_script_source" then
		return `Rewrote {Format.Path(Field(Input, "instancePath") or Field(Input, "path"))}`
	end

	if Name == "edit_script_lines" or Name == "insert_script_lines" or Name == "delete_script_lines" then
		return `Edited {Format.Path(Field(Input, "instancePath") or Field(Input, "path"))}`
	end

	if Name == "set_properties" then
		return `Changed properties on {Format.Path(Field(Input, "instancePath") or Field(Input, "path"))}`
	end

	if Name == "manage_instance" then
		const Action = Field(Input, "action") or "changed"
		const Past = {
			create = "Created",
			delete = "Deleted",
			destroy = "Deleted",
			remove = "Deleted",
			rename = "Renamed",
			clone = "Cloned",
			reparent = "Moved",
			move = "Moved",
		}

		return `{Past[Action] or "Changed"} {Format.Path(Field(Input, "instancePath") or Field(Input, "parentPath") or Field(Input, "className"))}`
	end

	if Name == "import_rbxm" or Name == "insert_asset" then
		return `Inserted into {Format.Path(Field(Input, "parent_path") or Field(Input, "parentPath"))}`
	end

	if Name == "execute_luau" or Name == "run_as_job" then
		return "Ran a Luau script in Studio"
	end

	if Name == "Write" or Name == "Edit" then
		return `Wrote {Format.Path(Field(Input, "file_path"))}`
	end

	return nil
end

const function Push(Found: {string}, Seen: {[string]: boolean}, Text: string)
	if not Seen[Text] then
		Seen[Text] = true
		table.insert(Found, Text)
	end
end

function Changes.For(Message: Types.Message): {string}
	const Edits = Message.Edits

	if not Edits then
		return Changes.Describe(Message.Calls)
	end

	const Found = {}
	const Seen = {}

	for _, Text in Edits do
		Push(Found, Seen, Text)
	end

	const Made: {Types.ToolCall} = Message.Calls or {}

	for _, Call in Made do
		if Call.status ~= "error" then
			const Name = (Call.name:gsub("^mcp__.-__", ""))

			if Name == "Write" or Name == "Edit" then
				Push(Found, Seen, `Wrote {Format.Path(Field(Call.input, "file_path"))}`)
			end
		end
	end

	return Found
end

function Changes.Describe(Calls: {Types.ToolCall}?): {string}
	const Found = {}
	const Seen = {}
	const Made: {Types.ToolCall} = Calls or {}

	for _, Call in Made do
		if Call.status ~= "error" then
			const Text = Line(Call)

			if Text and not Seen[Text] then
				Seen[Text] = true
				table.insert(Found, Text)
			end
		end
	end

	return Found
end

return Changes