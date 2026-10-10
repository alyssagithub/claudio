--!strict
const Config = require(script.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Client.Client)

const Attention = {}

function Attention.Closing(Text: string): string
	local Last = ""

	for Paragraph in (`{(Text:gsub("```.-```", "\n\n"))}\n\n`):gmatch("(.-)\n%s*\n") do
		const Plain = (Paragraph:gsub("%[([^%]]*)%]%([^%)]*%)", "%1"):gsub("[`*_]", ""):gsub("\n%s*[#>%-]*%s*", " "):gsub("^%s*[#>%-]*%s*", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")) :: string

		if Plain ~= "" then
			Last = Plain
		end
	end

	const First = (Last:match("^(.-[%.!?])%s") or Last) :: string

	return if #First <= 200 then First else `{First:sub(1, 197)}...`
end

function Attention.NotifyElsewhere(Title: string, Text: string)
	Attention.Notify(Text, Title)
end

function Attention.Notify(Text: string, Chat: string?)
	const Wanted = {
		sound = Settings.Get("Sound")(),
		flash = Settings.Get("Flash")(),
		toast = Settings.Get("Toast")(),
		anywhere = Settings.Get("NotifyWhenFocused")(),
		seconds = if Settings.Get("StickyToast")() then 0 else Settings.Get("ToastSeconds")(),
	}

	if not (Wanted.sound or Wanted.flash or Wanted.toast) then
		return
	end

	-- The testing mount says so in its notifications, so they are never mistaken for the real plugin's.
	const Name = if (script.Parent.Parent :: Instance).Name:match("Testing$") then "Claudio Testing" else Config.Name

	task.spawn(Client.Notify, if Chat then `{Name}: {Chat}` else Name, Attention.Closing(Text), Wanted)
end

return Attention