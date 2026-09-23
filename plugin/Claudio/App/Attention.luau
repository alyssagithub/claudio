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

	if #Last <= 200 then
		return Last
	end

	const Sentences = {}

	for Sentence in (`{(Last:gsub("([%.!?])%s+", "%1\n"))}\n`):gmatch("([^\n]+)\n") do
		table.insert(Sentences, (Sentence:match("^%s*(.-)%s*$") :: string))
	end

	local Kept = ""

	for Index = #Sentences, 1, -1 do
		const Sentence = Sentences[Index]

		if #Kept + #Sentence + 1 > 200 then
			break
		end

		Kept = if Kept == "" then Sentence else `{Sentence} {Kept}`
	end

	if Kept ~= "" then
		return Kept
	end

	return `...{Last:sub(-197)}`
end

function Attention.Notify(Text: string)
	const Wanted = {
		sound = Settings.Get("Sound")(),
		flash = Settings.Get("Flash")(),
		toast = Settings.Get("Toast")(),
		banner = Settings.Get("Banner")(),
		anywhere = Settings.Get("NotifyWhenFocused")(),
		seconds = if Settings.Get("StickyToast")() then 0 else Settings.Get("ToastSeconds")(),
	}

	if not (Wanted.sound or Wanted.flash or Wanted.toast or Wanted.banner) then
		return
	end

	task.spawn(Client.Notify, Config.Name, Attention.Closing(Text), Wanted)
end

return Attention