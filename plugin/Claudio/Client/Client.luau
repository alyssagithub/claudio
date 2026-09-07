--!strict
const Http = require(script.Parent.Http)
const Error = require(script.Parent.Error)
const Config = require(script.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Types)
const Connection = require(script.Parent.Parent.Store.Connection)
const Typed = require(script.Parent.Parent.Packages.typed)
const Schemas = require(script.Parent.Schemas)

const function BaseUrl(): string
	return `http://127.0.0.1:{Settings.Get("Port")()}`
end

const function Checked(Ok: boolean, Result: any, Schema: any): (boolean, any)
	if not Ok then
		return false, Result
	end

	const Parsed = Schema.parse(Result)

	if not Parsed.ok then
		return false, `The bridge sent something unexpected. {Typed.formatIssues(Parsed.issues)}`
	end

	return true, Parsed.value
end

const Client = {}

function Client.Connect(): boolean
	Connection.Status("Connecting")

	const Fetched, Response = Http.Request("GET", `{BaseUrl()}/health`)
	const Ok, Result = Checked(Fetched, Response, Schemas.Health)

	if not Ok then
		Connection.Fail(Error.Classify(Result))

		return false
	end

	if Result.protocolVersion ~= Config.ProtocolVersion then
		Connection.Fail("VersionMismatch")

		return false
	end

	Connection.Health(Result)
	Connection.Status("Connected")

	return true
end

local PlaceName: string?
local NamedPlaceId = 0

const function GetPlaceName(): string
	if PlaceName and NamedPlaceId == game.PlaceId then
		return PlaceName
	end

	if game.PlaceId == 0 then
		return game.Name
	end

	const Ok, Info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
	end)

	NamedPlaceId = game.PlaceId
	PlaceName = if Ok and typeof(Info.Name) == "string" and Info.Name ~= "" then Info.Name else game.Name

	return PlaceName :: string
end

function Client.StartTurn(Text: string, ConversationId: string?, Images: {Types.ImageUpload}, Escalate: boolean?): (boolean, any)
	const Effort = Settings.Get("Effort")()

	return Http.Request("POST", `{BaseUrl()}/chat`, {
		text = Text,
		conversationId = ConversationId,
		images = Images,
		model = Settings.Get("Model")(),
		effort = if Effort == "" then nil else Effort,
		askForTools = Settings.Get("AskForTools")(),
		guardTools = Settings.Get("GuardTools")(),
		extraPrompt = Settings.Get("ExtraPrompt")(),
		fastMode = Settings.Get("FastMode")(),
		mode = Settings.Get("Mode")(),
		bypass = Settings.Get("Bypass")(),
		workingDirectory = Settings.Get("WorkingFolder")(),
		escalate = Escalate,
		place = {
			name = GetPlaceName(),
			placeId = if game.PlaceId == 0 then nil else string.format("%d", game.PlaceId),
			universeId = if game.GameId == 0 then nil else string.format("%d", game.GameId),
		},
	})
end

function Client.PollTurn(RequestId: string, Version: number): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/turn/{RequestId}?version={Version}`)

	return Checked(Ok, Result, Schemas.Turn)
end

function Client.CancelTurn(RequestId: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/turn/{RequestId}/cancel`)
end

function Client.AnswerPermission(RequestId: string, PermissionId: string, Allow: boolean, Always: boolean): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/turn/{RequestId}/permission`, {
		id = PermissionId,
		allow = Allow,
		always = Always,
	})
end

function Client.AnswerQuestion(RequestId: string, QuestionId: string, Answers: {[string]: string}?): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/turn/{RequestId}/answer`, {
		id = QuestionId,
		answers = Answers,
	})
end

function Client.TakeStudioJob(): (boolean, any)
	return Http.Request("GET", `{BaseUrl()}/studio/job`)
end

function Client.AnswerStudio(JobId: string, Result: any): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/studio/job`, {
		id = JobId,
		result = Result,
	})
end

function Client.Aun(): (boolean, any)
	return Http.Request("GET", `{BaseUrl()}/aun`)
end

function Client.GetImage(RequestId: string, Index: number): (boolean, any)
	return Http.Request("GET", `{BaseUrl()}/turn/{RequestId}/image/{Index}`)
end

function Client.WriteClipboard(Text: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/clipboard/text`, {text = Text})
end

