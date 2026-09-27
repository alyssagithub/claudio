--!strict
const RunService = game:GetService("RunService")

const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)
const Format = require(script.Parent.Parent.Parent.Format)

const Create = Vide.create

-- The wording and timing below follow the Claude desktop app's working line.
const Waits: {[string]: string} = {
	sending = "Sending",
	starting = "Starting session",
	preparing = "Preparing",
	model = "Waiting for Claude",
	tools = "Running tools",
}

const HoldThinking = 2
const ShowThought = 2
const SettleLabel = 0.15

const function ThinkingLabel(Elapsed: number): string
	if Elapsed >= 60 then
		return "Almost done thinking"
	elseif Elapsed >= 45 then
		return "Thinking some more"
	elseif Elapsed >= 30 then
		return "Thinking more"
	elseif Elapsed >= 15 then
		return "Still thinking"
	end

	return "Thinking"
end

const function ShortError(Retry: {error: string, status: number?}): string
	if Retry.error == "overloaded" then
		return "Service is busy"
	elseif Retry.error == "server_error" then
		return "Server error"
	elseif Retry.status == nil then
		return "Connection problem"
	end

	return "Something went wrong"
end

const function TasksLabel(): string?
	local Running = 0

	for _, Task in Chat.Tasks() do
		if Task.status == "running" then
			Running += 1
		end
	end

	return if Running > 0 then `{Running} running task{if Running == 1 then "" else "s"}` else nil
end

return function()
	const Dots = Vide.source(1)
	const Seconds = Vide.source(0)
	const Thought = Vide.source(nil :: string?)
	const Waiting = Vide.source(nil :: string?)

	local ThinkingSince = 0
	local HeldUntil = 0
	local ThoughtFor = 0
	local WasThinking = false
	local Settling: string? = nil
	local SettlingSince = 0
	local WasWorking = false

	const function Dotted(Text: string): string
		return `{Text}{string.rep(".", Dots())}`
	end

	const function Line(): string
		const Tasks = TasksLabel()
		const Working = Chat.Waiting() == 0

		if Chat.Stopping() then
			return if Tasks then `{Dotted("Stopping")} · {Tasks}` else Dotted("Stopping")
		end

		if not Working and Tasks then
			return Tasks
		end

		const Clock = Format.Clock(Seconds())
		const Retry = Chat.ApiRetry()

		if Retry then
			return `{ShortError(Retry)} · Retrying ({Retry.attempt}/{Retry.maxRetries}) · {Clock}`
		end

		if Chat.Compacting() then
			return `{Dotted("Compacting session")} · {Clock}`
		end

		const Parts = {Clock}
		const Tokens = Chat.Tokens()
		const Counted = if Tokens then Tokens.output else 0

		if Counted > 0 then
			table.insert(Parts, `{Format.Amount(Counted)} tokens`)
		end

		if Tasks then
			table.insert(Parts, Tasks)
		end

		const Label = Thought() or Waiting()

		if Label then
			table.insert(Parts, if Label:sub(1, 11) == "Thought for" then Label else Dotted(Label))
		end

		return table.concat(Parts, " · ")
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
			Vide.cleanup(RunService.Heartbeat:Connect(function()
				const Started = Chat.Began()

				if Started == 0 then
					WasThinking = false
					WasWorking = false
					HeldUntil = 0
					ThoughtFor = 0
					Settling = nil

					return
				end

				const Now = os.clock()
				const Elapsed = Now - Started
				const InBlock = Chat.ThinkingBlock()

				if InBlock and not WasThinking then
					ThinkingSince = Now
					ThoughtFor = 0
				elseif WasThinking and not InBlock then
					ThoughtFor = Now - ThinkingSince
					HeldUntil = Now + math.max(0, HoldThinking - ThoughtFor)
				end

				WasThinking = InBlock
				Dots(math.floor(Elapsed * 2.5) % 3 + 1)
				Seconds(math.floor(Elapsed))

				local Thinking: string? = nil

				if InBlock or Now < HeldUntil then
					Thinking = ThinkingLabel(Elapsed)
				elseif ThoughtFor > 0 and Now < HeldUntil + ShowThought then
					Thinking = `Thought for {math.max(1, math.floor(ThoughtFor + 0.5))}s`
				end

				if Thinking ~= Vide.untrack(Thought) then
					Thought(Thinking)
				end

				const Stage = Chat.Stage()
				const Wanted = if Stage then Waits[Stage] else nil
				const Tokens = Vide.untrack(Chat.Tokens)
				const Counted = Elapsed >= 2 and Tokens ~= nil and Tokens.output > 0
				const Shown = Vide.untrack(Waiting)
				const Target = if Wanted == nil and not Counted and Thinking == nil then Shown else Wanted
				const Fresh = not WasWorking

				WasWorking = true

				if Target == Shown then
					Settling = nil
				elseif Fresh or Target == nil or Shown == nil then
					Settling = nil
					Waiting(Target)
				elseif Settling ~= Target then
					Settling = Target
					SettlingSince = Now
				elseif Now - SettlingSince >= SettleLabel then
					Settling = nil
					Waiting(Target)
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
			Text = Line,
		},
	}
end
