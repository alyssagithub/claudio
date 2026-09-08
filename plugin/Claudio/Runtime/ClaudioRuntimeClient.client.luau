--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")
const LogService = game:GetService("LogService")

local Remote = ReplicatedStorage:FindFirstChild("ClaudioRuntime")

const Deadline = os.clock() + 120

while (not Remote or not Remote:IsA("RemoteEvent")) and os.clock() < Deadline do
	task.wait(0.5)

	Remote = ReplicatedStorage:FindFirstChild("ClaudioRuntime")
end

if not Remote or not Remote:IsA("RemoteEvent") then
	return
end

const function Builder(): BindableFunction?
	const Found = ReplicatedStorage:FindFirstChild("ClaudioBuild")

	return if Found and Found:IsA("BindableFunction") then Found :: BindableFunction else nil
end

const function Placed(Message: string): string
	return (Message:gsub("[%w_%.]*ClaudioPayload:(%d+):?%s*", function(Digits: string): string
		return `line {math.max(1, (tonumber(Digits) or 2) - 1)}: `
	end))
end

const function Explain(Trouble: string, Said: {string}): string
	if not Trouble:find("experienced an error while loading", 1, true) then
		return Placed(Trouble)
	end

	task.wait(0.05)

	for Index = #Said, 1, -1 do
		const Line, Rest = Said[Index]:match("ClaudioPayload:(%d+): (.+)$")

		if Line then
			return `Line {math.max(1, (tonumber(Line) or 2) - 1)}: {Rest}`
		end
	end

	return Trouble
end

const function Find(Path: string): (GuiObject?, string?)
	local Object: Instance? = game

	for Index, Step in string.split(Path, ".") do
		if Index == 1 and (Step == "game" or Step == "Game") then
			continue
		end

		if not Object then
			return nil, `Nothing at "{Path}".`
		end

		Object = (Object :: Instance):FindFirstChild(Step)
	end

	if not Object or not Object:IsA("GuiObject") then
		return nil, `Nothing usable at "{Path}". Give the full path to a GuiObject, such as Players.Someone.PlayerGui.Menu.Play.`
	end

	const Target = Object :: GuiObject

	if Target.AbsoluteSize.X < 1 or Target.AbsoluteSize.Y < 1 then
		return nil, `{Target.Name} has no size on screen, so input would land on whatever is behind it.`
	end

	local Ancestor: Instance? = Target

	while Ancestor and Ancestor ~= game do
		if Ancestor:IsA("GuiObject") and not (Ancestor :: GuiObject).Visible then
			return nil, `{Target.Name} is not being drawn because {Ancestor.Name} is hidden, so input would do nothing.`
		end

		Ancestor = Ancestor.Parent
	end

	return Target, nil
end

const function Centre(Target: GuiObject): Vector2
	return Target.AbsolutePosition + Target.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
end

const function Where(Target: GuiObject): string
	const Point = Centre(Target)

	return `{math.floor(Point.X)}, {math.floor(Point.Y)}`
end

