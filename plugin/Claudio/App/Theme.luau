--!strict
const Vide = require(script.Parent.Parent.Packages.vide)

const Studio = settings().Studio

const Guide: {[string]: Enum.StudioStyleGuideColor} = {
	Background = Enum.StudioStyleGuideColor.MainBackground,
	Panel = Enum.StudioStyleGuideColor.Titlebar,
	Text = Enum.StudioStyleGuideColor.MainText,
	DimText = Enum.StudioStyleGuideColor.DimmedText,
	Input = Enum.StudioStyleGuideColor.InputFieldBackground,
	Border = Enum.StudioStyleGuideColor.Border,
	Button = Enum.StudioStyleGuideColor.Button,
	ButtonText = Enum.StudioStyleGuideColor.ButtonText,
	Accent = Enum.StudioStyleGuideColor.DialogMainButton,
	AccentText = Enum.StudioStyleGuideColor.DialogMainButtonText,
	Error = Enum.StudioStyleGuideColor.ErrorText,
	Code = Enum.StudioStyleGuideColor.ScriptBackground,
	CodeText = Enum.StudioStyleGuideColor.ScriptText,
}

const Theme = {
	Colors = {} :: {[string]: (Color3?) -> Color3},
}

local ThemeConnection: RBXScriptConnection?

function Theme.Init()
	for Name, Color in Guide do
		Theme.Colors[Name] = Vide.source(Studio.Theme:GetColor(Color))
	end

	ThemeConnection = Studio.ThemeChanged:Connect(function()
		for Name, Color in Guide do
			Theme.Colors[Name](Studio.Theme:GetColor(Color))
		end
	end)
end

function Theme.Destroy()
	if not ThemeConnection then
		return
	end

	ThemeConnection:Disconnect()
	ThemeConnection = nil
end

return Theme