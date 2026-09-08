--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const HttpService = game:GetService("HttpService")
const LogService = game:GetService("LogService")

local Remote = ReplicatedStorage:FindFirstChild("ClaudioRuntime")

while not Remote or not Remote:IsA("RemoteEvent") do
	task.wait(0.5)

	Remote = ReplicatedStorage:FindFirstChild("ClaudioRuntime")
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

	if typeof(loadstring) ~= "function" then
		return Finish({error = "Running code here needs loadstring, which this session does not have."})
	end

	const Made, Trouble = loadstring(`return function()\n{Code}\nend`)

	if not Made then
		return Finish({error = `That did not compile: {tostring(Trouble)}`})
	end

	const Built, Body = pcall(Made)

	if not Built then
		return Finish({error = tostring(Body)})
	end

	const Ok, Result = pcall(Body)

	if not Ok then
		return Finish({error = tostring(Result)})
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

		return Run(Body)
	end)

	Remote:FireServer(Id, if Ok then Result else {error = tostring(Result)})
end)
