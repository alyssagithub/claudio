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
	Added = Enum.StudioStyleGuideColor.DiffTextAdditionBackground,
	Removed = Enum.StudioStyleGuideColor.DiffTextDeletionBackground,
	Altered = Enum.StudioStyleGuideColor.DiffTextNoChangeBackground,
	DiffText = Enum.StudioStyleGuideColor.DiffTextNoChange,
	CodeText = Enum.StudioStyleGuideColor.ScriptText,
}

const Theme = {
	Colors = {} :: {[string]: (Color3?) -> Color3},
}

const function Channel(Value: number): number
	return if Value <= 0.03928 then Value / 12.92 else ((Value + 0.055) / 1.055) ^ 2.4
end

const function Luminance(Colour: Color3): number
	return 0.2126 * Channel(Colour.R) + 0.7152 * Channel(Colour.G) + 0.0722 * Channel(Colour.B)
end

const function Readable(Source: StudioTheme): Color3
	const Dim = Source:GetColor(Enum.StudioStyleGuideColor.DimmedText)
	const Full = Source:GetColor(Enum.StudioStyleGuideColor.MainText)
	const Back = Source:GetColor(Enum.StudioStyleGuideColor.Titlebar)
	const Behind = Luminance(Back)

	for Step = 0, 20 do
		const Blended = Dim:Lerp(Full, Step / 20)
		const Front = Luminance(Blended)

		if (math.max(Front, Behind) + 0.05) / (math.min(Front, Behind) + 0.05) >= 4.5 then
			return Blended
		end
	end

	return Full
end

local ThemeConnection: RBXScriptConnection?
local Painted: StudioTheme?

function Theme.Paint(Chosen: StudioTheme?)
	Painted = Chosen

	for Name, Color in Guide do
		Theme.Colors[Name]((Painted or Studio.Theme):GetColor(Color))
	end

	Theme.Colors.DimText(Readable(Painted or Studio.Theme))
end

function Theme.Init()
	for Name, Color in Guide do
		Theme.Colors[Name] = Vide.source(Studio.Theme:GetColor(Color))
	end

	Theme.Colors.DimText(Readable(Studio.Theme))

	ThemeConnection = Studio.ThemeChanged:Connect(function()
		for Name, Color in Guide do
			Theme.Colors[Name]((Painted or Studio.Theme):GetColor(Color))
		end

		Theme.Colors.DimText(Readable(Painted or Studio.Theme))
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