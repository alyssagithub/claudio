--!strict
const Config = require(script.Parent.Parent.Config)

const Widget = {}

function Widget.Create(CurrentPlugin: Plugin): DockWidgetPluginGui
	const Made, Created = pcall(CurrentPlugin.CreateDockWidgetPluginGuiAsync, CurrentPlugin, Config.WidgetId, DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, true, 360, 520, 240, 240))

	if not Made then
		error(`{Config.Name} could not open its window — {Created}`, 0)
	end

	Created.Name = Config.WidgetId
	Created.Title = `{Config.Name} v{Config.Version}`
	Created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	return Created
end

return Widget