function Client.GetPicker(): (boolean, any)
	return Http.Request("GET", `{BaseUrl()}/picker?take=1`)
end

function Client.GetClipboardImage(): (boolean, any)
	return Http.Request("GET", `{BaseUrl()}/clipboard`)
end

function Client.ArmClipboard(Marker: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/clipboard/arm`, {marker = Marker})
end

function Client.DisarmClipboard(Marker: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/clipboard/disarm`, {marker = Marker})
end

function Client.DecodeImage(Data: string, MediaType: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/decode`, {
		data = Data,
		mediaType = MediaType,
	})
end

function Client.GetCommands(): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/commands`)

	return Checked(Ok, Result, Schemas.Commands)
end

function Client.Lint(Scripts: {any}, Tree: {any}): (boolean, any)
	const Ok, Result = Http.Request("POST", `{BaseUrl()}/lint`, {
		scripts = Scripts,
		tree = Tree,
	})

	return Checked(Ok, Result, Schemas.Lint)
end

function Client.GetModels(): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/models`)

	return Checked(Ok, Result, Schemas.Models)
end

function Client.GetUsage(ConversationId: string?): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/usage?conversationId={ConversationId or ""}`)

	return Checked(Ok, Result, Schemas.Usage)
end

function Client.StartBrowse(): boolean
	const Ok, Result = Http.Request("POST", `{BaseUrl()}/folder/browse`)

	if not Ok or typeof(Result) ~= "table" then
		return false
	end

	return Result.started == true
end

function Client.TakeBrowse(): (boolean, string)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/folder/browse`)

	if not Ok or typeof(Result) ~= "table" then
		return false, ""
	end

	return Result.pending == true, if typeof(Result.path) == "string" then Result.path else ""
end

function Client.CheckFolder(Path: string): boolean
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/folder?path={Path:gsub("[^%w%-%._~]", function(Letter) return string.format("%%%02X", Letter:byte()) end)}`)

	return Ok and Result.usable == true
end

function Client.GetVersions(): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/versions?plugin={Config.Version}`)

	return Checked(Ok, Result, Schemas.Versions)
end

function Client.InstallVersion(Version: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/versions`, {version = Version})
end

function Client.GetMcpServers(): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/mcp`)

	return Checked(Ok, Result, Schemas.Servers)
end

function Client.ListConversations(): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/conversations`)

	return Checked(Ok, Result, Schemas.Conversations)
end

function Client.GetConversation(Id: string): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/conversations/{Id}`)

	return Checked(Ok, Result, Schemas.Conversation)
end

function Client.ConversationExists(Id: string): boolean
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/conversations/{Id}/exists`)

	return not Ok or Result.exists ~= false
end

function Client.GetConversationImage(Id: string, Index: number): (boolean, any)
	return Http.Request("GET", `{BaseUrl()}/conversations/{Id}/image/{Index}`)
end

function Client.RenameConversation(Id: string, Title: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/conversations/{Id}/title`, {title = Title})
end

function Client.SetConversationFlag(Id: string, Flag: string, Value: boolean): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/conversations/{Id}/{Flag}`, {value = Value})
end

function Client.GetChapters(Id: string): (boolean, any)
	const Ok, Result = Http.Request("GET", `{BaseUrl()}/conversations/{Id}/chapters`)

	return Checked(Ok, Result, Schemas.Chapters)
end

function Client.SetChapters(Id: string, Chapters: {Types.Chapter}): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/conversations/{Id}/chapters`, {chapters = Chapters})
end

function Client.ForkConversation(Id: string): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/conversations/{Id}/fork`)
end

function Client.DeleteConversation(Id: string): (boolean, any)
	return Http.Request("DELETE", `{BaseUrl()}/conversations/{Id}`)
end

function Client.Notify(Title: string, Body: string, Options: {[string]: boolean}): (boolean, any)
	return Http.Request("POST", `{BaseUrl()}/notify`, {
		title = Title,
		body = Body,
		sound = Options.sound,
		flash = Options.flash,
		toast = Options.toast,
		banner = Options.banner,
		anywhere = Options.anywhere,
	})
end

return Client