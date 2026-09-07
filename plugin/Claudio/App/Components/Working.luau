--!strict
const RunService = game:GetService("RunService")

const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Format = require(script.Parent.Parent.Parent.Format)

const Create = Vide.create

const Words = {
	"Still thinking",
	"Still working",
	"Still puzzling",
	"Still digging",
	"Still pondering",
	"Still noodling",
	"Still untangling",
	"Still considering",
}

const function Running(): boolean
	for _, Call in Chat.Calls() do
		if Call.status == "running" then
			return true
		end
	end

	return false
end

return function()
	const Word = Vide.source(Words[1])
	const Dots = Vide.source(1)
	const Seconds = Vide.source(0)

	const function Phase(): string
		if Chat.Elapsed() == 0 and Chat.StreamingText() == "" then
			return "Sending"
		end

		if Running() then
			return "Running tools"
		end

		if Chat.StreamingText() ~= "" then
			return "Almost done thinking"
		end

		const Tokens = Chat.Tokens()

		if #Chat.Activity() == 0 and (not Tokens or Tokens.output == 0) then
			return "Waiting for Claude"
		end

		return Word()
	end

	return Create "TextButton" {
		Name = "Working",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 2,
		Activated = function()
			Chat.Thinking(not Chat.Thinking())
		end,

		Vide.action(function()
			local Chosen = 1

			Vide.cleanup(RunService.Heartbeat:Connect(function()
				const Started = Chat.Began()

				if Started == 0 then
					return
				end

				const Elapsed = os.clock() - Started
				const Next = math.floor(Elapsed / 3) % #Words + 1

				Dots(math.floor(Elapsed * 2.5) % 3 + 1)
				Seconds(math.floor(Elapsed))

				if Next ~= Chosen then
					Chosen = Next
					Word(Words[Next])
				end
			end))
		end),
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Create "ImageLabel" {
			Name = "Icon",
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = Config.ButtonIcon,
			LayoutOrder = 1,
		},
		Create "TextLabel" {
			Name = "Detail",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			LayoutOrder = 2,
			Text = function()
				const Tokens = Chat.Tokens()
				const Counted = if Tokens then Tokens.output else 0
				const Parts = {Format.Clock(Seconds())}

				if Counted > 0 then
					table.insert(Parts, `{Format.Amount(Counted)} tokens`)
				end

				table.insert(Parts, `{Phase()}{string.rep(".", Dots())}`)

				return table.concat(Parts, " · ")
			end,
		},
	}
end