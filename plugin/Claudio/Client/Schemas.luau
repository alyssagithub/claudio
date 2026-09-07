--!strict
const Typed = require(script.Parent.Parent.Packages.typed)

const Tokens = Typed.table({
	input = Typed.number(),
	output = Typed.number(),
	cached = Typed.number(),
})

const Call = Typed.table({
	name = Typed.string(),
	input = Typed.string(),
	output = Typed.string(),
	status = Typed.string(),
	milliseconds = Typed.number(),
	steps = Typed.optional(Typed.array(Typed.string())),
	delegate = Typed.optional(Typed.table({
		name = Typed.string(),
		model = Typed.string(),
	})),
})

const Asked = Typed.table({
	id = Typed.string(),
	questions = Typed.array(Typed.table({
		question = Typed.string(),
		header = Typed.string(),
		multiSelect = Typed.boolean(),
		options = Typed.array(Typed.table({
			label = Typed.string(),
			description = Typed.string(),
			preview = Typed.optional(Typed.string()),
		})),
	})),
})

const Permission = Typed.table({
	id = Typed.string(),
	tool = Typed.string(),
	input = Typed.optional(Typed.string()),
})

const Summary = Typed.table({
	id = Typed.string(),
	title = Typed.string(),
	project = Typed.string(),
	source = Typed.string(),
	starred = Typed.optional(Typed.boolean()),
	archived = Typed.optional(Typed.boolean()),
	createdAt = Typed.number(),
	updatedAt = Typed.number(),
})

const Limit = Typed.table({
	kind = Typed.string(),
	label = Typed.optional(Typed.string()),
	status = Typed.string(),
	utilization = Typed.optional(Typed.number()),
	resetsAt = Typed.optional(Typed.number()),
})

const Breakdown = Typed.table({
	total = Typed.number(),
	max = Typed.number(),
	percentage = Typed.number(),
	model = Typed.optional(Typed.string()),
	categories = Typed.array(Typed.table({
		name = Typed.string(),
		tokens = Typed.number(),
		colour = Typed.string(),
		deferred = Typed.boolean(),
	})),
})

const Message = Typed.table({
	role = Typed.string(),
	text = Typed.string(),
	activity = Typed.optional(Typed.array(Typed.string())),
	images = Typed.optional(Typed.array(Typed.number())),
	at = Typed.optional(Typed.number()),
	tokens = Typed.optional(Tokens),
	cost = Typed.optional(Typed.number()),
	estimated = Typed.optional(Typed.boolean()),
})

return {
	Health = Typed.table({
		name = Typed.string(),
		version = Typed.string(),
		protocolVersion = Typed.number(),
		loggedIn = Typed.boolean(),
		loginDetail = Typed.optional(Typed.string()),
		mcpServers = Typed.array(Typed.string()),
		systemPrompt = Typed.optional(Typed.string()),
		limits = Typed.optional(Typed.array(Limit)),
		context = Typed.optional(Breakdown),
	}),
	Turn = Typed.table({
		requestId = Typed.string(),
		conversationId = Typed.optional(Typed.string()),
		status = Typed.string(),
		text = Typed.string(),
		thinking = Typed.optional(Typed.string()),
		activity = Typed.array(Typed.string()),
		model = Typed.optional(Typed.string()),
		effort = Typed.optional(Typed.string()),
		auto = Typed.optional(Typed.boolean()),
		calls = Typed.array(Call),
		tasks = Typed.optional(Typed.array(Typed.table({
			id = Typed.string(),
			description = Typed.string(),
			kind = Typed.string(),
			status = Typed.string(),
			background = Typed.boolean(),
			depth = Typed.number(),
		}))),
		planning = Typed.optional(Typed.boolean()),
		milliseconds = Typed.number(),
		tokens = Tokens,
		cost = Typed.number(),
		limits = Typed.optional(Typed.array(Limit)),
		contextWindow = Typed.optional(Typed.number()),
		contextModel = Typed.optional(Typed.string()),
		context = Typed.optional(Breakdown),
		imageCount = Typed.number(),
		permission = Typed.optional(Permission),
		question = Typed.optional(Asked),
		error = Typed.optional(Typed.string()),
		version = Typed.number(),
	}),
	Usage = Typed.table({
		asked = Typed.boolean(),
		limits = Typed.optional(Typed.array(Limit)),
		context = Typed.optional(Breakdown),
	}),
	Versions = Typed.table({
		current = Typed.optional(Typed.string()),
		bridge = Typed.optional(Typed.string()),
		matched = Typed.optional(Typed.boolean()),
		known = Typed.optional(Typed.boolean()),
		latest = Typed.optional(Typed.string()),
		newer = Typed.boolean(),
		releases = Typed.array(Typed.table({
			version = Typed.string(),
			name = Typed.string(),
			prerelease = Typed.boolean(),
			notes = Typed.string(),
		})),
	}),
	Conversations = Typed.table({conversations = Typed.array(Summary)}),
	Conversation = Typed.table({
		id = Typed.string(),
		title = Typed.string(),
		source = Typed.string(),
		messages = Typed.array(Message),
	}),
	Lint = Typed.table({
		scripts = Typed.array(Typed.table({
			path = Typed.string(),
			lines = Typed.array(Typed.string()),
		})),
	}),
	Models = Typed.table({
		models = Typed.array(Typed.table({
			value = Typed.string(),
			displayName = Typed.string(),
			description = Typed.string(),
			supportsEffort = Typed.boolean(),
			supportedEffortLevels = Typed.array(Typed.string()),
			contextWindow = Typed.optional(Typed.number()),
			extra = Typed.optional(Typed.boolean()),
		})),
	}),
	Commands = Typed.table({
		slashCommands = Typed.array(Typed.string()),
		skills = Typed.array(Typed.string()),
		commands = Typed.optional(Typed.array(Typed.table({
			name = Typed.string(),
			description = Typed.string(),
		}))),
	}),
	Chapters = Typed.table({
		chapters = Typed.array(Typed.table({
			index = Typed.number(),
			title = Typed.string(),
		})),
	}),
	Servers = Typed.table({
		servers = Typed.array(Typed.table({
			name = Typed.string(),
			command = Typed.string(),
			arguments = Typed.string(),
			status = Typed.string(),
		})),
	}),
	Image = Typed.table({
		width = Typed.number(),
		height = Typed.number(),
		pixels = Typed.string(),
	}),
}