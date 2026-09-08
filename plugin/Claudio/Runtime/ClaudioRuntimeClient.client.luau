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

const function Typed(Body: string): any
	const UserInputService = game:GetService("UserInputService")
	const Virtual = (UserInputService :: any):CreateVirtualInput()
	const Ok, Trouble = pcall(function()
		Virtual:SendTextInput(Body)
	end)

	if not Ok then
		return {error = `Studio refused the typing: {tostring(Trouble)}`}
	end

	return {text = `Typed {#Body} characters into whatever has focus. Check the place to confirm where they landed.`}
end

const function Pressed(Path: string): any
	const UserInputService = game:GetService("UserInputService")

	local Object: Instance? = game

	for Index, Step in string.split(Path, ".") do
		if Index == 1 and (Step == "game" or Step == "Game") then
			continue
		end

		if not Object then
			return {error = `Nothing at "{Path}".`}
		end

		Object = (Object :: Instance):FindFirstChild(Step)
	end

	if not Object or not Object:IsA("GuiObject") then
		return {error = `Nothing usable at "{Path}". Give the full path to a GuiObject, such as Players.Someone.PlayerGui.Menu.Play.`}
	end

	const Target = Object :: GuiObject

	if Target.AbsoluteSize.X < 1 or Target.AbsoluteSize.Y < 1 then
		return {error = `{Target.Name} has no size on screen, so a press would land on whatever is behind it.`}
	end

	local Ancestor: Instance? = Target

	while Ancestor and Ancestor ~= game do
		if Ancestor:IsA("GuiObject") and not (Ancestor :: GuiObject).Visible then
			return {error = `{Target.Name} is not being drawn because {Ancestor.Name} is hidden, so a press would do nothing.`}
		end

		Ancestor = Ancestor.Parent
	end

	const Centre = Target.AbsolutePosition + Target.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
	const Virtual = (UserInputService :: any):CreateVirtualInput()
	const Sent, Trouble = pcall(function()
		Virtual:SendMouseButton(Centre, Enum.UserInputType.MouseButton1, true)
		task.wait(0.05)
		Virtual:SendMouseButton(Centre, Enum.UserInputType.MouseButton1, false)
	end)

	if not Sent then
		return {error = `The press was refused at {math.floor(Centre.X)}, {math.floor(Centre.Y)}: {tostring(Trouble)}`}
	end

	return {text = `Pressed {Target.Name} at {math.floor(Centre.X)}, {math.floor(Centre.Y)}. Check the place to confirm what it did, because a press that lands on nothing still reports as sent.`}
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
		if Kind == "press" then
			return Pressed(Body)
		end

		if Kind == "type" then
			return Typed(Body)
		end

		return Run(Body)
	end)

	Remote:FireServer(Id, if Ok then Result else {error = tostring(Result)})
end)