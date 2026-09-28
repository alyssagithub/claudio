--!strict
-- The background tasks pane, following the Claude desktop app's: running tasks first, finished ones folded
-- under a count with a button to clear them, and each Bash task opening to its command and output.
const HttpService = game:GetService("HttpService")

const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Format = require(script.Parent.Parent.Parent.Format)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)
const IconButton = require(script.Parent.IconButton)

const Create = Vide.create

const Kinds: {[string]: string} = {
	local_agent = "Agent",
	in_process_teammate = "Agent",
	remote_agent = "Remote agent",
	local_bash = "Bash",
	local_workflow = "Workflow",
	monitor_mcp = "Monitor",
	monitor_ws = "Monitor",
	dream = "Dream",
}

const Statuses: {[string]: string} = {
	running = "Running",
	completed = "Completed",
	stopped = "Stopped",
	failed = "Failed",
}

const Monospace = Font.new("rbxasset://fonts/families/RobotoMono.json")

const function IsBash(Task: Types.BackgroundTask): boolean
	return Task.kind == "local_bash"
end

const function IsAgent(Task: Types.BackgroundTask): boolean
	return Task.kind == "local_agent" or Task.kind == "in_process_teammate"
end

const function HasSummary(Task: Types.BackgroundTask): boolean
	return typeof(Task.summary) == "string" and Task.summary ~= "" and Task.summary ~= Task.description
end

const function Command(Task: Types.BackgroundTask): string?
	const Ok, Input = pcall(HttpService.JSONDecode, HttpService, Task.input or "")

	return if Ok and typeof(Input) == "table" and typeof(Input.command) == "string" then Input.command else nil
end

const function Label(Text: string | () -> string, LayoutOrder: number, Colour: (() -> Color3)?, Size: (() -> number)?): TextLabel
	return Create "TextLabel" {
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		TextColor3 = Colour or Theme.Colors.DimText,
		TextSize = Size or Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = LayoutOrder,
		Text = Text,
	}
end

const function Block(Text: () -> string, LayoutOrder: number, Visible: () -> boolean): Frame
	return Create "Frame" {
		Name = "Block",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Background,
		LayoutOrder = LayoutOrder,
		Visible = Visible,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
		Create "TextLabel" {
			Name = "Text",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Monospace,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = Text,
		},
	}
end

const function Row(Value: () -> Types.BackgroundTask): Frame
	const Hovered = Vide.source(false)
	const Expanded = Vide.source(false)
	const Output = Vide.source(nil :: string?)
	const Loading = Vide.source(false)
	const Now = Vide.source(os.time())

	const function Running(): boolean
		return Value().status == "running"
	end

	const function Expandable(): boolean
		return IsBash(Value()) or HasSummary(Value())
	end

	local Alive = true

	Vide.cleanup(function()
		Alive = false
	end)

	-- Tick the running clock and follow the output while the row is open.
	task.spawn(function()
		while Alive do
			Now(os.time())

			const Task = Vide.untrack(Value)
			const Id = Chat.ConversationId()

			if Vide.untrack(Expanded) and IsBash(Task) and Id and (Task.status == "running" or Vide.untrack(Output) == nil) then
				if Vide.untrack(Output) == nil then
					Loading(true)
				end

				const Ok, Result = Client.TaskOutput(Id, Task.id)

				Loading(false)

				if Ok and typeof(Result) == "table" then
					Output(if typeof(Result.text) == "string" then Result.text else "")
				end
			end

			task.wait(1)
		end
	end)

	const function Elapsed(): string?
		const Task = Value()

		if Task.status == "running" then
			return Format.Clock(math.max(0, Now() - math.floor(Task.startedAt / 1000)))
		end

		return if Task.endedAt then Format.Clock(math.max(0, math.floor((Task.endedAt - Task.startedAt) / 1000))) else nil
	end

	return Create "Frame" {
		Name = "Task",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = function()
			return if Hovered() and Expandable() then 0 else 0.3
		end,
		Vide.action(Covers.Hover(Hovered)),

		Create "UICorner" {CornerRadius = UDim.new(0, 8)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 5),
		},
		Create "Frame" {
			Name = "Top",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Create "TextButton" {
				Name = "Title",
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = 1,
				Activated = function()
					if Expandable() then
						Expanded(not Expanded())
					end
				end,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 3),
				},
				Create "TextLabel" {
					Name = "Description",
					Size = UDim2.fromScale(0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = function()
						return if Running() then Theme.Colors.Text() else Theme.Colors.DimText()
					end,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					Text = function()
						return Value().description
					end,

					Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Shrink},
				},
				Icon {
					Name = Config.Icons.Right,
					Size = Settings.SmallText,
					LayoutOrder = 2,
					Rotation = function()
						return if Expanded() then 90 else 0
					end,
					Visible = function()
						return Expandable() and (Hovered() or Expanded())
					end,
				},
			},
			IconButton {
				Icon = Config.Icons.Stop,
				LayoutOrder = 2,
				Size = Settings.SmallText,
				Tooltip = "Stop this task",
				Visible = Running,
				OnClick = function()
					const Id = Chat.ConversationId()

					if Id then
						task.spawn(function()
							Client.StopTask(Id, Value().id)
							Chat.RefreshTasks()
						end)
					end
				end,
			},
		},
		Create "Frame" {
			Name = "Meta",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
				Padding = UDim.new(0, 8),
			},
			Label(function()
				return Kinds[Value().kind] or Value().kind
			end, 1, function()
				return if Running() then Theme.Colors.Text() else Theme.Colors.DimText()
			end),
			Create "TextLabel" {
				Name = "Status",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = function()
					return if Value().status == "failed" then Theme.Colors.Error() else Theme.Colors.DimText()
				end,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				LayoutOrder = 2,
				Visible = function()
					return not Running()
				end,
				Text = function()
					return Statuses[Value().status] or Format.Capitalize(Value().status)
				end,
			},
			Create "TextLabel" {
				Name = "Time",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				LayoutOrder = 3,
				Visible = function()
					return Elapsed() ~= nil
				end,
				Text = function()
					return Elapsed() or ""
				end,
			},
			Create "TextButton" {
				Name = "Transcript",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 4,
				Text = "View transcript",
				Visible = function()
					return IsAgent(Value()) and Value().toolUseId ~= nil
				end,
				Activated = function()
					const Task = Value()

					Chat.TasksOpen(false)
					Chat.ViewSubagent({
						id = Task.id,
						description = Task.description,
						kind = Task.kind,
						status = Task.status,
						background = true,
						depth = 1,
						toolUseId = Task.toolUseId,
					} :: Types.Task)
				end,
			},
		},
		Create "Frame" {
			Name = "Body",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Visible = function()
				return Expanded() and Expandable()
			end,

			Create "UIPadding" {PaddingTop = UDim.new(0, 4)},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 5),
			},
			Block(function()
				return Command(Value()) or ""
			end, 1, function()
				return IsBash(Value()) and Command(Value()) ~= nil
			end),
			Block(function()
				return Output() or ""
			end, 2, function()
				return IsBash(Value()) and (Output() or "") ~= ""
			end),
			Label(function()
				const Task = Value()

				if IsBash(Task) and (Output() or "") == "" then
					if Loading() then
						return "Loading output…"
					end

					if Task.status == "running" then
						return "No output yet"
					end
				end

				if HasSummary(Task) and not (IsBash(Task) and (Output() or "") ~= "") then
					return Task.summary :: string
				end

				return if IsBash(Task) and (Output() or "") == "" then "No output captured." else ""
			end, 3, Theme.Colors.DimText),
		},
	}
