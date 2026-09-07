--!strict
const Config = require(script.Parent.Parent.Config)

const Toolbar = {}

function Toolbar.Create(CurrentPlugin: Plugin, OnClick: () -> ()): (PluginToolbar, PluginToolbarButton)
	const Created = CurrentPlugin:CreateToolbar(Config.Name)
	const Button = Created:CreateButton("Chat", "Open the Claudio chat", Config.ButtonIcon, "Claudio")

	Button.ClickableWhenViewportHidden = true
	Button.Click:Connect(OnClick)

	return Created, Button
end

return Toolbar