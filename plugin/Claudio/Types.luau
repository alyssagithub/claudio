--!strict
export type Part = {
	name: string,
	tokens: number,
	colour: string,
	deferred: boolean,
}

export type Breakdown = {
	total: number,
	max: number,
	percentage: number,
	model: string?,
	categories: {Part},
}

export type Limit = {
	kind: string,
	label: string?,
	status: string,
	utilization: number?,
	resetsAt: number?,
}

export type Piece = {
	Kind: "thinking" | "text" | "call" | "user" | "notice",
	Text: string?,
	Call: number?,
	Id: string?,
}

export type Message = {
	Role: "user" | "assistant",
	Text: string,
	Parts: {Piece}?,
	Activity: {string}?,
	Thinking: string?,
	Attachments: {string}?,
	Images: {EditableImage}?,
	ImageIds: {number}?,
	Model: string?,
	Effort: string?,
	Checkpoint: number?,
	Edits: {Change}?,
	Calls: {ToolCall}?,
	Tokens: Tokens?,
	Milliseconds: number?,
	Failed: boolean?,
	Error: string?,
	Cost: number?,
	Estimated: boolean?,
	Uuid: string?,
	Parent: string?,
	Prompt: string?,
	At: number?,
}

export type Chip = {
	Kind: "instance" | "script" | "output" | "image" | "selection" | "runtime",
	Label: string,
	Token: string?,
	Instance: Instance?,
	Objects: {Instance}?,
	Preview: EditableImage?,
	Unreadable: boolean?,
	Description: string?,
	Data: string?,
	MediaType: string?,
	Lines: {string}?,
}

export type ImageUpload = {
	data: string,
	mediaType: string,
}

export type QueuedMessage = {
	Display: string,
	Full: string,
	Extra: string?,
	Attachments: {string},
	Images: {ImageUpload},
	Previews: {EditableImage},
	Edits: {Change}?,
	Id: string?,
	Sent: boolean?,
}

export type Choice = {
	label: string,
	description: string,
	preview: string?,
}

export type Question = {
	question: string,
	header: string,
	multiSelect: boolean,
	options: {Choice},
}

export type Asked = {
	id: string,
	questions: {Question},
}

export type Permission = {
	id: string,
	tool: string,
	input: string,
}

export type ModelInfo = {
	value: string,
	displayName: string,
	description: string,
	supportsEffort: boolean,
	supportedEffortLevels: {string},
	contextWindow: number?,
	extra: boolean?,
	supportsFastMode: boolean?,
}

export type Change = {
	Kind: "added" | "removed" | "changed",
	Text: string,
	Path: string?,
	Fields: {string}?,
	Added: number?,
	Removed: number?,
}

export type ToolCall = {
	name: string,
	input: string,
	output: string,
	status: "preparing" | "running" | "done" | "error",
	milliseconds: number,
	startedAt: number?,
	steps: {string}?,
	lines: {added: number, removed: number}?,
	image: number?,
}

export type Release = {
	version: string,
	name: string,
	prerelease: boolean,
	notes: string,
}

export type Versions = {
	current: string?,
	bridge: string?,
	matched: boolean?,
	known: boolean?,
	latest: string?,
	newer: boolean,
	releases: {Release},
}

export type Tokens = {
	input: number,
	output: number,
	cached: number,
}

export type Chapter = {
	index: number,
	title: string,
}

export type Command = {
	name: string,
	description: string,
}

export type McpTool = {
	name: string,
	description: string,
}

export type McpServer = {
	name: string,
	command: string,
	arguments: string,
	status: string,
	tools: {McpTool}?,
}

export type ConnectionStatus = "Disconnected" | "Connecting" | "Connected" | "Error"

export type BackgroundTask = {
	id: string,
	description: string,
	kind: string,
	status: string,
	startedAt: number,
	endedAt: number?,
	input: string,
	prompt: string?,
	summary: string?,
	toolUseId: string?,
}

export type Retry = {
	attempt: number,
	maxRetries: number,
	error: string,
	status: number?,
}

export type Turn = {
	requestId: string,
	received: boolean?,
	stage: string?,
	thinkingBlock: boolean?,
	retry: Retry?,
	automatic: boolean?,
	prompt: string?,
	waiting: number?,
	conversationId: string?,
	sessionId: string?,
	status: string,
	text: string,
	thinking: string?,
	parts: {{kind: string, text: string?, call: number?}}?,
	limits: {Limit}?,
	contextWindow: number?,
	context: Breakdown?,
	activity: {string},
	model: string?,
	effort: string?,
	auto: boolean?,
	imageCount: number,
	permission: Permission?,
	question: Asked?,
	error: string?,
	calls: {ToolCall},
	milliseconds: number,
	tokens: Tokens,
	cost: number,
	version: number,
}

export type Health = {
	name: string,
	version: string,
	protocolVersion: number,
	loggedIn: boolean,
	loginDetail: string?,
	mcpServers: {string},
	systemPrompt: string?,
	limits: {Limit}?,
	context: Breakdown?,
}

export type ConversationSummary = {
	id: string,
	title: string,
	project: string,
	folder: string?,
	source: "desktop" | "claudio",
	starred: boolean?,
	archived: boolean?,
	hidden: boolean?,
	createdAt: number,
	updatedAt: number,
}

export type Conversation = {
	id: string,
	title: string,
	project: string?,
	source: "desktop" | "claudio",
	messages: {
		{
			role: string,
			text: string,
			activity: {string}?,
			images: {number}?,
			at: number?,
		}
	},
}

export type Mode = {
	value: string,
	label: string,
	detail: string,
}

export type Task = {
	id: string,
	description: string,
	kind: string,
	status: string,
	background: boolean,
	depth: number,
	toolUseId: string?,
}

export type Reference = {
	Path: string,
	Line: number?,
}

return nil