end

const function Section(Heading: string, Tasks: () -> {Types.BackgroundTask}, Collapsible: boolean, LayoutOrder: number): Frame
	const Open = Vide.source(not Collapsible)

	return Create "Frame" {
		Name = Heading,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = LayoutOrder,
		Visible = function()
			return #Tasks() > 0
		end,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 6),
		},
		Create "Frame" {
			Name = "Heading",
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "TextButton" {
				Name = "Toggle",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Active = Collapsible,
				Activated = function()
					if Collapsible then
						Open(not Open())
					end
				end,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				},
				Label(Heading, 1),
				Label(function()
					return if Collapsible then tostring(#Tasks()) else ""
				end, 2),
				Icon {
					Name = Config.Icons.Right,
					Size = Settings.SmallText,
					LayoutOrder = 3,
					Visible = function()
						return Collapsible
					end,
					Rotation = function()
						return if Open() then 90 else 0
					end,
				},
			},
			if Collapsible then Create "Frame" {
				Name = "Actions",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				IconButton {
					Icon = "trash-can",
					Size = Settings.SmallText,
					Tooltip = "Clear finished tasks",
					OnClick = function()
						const Id = Chat.ConversationId()

						if Id then
							task.spawn(function()
								Client.ClearTasks(Id)
								Chat.RefreshTasks()
							end)
						end
					end,
				},
			} else nil,
		},
		Create "Frame" {
			Name = "Rows",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Visible = Open,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 4),
			},
			Vide.values(Tasks, function(Task: Types.BackgroundTask, Index: () -> number)
				const Current = Vide.derive(function(): Types.BackgroundTask
					for _, Latest in Chat.BackgroundTasks() do
						if Latest.id == Task.id then
							return Latest
						end
					end

					return Task
				end)
				const Made = Row(Current)

				Vide.effect(function()
					Made.LayoutOrder = Index()
				end)

				return Made
			end),
		},
	}
end

return function()
	task.spawn(Chat.RefreshTasks)

	const Running = Vide.derive(function(): {Types.BackgroundTask}
		const Found = {}

		for _, Task in Chat.BackgroundTasks() do
			if Task.status == "running" or Task.status == "pending" then
				table.insert(Found, Task)
			end
		end

		table.sort(Found, function(Left, Right)
			return Left.startedAt < Right.startedAt
		end)

		return Found
	end)

	const Finished = Vide.derive(function(): {Types.BackgroundTask}
		const Found = {}

		for _, Task in Chat.BackgroundTasks() do
			if Task.status ~= "running" and Task.status ~= "pending" then
				table.insert(Found, Task)
			end
		end

		table.sort(Found, function(Left, Right)
			return (Left.endedAt or 0) > (Right.endedAt or 0)
		end)

		return Found
	end)

	return Create "Frame" {
		Name = "TasksPanel",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		LayoutOrder = 2,

		Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Create "Frame" {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 8),
			},
			Create "TextLabel" {
				Name = "Title",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Background tasks",
			},
			Create "Frame" {
				Name = "Close",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				IconButton {
					Icon = Config.Icons.Close,
					Size = Settings.SmallText,
					Tooltip = "Close",
					OnClick = function()
						Chat.TasksOpen(false)
					end,
				},
			},
		},
		Create "ScrollingFrame" {
			Name = "List",
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromScale(0, 0),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.Border,
			LayoutOrder = 2,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 16),
			},
			Create "TextLabel" {
				Name = "Empty",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				Text = "Background tasks appear here",
				Visible = function()
					return #Chat.BackgroundTasks() == 0
				end,
			},
			Section("Running", Running, false, 1),
			Section("Finished", Finished, true, 2),
		},
	}
end
