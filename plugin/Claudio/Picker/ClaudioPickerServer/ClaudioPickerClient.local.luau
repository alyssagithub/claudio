--!strict
const GuiService = game:GetService("GuiService")
const RunService = game:GetService("RunService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const Player = Players.LocalPlayer
const Screen = Player:WaitForChild("PlayerGui")
const Link = ReplicatedStorage:WaitForChild("ClaudioPicker") :: RemoteEvent

const Accent = Color3.fromRGB(90, 160, 255)
const Idle = Color3.fromRGB(32, 32, 34)
const Warm = Color3.fromRGB(58, 58, 62)

script.Overlay.Enabled = false

local Mode: string?
local Hovered: string?
local Shown = 0
local Message: TextLabel
local Overlay: ScreenGui?
local Marker: Instance?
local Toolbar: ScreenGui

const function Clear()
	if Marker then
		Marker:Destroy()
		Marker = nil
	end
end

const function Describe(Object: Instance): string
	const Lines = {`{Object:GetFullName()} ({Object.ClassName})`}

	if Object:IsA("GuiObject") then
		table.insert(Lines, `Size {Object.Size}, Position {Object.Position}, AnchorPoint {Object.AnchorPoint}, ZIndex {Object.ZIndex}, Visible {Object.Visible}`)
		table.insert(Lines, `On screen it covers {Object.AbsoluteSize} pixels at {Object.AbsolutePosition}`)
	end

	if Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
		table.insert(Lines, `Text "{Object.Text}", TextSize {Object.TextSize}, colour {Object.TextColor3}`)
	end

	if Object:IsA("BasePart") then
		table.insert(Lines, `Size {Object.Size}, CFrame {Object.CFrame}, Material {Object.Material.Name}, Colour {Object.Color}, Anchored {Object.Anchored}`)
	end

	const Children = {}

	for _, Child in Object:GetChildren() do
		table.insert(Children, `{Child.Name} ({Child.ClassName})`)

		if #Children == 12 then
			break
		end
	end

	if #Children > 0 then
		table.insert(Lines, `Children: {table.concat(Children, ", ")}`)
	end

	return table.concat(Lines, "\n")
end

const function Highlight(Object: Instance?)
	Clear()

	if not Object or not Overlay then
		return
	end

	if Object:IsA("BasePart") or Object:IsA("Model") then
		const Glow = script.Glow:Clone()

		Glow.Adornee = Object
		Glow.Parent = Overlay
		Marker = Glow

		return
	end

	if not Object:IsA("GuiObject") then
		return
	end

	const Box = script.Box:Clone()

	Box.Position = UDim2.fromOffset(Object.AbsolutePosition.X, Object.AbsolutePosition.Y)
	Box.Size = UDim2.fromOffset(Object.AbsoluteSize.X, Object.AbsoluteSize.Y)
	Box.Parent = Overlay
	Marker = Box
end

const function Target(X: number, Y: number): Instance?
	const Gui = Player:FindFirstChildOfClass("PlayerGui")

	if Mode == "ui" and Gui then
		for _, Object in (Gui :: PlayerGui):GetGuiObjectsAtPosition(X, Y - GuiService:GetGuiInset().Y) do
			if Object.Visible and Overlay and not Object:IsDescendantOf(Overlay) and not Object:IsDescendantOf(Toolbar) then
				return Object
			end
		end

		return nil
	end

	const Camera = workspace.CurrentCamera

	if not Camera then
		return nil
	end

	const Ray = Camera:ViewportPointToRay(X, Y)
	const Hit = workspace:Raycast(Ray.Origin, Ray.Direction * 2000)

	if not Hit then
		return nil
	end

	const Model = Hit.Instance:FindFirstAncestorOfClass("Model")

	return if Model and Model ~= Player.Character then Model else Hit.Instance
end

Toolbar = script.Toolbar:Clone()

Toolbar.Name = "ClaudioPickerBar"
Toolbar.Parent = Screen

const Panel = Toolbar.Panel
const Row = Panel.Row

const Buttons: {[string]: TextButton} = {}

const function Paint()
	for Name, Button in Buttons do
		const On = Mode == Name

		Button.BackgroundColor3 = if On then Accent elseif Hovered == Name then Warm else Idle
		Button.TextColor3 = if On then Color3.new(1, 1, 1) elseif Hovered == Name then Color3.new(1, 1, 1) else Color3.fromRGB(190, 190, 195)
		Button.Text = if On then `● {Name:upper()}` else Name:upper()
	end
end

const function Announce(Ok: boolean, Text: string)
	Message.Text = if Ok then `  Sent {Text} to Claudio  ` else `  Could not send that. {Text}  `
	Message.BackgroundColor3 = if Ok then Color3.fromRGB(40, 110, 60) else Color3.fromRGB(130, 45, 45)
	Message.Visible = true
	Shown += 1

	const Token = Shown

	task.delay(3, function()
		if Shown == Token then
			Message.Visible = false
		end
	end)
end

const function Stop()
	Mode = nil
	script.PickerInput.Enabled = false
	Clear()

	if Overlay then
		Overlay:Destroy()
		Overlay = nil
	end

	Paint()
end

const function Start(Wanted: string)
	Clear()

	if Overlay then
		Overlay:Destroy()
	end

	Mode = Wanted
	script.PickerInput.Enabled = true

	const Sheet = script.Overlay:Clone()

	Sheet.Name = "ClaudioPickerOverlay"
	Sheet.DisplayOrder = 2147483646
	Sheet.Enabled = true
	Sheet.Parent = Screen
	Overlay = Sheet

	Sheet.Catcher:Destroy()

	Sheet.Hint.Text = if Wanted == "ui" then "  Click a UI element to send it to Claudio, X to cancel  " else "  Click a part to send it to Claudio, X to cancel  "

	Paint()
end

const function OverToolbar(): boolean
	const Where = UserInputService:GetMouseLocation()
	const Corner = Panel.AbsolutePosition + Vector2.new(0, GuiService:GetGuiInset().Y)
	const Span = Panel.AbsoluteSize

	return Where.X >= Corner.X and Where.X <= Corner.X + Span.X and Where.Y >= Corner.Y and Where.Y <= Corner.Y + Span.Y
end

RunService.RenderStepped:Connect(function()
	if not Mode then
		return
	end

	if OverToolbar() then
		Clear()

		return
	end

	const Where = UserInputService:GetMouseLocation()

	Highlight(Target(Where.X, Where.Y))
end)

script.PickerInput.Pick.Pressed:Connect(function()
	if not Mode or OverToolbar() then
		return
	end

	const Where = UserInputService:GetMouseLocation()
	const Object = Target(Where.X, Where.Y)

	if not Object then
		Announce(false, "Nothing under the cursor")

		return
	end

	Link:FireServer(Object.Name, Describe(Object))
	Clear()
end)

const function Toggle(Name: string)
	if Mode == Name then
		Stop()

		return
	end

	Start(Name)
end

for Index, Name in {
	"parts",
	"ui",
} do
	const Button = script.Button:Clone()

	Button.Name = Name
	Button.LayoutOrder = Index + 1
	Button.Parent = Row

	Button.MouseEnter:Connect(function()
		Hovered = Name
		Paint()
	end)

	Button.MouseLeave:Connect(function()
		if Hovered == Name then
			Hovered = nil
		end

		Paint()
	end)

	Button.Activated:Connect(function()
		Toggle(Name)
	end)

	Buttons[Name] = Button
end

Message = Row.Message

script.Destroying:Connect(function()
	if Overlay then
		Overlay:Destroy()
	end

	Toolbar:Destroy()
end)

Link.OnClientEvent:Connect(function(Ok: boolean, Text: string)
	Announce(Ok, Text)
end)

script.PickerInput.Cancel.Pressed:Connect(function()
	if not Mode then
		return
	end

	Stop()
end)

Paint()