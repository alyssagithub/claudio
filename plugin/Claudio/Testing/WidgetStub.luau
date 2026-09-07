--!strict
const PluginGuiService = game:GetService("PluginGuiService")

const Widget = {}

function Widget.Create(CurrentPlugin: Plugin): DockWidgetPluginGui
	const Existing = PluginGuiService:FindFirstChild("ClaudioTestWidget")

	if Existing then
		const Reused = Existing :: DockWidgetPluginGui

		Reused.Enabled = true

		return Reused
	end

	const Made, Created = pcall(CurrentPlugin.CreateDockWidgetPluginGuiAsync, CurrentPlugin, "ClaudioTestWidget", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, true, 360, 520, 240, 240))

	if not Made then
		error(`Claudio could not open its testing window: {Created}`)
	end

	Created.Name = "ClaudioTestWidget"
	Created.Title = "Claudio (testing)"
	Created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	return Created
end

return Widget