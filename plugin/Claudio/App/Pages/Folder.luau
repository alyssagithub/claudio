--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Parent.Components.Button)

const Create = Vide.create

return function()
	const Typing = Vide.source("")
	const Problem = Vide.source("")
	const Checking = Vide.source(false)

	local Alive = true

	Vide.cleanup(function()
		Alive = false
	end)

	const function Browse()
		if Checking() then
			return
		end

		Checking(true)
		Problem("")

		if not Client.StartBrowse() then
			Checking(false)
			Problem("Could not open a folder window. Type or paste the path instead.")

			return
		end

		local Pending = true
		local Path = ""
		local Waited = 0

		while Pending and Alive and task.wait(0.4) do
			Pending, Path = Client.TakeBrowse()
			Waited += 0.4

			if Waited > 600 then
				break
			end
		end

		Checking(false)

		if Path == "" or not Alive then
			return
		end

		Typing(Path)
		Settings.Set("WorkingFolder", Path)
		task.spawn(Chat.Refresh)
	end

	const function Save()
		if Checking() then
			return
		end

		const Wanted = Typing():gsub("^%s+", ""):gsub("%s+$", ""):gsub('^"', ""):gsub('"$', "")

		if Wanted == "" then
			Problem("Type a folder path first.")

			return
		end

		Checking(true)

		const Usable = Client.CheckFolder(Wanted)

		Checking(false)

		if not Usable then
			Problem("That folder does not exist on this machine.")

			return
		end

		Problem("")
		Settings.Set("WorkingFolder", Wanted)
		task.spawn(Chat.Refresh)
	end

	return Create "Frame" {
		Name = "FolderPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 20),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 10),
		},
		Create "TextLabel" {
			Name = "Title",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Text = "Pick a folder to work in",
		},
		Create "TextLabel" {
			Name = "Detail",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Text = "Claude runs in this folder, so a CLAUDE.md there applies and it can read files next to it. Your Studio place is reached through the Roblox tools either way. You can change this later in settings.",
		},
		Create "TextBox" {
			Name = "Path",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Colors.Input,
			TextColor3 = Theme.Colors.Text,
			PlaceholderColor3 = Theme.Colors.DimText,
			PlaceholderText = "C:\\Users\\you\\Documents\\MyGame",
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 3,
			Text = "",

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			},
			Vide.changed("Text", function(Value: string)
				Typing(Value)
			end),
		},
		Create "TextLabel" {
			Name = "Problem",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Error,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 4,
			Visible = function()
				return Problem() ~= ""
			end,
			Text = Problem,
		},
		Create "Frame" {
			Name = "Actions",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 5,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Button {
				Text = "Use this path",
				LayoutOrder = 1,
				OnClick = function()
					task.spawn(Save)
				end,
			},
			Button {
				Text = function()
					return if Checking() then "Waiting" else "Browse"
				end,
				Primary = true,
				LayoutOrder = 2,
				OnClick = function()
					task.spawn(Browse)
				end,
			},
		},
	}
end