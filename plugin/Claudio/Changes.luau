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

const function Line(Call: Types.ToolCall): Types.Change?
	const Name = (Call.name:gsub("^mcp__.-__", ""))
	const Input = Call.input

	if Name == "set_script_source" then
		return {Kind = "changed", Text = `Rewrote {Format.Path(Field(Input, "instancePath") or Field(Input, "path"))}`}
	end

	if Name == "edit_script_lines" or Name == "insert_script_lines" or Name == "delete_script_lines" then
		return {Kind = "changed", Text = `Edited {Format.Path(Field(Input, "instancePath") or Field(Input, "path"))}`}
	end

	if Name == "set_properties" then
		return {Kind = "changed", Text = `Changed properties on {Format.Path(Field(Input, "instancePath") or Field(Input, "path"))}`}
	end

	if Name == "manage_instance" then
		const Action = Field(Input, "action") or "changed"
		const Past = {
			create = {Kind = "added", Word = "Created"},
			delete = {Kind = "removed", Word = "Deleted"},
			destroy = {Kind = "removed", Word = "Deleted"},
			remove = {Kind = "removed", Word = "Deleted"},
			rename = {Kind = "changed", Word = "Renamed"},
			clone = {Kind = "added", Word = "Cloned"},
			reparent = {Kind = "changed", Word = "Moved"},
			move = {Kind = "changed", Word = "Moved"},
		}

		const Done = Past[Action] or {Kind = "changed", Word = "Changed"}

		return {Kind = Done.Kind, Text = `{Done.Word} {Format.Path(Field(Input, "instancePath") or Field(Input, "parentPath") or Field(Input, "className"))}`}
	end

	if Name == "import_rbxm" or Name == "insert_asset" then
		return {Kind = "added", Text = `Inserted into {Format.Path(Field(Input, "parent_path") or Field(Input, "parentPath"))}`}
	end

	if Name == "Write" or Name == "Edit" then
		return {Kind = "changed", Text = `Wrote {Format.Path(Field(Input, "file_path"))}`}
	end

	return nil
end

const function Push(Found: {Types.Change}, Seen: {[string]: boolean}, Entry: Types.Change)
	if not Seen[Entry.Text] then
		Seen[Entry.Text] = true
		table.insert(Found, Entry)
	end
end

function Changes.For(Message: Types.Message): {Types.Change}
	const Edits = Message.Edits

	if not Edits then
		return Changes.Describe(Message.Calls)
	end

	const Found = {}
	const Seen = {}

	for _, Written in Edits do
		Push(Found, Seen, {Kind = "changed", Text = Written})
	end

	const Made: {Types.ToolCall} = Message.Calls or {}

	for _, Call in Made do
		if Call.status ~= "error" then
			const Name = (Call.name:gsub("^mcp__.-__", ""))

			if Name == "Write" or Name == "Edit" then
				Push(Found, Seen, {Kind = "changed", Text = `Wrote {Format.Path(Field(Call.input, "file_path"))}`})
			end
		end
	end

	return Found
end

function Changes.Describe(Calls: {Types.ToolCall}?): {Types.Change}
	const Found = {}
	const Seen = {}
	const Made: {Types.ToolCall} = Calls or {}

	for _, Call in Made do
		if Call.status ~= "error" then
			const Entry = Line(Call)

			if Entry then
				Push(Found, Seen, Entry)
			end
		end
	end

	return Found
end

return Changes