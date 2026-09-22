--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Keys = require(script.Parent.Parent.Parent.Store.Keys)
const Navigate = require(script.Parent.Parent.Parent.Navigate)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

export type Props = {
	Name: string,
	Text: () -> string,
	Size: (() -> number)?,
	Font: Enum.Font?,
	Colour: (() -> Color3)?,
	Background: (() -> Color3)?,
	Transparent: boolean?,
	Wide: boolean?,
	LayoutOrder: any,
	Links: (() -> {[string]: string})?,
	Urls: (() -> {[string]: string})?,
	Children: {Instance}?,
}

const function Spanning(Text: string, Needle: string, At: number): boolean
	if Needle == "" then
		return false
	end

	local From = 1

	while true do
		const Start, Stop = Text:find(Needle, From, true)

		if not Start or not Stop then
			return false
		end

		if At >= Start and At <= Stop then
			return true
		end

		From = Stop + 1
	end
end

return function(Props: Props)
	local Box: TextBox
	local Copies = 0
	local Focused = 0
	local Holding = false

	const function Pressed()
		if Box.SelectionStart ~= -1 and Box.SelectionStart ~= Box.CursorPosition then
			return
		end

		const At = Box.CursorPosition - 1
		const Plain = Keys.Clean(Box.Text)

		for Path, Full in (if Props.Links then Props.Links() else {}) do
			if Spanning(Plain, Path, At) then
				task.spawn(Navigate.Go, {Path = Full})

				return
			end
		end

		for Label, Url in (if Props.Urls then Props.Urls() else {}) do
			if Spanning(Plain, Label, At) then
				task.spawn(Chat.Copy, Url)

				return
			end
		end
	end

	Box = Create "TextBox" {
		Name = Props.Name,
		Size = if Props.Wide == false then UDim2.fromScale(0, 0) else UDim2.fromScale(1, 0),
		AutomaticSize = if Props.Wide == false then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
		BackgroundColor3 = Props.Background or Theme.Colors.Code,
		BackgroundTransparency = if Props.Transparent == false then 0 else 1,
		TextColor3 = Props.Colour or Theme.Colors.Text,
		TextSize = Props.Size or Settings.TextSize,
		FontFace = Font.fromEnum(Props.Font or Enum.Font.BuilderSans),
		TextWrapped = true,
		RichText = true,
		MultiLine = true,
		TextEditable = false,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = Props.LayoutOrder,
		Text = Props.Text,
		Focused = function()
			Focused += 1

			const Mine = Focused

			if not Holding then
				Holding = true
				Keys.Hold()
			end

			task.spawn(function()
				while Focused == Mine and task.wait(0.15) do
					Copies = Keys.CopySelection(Box, Copies)
				end
			end)
		end,
		FocusLost = function()
			Focused += 1

			if Holding then
				Holding = false
				Keys.Release()
			end
		end,
		InputEnded = function(Input: InputObject)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 and Box:IsFocused() then
				task.defer(Pressed)
			end
		end,

		Props.Children,
	}

	Vide.cleanup(function()
		Focused += 1

		if Holding then
			Holding = false
			Keys.Release()
		end
	end)

	return Box
end