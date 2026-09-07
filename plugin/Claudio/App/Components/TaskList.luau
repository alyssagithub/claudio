--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Parent.Config)
const Types = require(script.Parent.Parent.Parent.Types)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

const Marks = {
	running = "spinner",
	pending = "circle-dashed",
	completed = "check",
	failed = "x",
	killed = "x",
	paused = "minus",
}

const function Running(): {Types.Task}
	const Found = {}

	for _, Task in Chat.Tasks() do
		if Task.status ~= "completed" then
			table.insert(Found, Task)
		end
	end

	return Found
end

const function Row(Task: () -> Types.Task)
	return Create "Frame" {
		Name = "Task",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Create "UIPadding" {
			PaddingLeft = function()
				return UDim.new(0, (Task().depth - 1) * 12)
			end,
		},
		Create "TextLabel" {
			Name = "Mark",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = function()
				return if Task().status == "failed" or Task().status == "killed" then Theme.Colors.Error() else Theme.Colors.DimText()
			end,
			TextSize = Settings.SmallText,
			FontFace = Config.IconFont,
			LayoutOrder = 1,
			Text = function()
				return Marks[Task().status] or Marks.running
			end,
		},
		Create "TextLabel" {
			Name = "What",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = 2,
			Text = function()
				const Held = Task()

				return if Held.background then `{Held.description} (background)` else Held.description
			end,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		},
	}
end

return function()
	return Create "Frame" {
		Name = "TaskList",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 3,
		Visible = function()
			return #Running() > 0
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		},
		Create "TextLabel" {
			Name = "Heading",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Text = function()
				const Held = Running()
				local Busy = 0

				for _, Task in Held do
					if Task.status == "running" then
						Busy += 1
					end
				end

				if Busy == #Held then
					return if Busy == 1 then "1 task running" else `{Busy} tasks running`
				end

				return if #Held == 1 then "1 task" else `{#Held} tasks, {Busy} running`
			end,
		},
		Vide.indexes(function()
			return Running()
		end, function(Task: () -> Types.Task, Index: number)
			return Row(Task)
		end),
	}
end
