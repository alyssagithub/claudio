--!strict
const Vide = require(script.Parent.Packages.vide)
const Config = require(script.Parent.Config)

export type Definition = {
	Key: string,
	Label: string,
	Detail: string,
	Group: string,
	Default: any,
	Minimum: number?,
	Maximum: number?,
	Options: {string}?,
}

const Definitions: {Definition} = {
	{
		Key = "Sound",
		Label = "Play a sound",
		Detail = "A Windows chime when a reply lands",
		Group = "Notifications",
		Default = true,
	},
	{
		Key = "Flash",
		Label = "Flash the taskbar",
		Detail = "",
		Group = "Notifications",
		Default = true,
	},
	{
		Key = "Toast",
		Label = "Show a desktop notification",
		Detail = "",
		Group = "Notifications",
		Default = true,
	},
	{
		Key = "Banner",
		Label = "Show notifications in fullscreen",
		Detail = "Claudio draws its own banner, which Windows notifications cannot cover",
		Group = "Notifications",
		Default = true,
	},
	{
		Key = "NotifyWhenFocused",
		Label = "Notify even when Studio is in front",
		Detail = "Off means only the sound plays when Studio is in front",
		Group = "Notifications",
		Default = false,
	},
	{
		Key = "PlaytestPicker",
		Label = "Pick objects in playtests",
		Detail = "Adds a picker toolbar to playtests. Its helper script sits in ServerScriptService while this is on",
		Group = "Chat",
		Default = false,
	},
	{
		Key = "ClipboardPaste",
		Label = "Paste images with Ctrl+V",
		Detail = "",
		Group = "Chat",
		Default = true,
	},
	{
		Key = "SendWithEnter",
		Label = "Send with Enter",
		Detail = "Off means Enter starts a new line and the button sends",
		Group = "Chat",
		Default = true,
	},
	{
		Key = "AttachSelection",
		Label = "Always attach the selection",
		Detail = "Sends whatever is selected in the Explorer with every message",
		Group = "Chat",
		Default = false,
	},
	{
		Key = "UndoPoint",
		Label = "One undo point per reply",
		Detail = "Ctrl+Z reverts everything Claude changed in a single reply",
		Group = "Chat",
		Default = true,
	},
	{
		Key = "AskForTools",
		Label = "Ask before non-Roblox tools run",
		Detail = "Shell commands, file edits and web access wait for you",
		Group = "Chat",
		Default = false,
	},
	{
		Key = "WatchChanges",
		Label = "Track what changes in Studio",
		Detail = "Lists the instances a reply actually created, deleted or edited",
		Group = "Chat",
		Default = true,
	},
	{
		Key = "ShareEdits",
		Label = "Send your own edits to Claude",
		Detail = "Listed with your next message. Needs the setting above",
		Group = "Chat",
		Default = true,
	},
	{
		Key = "FixLint",
		Label = "Fix script warnings automatically",
		Detail = "After Claude edits a script, its warnings are sent back so Claude can correct them. Uses extra tokens",
		Group = "Chat",
		Default = true,
	},
	{
		Key = "GuardTools",
		Label = "Confirm risky tools",
		Detail = "Asks before deleting instances or rewriting a whole script",
		Group = "Chat",
		Default = false,
	},
	{
		Key = "TranscriptView",
		Label = "Transcript view",
		Detail = "Thinking shows Claude's reasoning and every tool call, normal shows the tools alone",
		Group = "Appearance",
		Default = "Normal",
		Options = {
			"Thinking",
			"Normal",
		},
	},
	{
		Key = "RingStat",
		Label = "Usage ring shows",
		Detail = "Which number the ring in the corner fills up",
		Group = "Appearance",
		Default = "5-hour usage",
		Options = {
			"Context",
			"5-hour usage",
			"Weekly usage",
			"Weekly Fable usage",
		},
	},
	{
		Key = "TextSize",
		Label = "Text size",
		Detail = "",
		Group = "Appearance",
		Default = Config.TextSize,
		Minimum = 10,
		Maximum = 22,
	},
	{
		Key = "ExtraPrompt",
		Label = "Send Claudio's own instructions",
		Detail = "What Claude is told before your message. Shown below",
		Group = "Connection",
		Default = true,
	},
	{
		Key = "Port",
		Label = "Bridge port",
		Detail = "",
		Group = "Connection",
		Default = Config.DefaultPort,
		Minimum = 1024,
		Maximum = 65535,
	},
}

const Sources: {[string]: any} = {}
local CurrentPlugin: Plugin

const Hidden: {[string]: string | boolean} = {
	Model = "auto",
	Effort = "",
	FastMode = false,
	DeclinedVersion = "",
	WorkingFolder = "",
	LastChat = "",
	RelayToken = "",
	Mode = "auto",
	Bypass = false,
}

const Settings = {
	Definitions = Definitions,
	Hidden = Hidden,
}

function Settings.Load(PluginObject: Plugin)
	CurrentPlugin = PluginObject

	for _, Definition in Definitions do
		const Stored = CurrentPlugin:GetSetting(`Claudio_{Definition.Key}`)

		Sources[Definition.Key] = Vide.source(if Stored == nil then Definition.Default else Stored)
	end

	for Key, Default in Settings.Hidden do
		const Stored = CurrentPlugin:GetSetting(`Claudio_{Key}`)

		Sources[Key] = Vide.source(if Stored == nil then Default else Stored)
	end

	if Sources.Mode() == "standard" then
		Sources.Mode("auto")
	end
end

function Settings.Token(): string
	if not CurrentPlugin then
		return ""
	end

	const Given = CurrentPlugin:GetSetting("Claudio_BridgeToken")

	return if typeof(Given) == "string" then Given else ""
end

function Settings.TextSize(): number
	return Sources.TextSize()
end

function Settings.SmallText(): number
	return math.min(Sources.TextSize(), math.max(11, Sources.TextSize() - 2))
end

function Settings.Get(Key: string): any
	return assert(Sources[Key], `No setting named {Key}`)
end

function Settings.Set(Key: string, Value: any)
	Sources[Key](Value)
	CurrentPlugin:SetSetting(`Claudio_{Key}`, Value)
end

function Settings.Reset()
	for _, Definition in Definitions do
		Settings.Set(Definition.Key, Definition.Default)
	end

	for Key, Default in Settings.Hidden do
		if Key ~= "RelayToken" then
			Settings.Set(Key, Default)
		end
	end
end

return Settings