const function Interact(Body: string): any
	const Read, Input = pcall(function(): any
		return HttpService:JSONDecode(Body)
	end)

	if not Read or typeof(Input) ~= "table" then
		return {error = "Claudio could not read what input to send."}
	end

	const Action = tostring(Input.action)
	const Virtual = ((game:GetService("UserInputService")) :: any):CreateVirtualInput()

	if Action == "type" then
		if typeof(Input.text) ~= "string" or Input.text == "" then
			return {error = "Typing needs text."}
		end

		const Ok, Trouble = pcall(function()
			Virtual:SendTextInput(Input.text)
		end)

		if not Ok then
			return {error = `Studio refused the typing: {tostring(Trouble)}`}
		end

		return {text = `Typed {#Input.text} characters into whatever has focus. Check the place to confirm where they landed.`}
	end

	if Action == "key" then
		if typeof(Input.key) ~= "string" then
			return {error = "A key press needs the name of a KeyCode, such as Return or E."}
		end

		const Named, Code = pcall(function(): any
			return (Enum.KeyCode :: any)[Input.key]
		end)

		if not Named or not Code then
			return {error = `"{Input.key}" is not a KeyCode. Use the name Roblox gives it, such as Return, Escape, E or LeftShift.`}
		end

		const Ok, Trouble = pcall(function()
			Virtual:SendKey(true, Code, false)
			task.wait(0.05)
			Virtual:SendKey(false, Code, false)
		end)

		if not Ok then
			return {error = `Studio refused the key {Input.key}: {tostring(Trouble)}`}
		end

		return {text = `Pressed and released {Input.key}. Check the place to confirm what it did.`}
	end

	if typeof(Input.path) ~= "string" then
		return {error = `{Action} needs a path to the GuiObject to act on.`}
	end

	const Target, Trouble = Find(Input.path)

	if not Target then
		return {error = Trouble}
	end

	const Point = Centre(Target)

	if Action == "press" then
		const Sent, Refused = pcall(function()
			Virtual:SendMouseButton(Point, Enum.UserInputType.MouseButton1, true, 0)
			task.wait(0.05)
			Virtual:SendMouseButton(Point, Enum.UserInputType.MouseButton1, false, 0)
		end)

		if not Sent then
			return {error = `The press was refused at {Where(Target)}: {tostring(Refused)}`}
		end

		return {text = `Pressed {Target.Name} at {Where(Target)}. Check the place to confirm what it did, because a press that lands on nothing still reports as sent.`}
	end

	if Action == "hover" then
		const Sent, Refused = pcall(function()
			Virtual:SendMousePosition(Point)
		end)

		if not Sent then
			return {error = `The pointer could not be moved to {Where(Target)}: {tostring(Refused)}`}
		end

		return {text = `Moved the pointer onto {Target.Name} at {Where(Target)}.`}
	end

	if Action == "scroll" then
		const Amount = tonumber(Input.amount) or -1
		const Sent, Refused = pcall(function()
			Virtual:SendMousePosition(Point)
			Virtual:SendPointerAction(Point, {Wheel = Amount, Pan = Vector2.zero, Pinch = 0})
		end)

		if not Sent then
			return {error = `Scrolling over {Target.Name} was refused: {tostring(Refused)}`}
		end

		return {text = `Scrolled {if Amount < 0 then "down" else "up"} over {Target.Name}. Read the canvas position back to see how far it moved.`}
	end

	if Action ~= "drag" then
		return {error = `Claudio does not know the input action "{Action}".`}
	end

	local Finish = Point

	if typeof(Input.to) == "string" then
		const Second, Missing = Find(Input.to)

		if not Second then
			return {error = Missing}
		end

		Finish = Centre(Second)
	elseif tonumber(Input.x) or tonumber(Input.y) then
		Finish = Point + Vector2.new(tonumber(Input.x) or 0, tonumber(Input.y) or 0)
	else
		return {error = "A drag needs somewhere to go: give to for another GuiObject, or x and y to move by."}
	end

	const Sent, Refused = pcall(function()
		Virtual:SendMousePosition(Point)
		Virtual:SendMouseButton(Point, Enum.UserInputType.MouseButton1, true, 0)

		for Step = 1, 10 do
			Virtual:SendMousePosition(Point:Lerp(Finish, Step / 10))
			task.wait(0.02)
		end

		Virtual:SendMouseButton(Finish, Enum.UserInputType.MouseButton1, false, 0)
	end)

	if not Sent then
		return {error = `The drag from {Where(Target)} was refused: {tostring(Refused)}`}
	end

	return {text = `Dragged {Target.Name} from {math.floor(Point.X)}, {math.floor(Point.Y)} to {math.floor(Finish.X)}, {math.floor(Finish.Y)}.`}
end

const function Run(Code: string): any
	const Said = {}
	const Listening = LogService.MessageOut:Connect(function(Message: string, Kind: Enum.MessageType)
		if #Said < 200 and Kind ~= Enum.MessageType.MessageInfo then
			table.insert(Said, Message)
		end
	end)

	const function Finish(Answer: {[string]: any}): any
		task.wait(0.1)
		Listening:Disconnect()

		if #Said > 0 then
			Answer.output = Said
		end

		return Answer
	end

	const Making = Builder()

	if not Making then
		return Finish({error = "Claudio's plugin is not running inside this play session, so there is nothing to build the code with. Stop the playtest and start it again, and if that does not help, reinstall the plugin."})
	end

	const Payload = Making:Invoke(`return function()\n{Code}\nend`)

	if not Payload then
		return Finish({error = "Claudio could not turn that code into a module to run it."})
	end

	const Built, Body = pcall(require, Payload)

	Payload:Destroy()

	if not Built then
		return Finish({error = Explain(tostring(Body), Said)})
	end

	const Ok, Result = pcall(Body)

	if not Ok then
		return Finish({error = Placed(tostring(Result))})
	end

	const Answer: {[string]: any} = {}

	if Result ~= nil then
		if typeof(Result) == "table" then
			const Encoded, Text = pcall(HttpService.JSONEncode, HttpService, Result)

			Answer.result = if Encoded then Text else tostring(Result)
		else
			Answer.result = tostring(Result)
		end
	end

	return Finish(Answer)
end

Remote.OnClientEvent:Connect(function(Id: string, Kind: string, Body: string)
	const Ok, Result = pcall(function(): any
		if Kind == "input" then
			return Interact(Body)
		end

		return Run(Body)
	end)

	Remote:FireServer(Id, if Ok then Result else {error = tostring(Result)})
end)