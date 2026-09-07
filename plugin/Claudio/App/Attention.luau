--!strict
const Config = require(script.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Client.Client)

const Attention = {}

function Attention.Notify(Text: string)
	const Wanted = {
		sound = Settings.Get("Sound")(),
		flash = Settings.Get("Flash")(),
		toast = Settings.Get("Toast")(),
		banner = Settings.Get("Banner")(),
		anywhere = Settings.Get("NotifyWhenFocused")(),
	}

	if not (Wanted.sound or Wanted.flash or Wanted.toast or Wanted.banner) then
		return
	end

	task.spawn(Client.Notify, Config.Name, Text, Wanted)
end

return Attention