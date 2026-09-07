--!strict
const Toolbar = {}

function Toolbar.Create(CurrentPlugin: Plugin, OnClick: () -> ()): (PluginToolbar, PluginToolbarButton)
	if not _G.ClaudioTestBar then
		const Bar = CurrentPlugin:CreateToolbar("Claudio testing")

		_G.ClaudioTestBar = Bar
		_G.ClaudioTestButton = Bar:CreateButton("ClaudioTestChat", "Open the Claudio test chat", "", "Claudio")
	end

	const Button = _G.ClaudioTestButton :: PluginToolbarButton

	Button.ClickableWhenViewportHidden = true

	if _G.ClaudioTestClick then
		(_G.ClaudioTestClick :: RBXScriptConnection):Disconnect()
	end

	_G.ClaudioTestClick = Button.Click:Connect(OnClick)
	Button.Enabled = true

	return _G.ClaudioTestBar :: PluginToolbar, Button
end

function Toolbar.Retire()
	if _G.ClaudioTestClick then
		(_G.ClaudioTestClick :: RBXScriptConnection):Disconnect()

		_G.ClaudioTestClick = nil
	end

	if _G.ClaudioTestButton then
		(_G.ClaudioTestButton :: PluginToolbarButton).Enabled = false
	end
end

return Toolbar