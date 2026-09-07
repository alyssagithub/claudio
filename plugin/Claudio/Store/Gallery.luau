--!strict
const Types = require(script.Parent.Parent.Types)

const Gallery = {
	Id = "claudio-design-gallery",
	Title = "Design gallery (every message variant)",
	Testing = script.Parent.Parent.Name:match("Testing$") ~= nil,
}

const Code = table.concat({
	"```lua",
	"const function Greet(Name: string): string",
	"\treturn `Hello {Name}`",
	"end",
	"```",
}, "\n")

const Markdown = table.concat({
	"# Heading one",
	"## Heading two",
	"",
	"Body copy with **bold**, *italic*, `inline code` and a path link to Workspace.Baseplate that should be clickable.",
	"",
	"- First bullet",
	"- Second bullet with a much longer run of text so it has to wrap onto another line inside the bubble",
	"- Third bullet",
	"",
	Code,
}, "\n")

const Long = string.rep("This paragraph repeats so the bubble grows tall enough to test wrapping and scrolling. ", 8)

function Gallery.Messages(): {Types.Message}
	const Now = os.time()

	return {
		{Role = "user", Text = "A short user message.", At = Now - 3600},
		{Role = "assistant", Text = "A short assistant reply.", At = Now - 3590},
		{Role = "user", Text = Long, At = Now - 3500},
		{Role = "assistant", Text = Markdown, At = Now - 3400},
		{
			Role = "assistant",
			Text = "A reply that also carries thinking, activity and a cost footer.",
			Thinking = "Weighing two approaches before answering, then picking the simpler one.",
			Activity = {"Read Workspace", "Searched scripts"},
			Model = "sonnet",
			Effort = "medium",
			Tokens = {input = 1200, output = 340, cached = 90000},
			Milliseconds = 4200,
			Cost = 0.0421,
			At = Now - 3300,
		},
		{
			Role = "assistant",
			Text = "A reply that changed things in the place.",
			Edits = {"Workspace.Baseplate", "ServerScriptService.Main", "ReplicatedStorage.Shared.Config"},
			Checkpoint = 3,
			At = Now - 3200,
		},
		{
			Role = "assistant",
			Text = "A reply with tool calls in every state.",
			Calls = {
				{name = "get_script_source", input = "{\"path\":\"ServerScriptService.Main\"}", output = "42 lines", status = "done", milliseconds = 320},
				{name = "execute_luau", input = "{\"code\":\"return 1\"}", output = "", status = "running", milliseconds = 0},
				{name = "set_properties", input = "{\"path\":\"Workspace.Missing\"}", output = "Instance not found", status = "error", milliseconds = 120},
			},
			At = Now - 3100,
		},
		{
			Role = "assistant",
			Text = "A reply that estimated its own token count rather than being told.",
			Tokens = {input = 800, output = 120, cached = 0},
			Estimated = true,
			At = Now - 3000,
		},
		{Role = "user", Text = "A user message with attachments.", Attachments = {"Workspace.Baseplate", "Output"}, At = Now - 2900},
		{Role = "assistant", Text = "", Failed = true, At = Now - 2800},
		{Role = "assistant", Text = "The last reply, so the message actions can be checked on a final bubble.", At = Now - 2700},
	}
end

function Gallery.Live(): {[string]: any}
	return {
		Activity = {"Reading Workspace", "Editing ServerScriptService.Main"},
		StreamingThinking = "Working out which of the two approaches keeps the existing callers intact, then checking whether anything else reads the same value.",
		StreamingText = "This reply is still streaming in, so the caret and the growing bubble can both be looked at while they animate.",
		Tasks = {
			{id = "1", description = "Reading Workspace", kind = "read", status = "running", background = true, depth = 1},
			{id = "2", description = "Checking the analyzer", kind = "lint", status = "pending", background = false, depth = 2},
			{id = "3", description = "Writing the fix", kind = "edit", status = "completed", background = false, depth = 1},
			{id = "4", description = "Publishing", kind = "publish", status = "failed", background = false, depth = 1},
		},
		Queue = {
			{Display = "A queued message, waiting its turn.", Full = "A queued message, waiting its turn.", Attachments = {}, Images = {}, Previews = {}},
			{Display = "A second queued message, so the reorder arrows appear.", Full = "A second queued message.", Attachments = {}, Images = {}, Previews = {}},
		},
		Permission = {id = "gallery", tool = "set_properties", input = "{\"path\":\"Workspace.Baseplate\",\"Anchored\":false}"},
		Question = {
			id = "gallery-ask",
			questions = {
				{
					question = "Which corner radius should the panels use?",
					header = "Radius",
					multiSelect = false,
					options = {
						{label = "Four (Recommended)", description = "Matches the inline chrome already used everywhere else.", preview = "UICorner { CornerRadius = UDim.new(0, 4) }"},
						{label = "Six", description = "Softer, and what the menus already use."},
						{label = "Eight", description = "Softer still, currently only used by message bubbles."},
					} :: {Types.Choice},
				},
				{
					question = "Which of these should the pass also cover?",
					header = "Extras",
					multiSelect = true,
					options = {
						{label = "Tooltips", description = "Five implementations with five anchoring rules."},
						{label = "Spacing", description = "Thirteen padding values with a long tail of one offs."},
						{label = "Icons", description = "Two icon vocabularies in one interface."},
					},
				},
			} :: {Types.Question},
		} :: Types.Asked,
	}
end

function Gallery.Summary(): Types.ConversationSummary
	return {
		id = Gallery.Id,
		title = Gallery.Title,
		project = "Testing",
		source = "claudio",
		createdAt = (os.time() - 3600) * 1000,
		updatedAt = (os.time() - 2700) * 1000,
	}
end

return Gallery
