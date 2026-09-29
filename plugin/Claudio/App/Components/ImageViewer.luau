--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Config = require(script.Parent.Parent.Parent.Config)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Covers = require(script.Parent.Parent.Covers)
const Theme = require(script.Parent.Parent.Theme)
const Button = require(script.Parent.Button)
const IconButton = require(script.Parent.IconButton)

const Create = Vide.create

return function()
	const Scale = Vide.source(1)
	const Pan = Vide.source(Vector2.zero)
	const Room = Vide.source(Vector2.one)
	const Crisp = Vide.source(true)
	local Dragging: Vector2?
	local Stage: Frame

	const function Natural(): Vector2
		const Image = Chat.Zoomed()

		return if Image then Image.Size else Vector2.one
	end

	const function Fit()
		const Size = Natural()

		Scale(math.min(Room().X / Size.X, Room().Y / Size.Y, 1) * 0.96)
		Pan(Vector2.zero)
	end

	const function ZoomTo(Wanted: number, Around: Vector2?)
		const Before = Scale()
		const After = math.clamp(Wanted, 0.1, 64)
		const Point = Around or Room() / 2
		const FromCentre = Point - Room() / 2

		Pan(FromCentre - (FromCentre - Pan()) * (After / Before))
		Scale(After)
	end

	Vide.effect(function()
		if Chat.Zoomed() then
			Vide.untrack(Fit)
		end
	end)

	return Create "Frame" {
		Name = "ImageViewer",
		Vide.action(Covers.Add),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 24, 26),
		BackgroundTransparency = 0,
		ZIndex = 300,
		Visible = function()
			return Chat.Zoomed() ~= nil
		end,

		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Create "Frame" {
			Name = "Stage",
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 1,
			ZIndex = 301,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			Vide.action(function(Object: Frame)
				Stage = Object
				Room(Object.AbsoluteSize)
				Vide.cleanup(Object:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					Room(Object.AbsoluteSize)
				end))
				Vide.cleanup(Object.InputBegan:Connect(function(Input: InputObject)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Dragging = Vector2.new(Input.Position.X, Input.Position.Y)
					end
				end))
				Vide.cleanup(Object.InputEnded:Connect(function(Input: InputObject)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Dragging = nil
					end
				end))
				Vide.cleanup(Object.InputChanged:Connect(function(Input: InputObject)
					const Point = Vector2.new(Input.Position.X, Input.Position.Y)

					if Input.UserInputType == Enum.UserInputType.MouseWheel then
						ZoomTo(Scale() * (if Input.Position.Z > 0 then 1.25 else 0.8), Point - Stage.AbsolutePosition)
					elseif Input.UserInputType == Enum.UserInputType.MouseMovement and Dragging then
						Pan(Pan() + Point - Dragging)
						Dragging = Point
					end
				end))
			end),
			Create "ImageLabel" {
				Name = "Big",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = function()
					return UDim2.new(0.5, Pan().X, 0.5, Pan().Y)
				end,
				Size = function()
					return UDim2.fromOffset(Natural().X * Scale(), Natural().Y * Scale())
				end,
				BackgroundTransparency = 1,
				ResampleMode = function()
					return if Crisp() and Scale() > 1 then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default
				end,
				ZIndex = 302,
				ImageContent = function()
					const Image = Chat.Zoomed()

					return if Image then Content.fromObject(Image) else Content.none
				end,
			},
		},
		Create "Frame" {
			Name = "Tools",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Background,
			LayoutOrder = 2,
			ZIndex = 303,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},
			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
				Padding = UDim.new(0, 6),
			},
			IconButton {
				Icon = Config.Icons.Close,
				LayoutOrder = 1,
				Tooltip = "Close",
				OnClick = function()
					Chat.Zoomed(nil)
				end,
			},
			Button {
				Text = "Zoom out",
				LayoutOrder = 2,
				OnClick = function()
					ZoomTo(Scale() * 0.5)
				end,
			},
			Create "TextLabel" {
				Name = "Amount",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 3,
				Text = function()
					return `{math.floor(Scale() * 100 + 0.5)}%`
				end,
			},
			Button {
				Text = "Zoom in",
				LayoutOrder = 4,
				OnClick = function()
					ZoomTo(Scale() * 2)
				end,
			},
			Button {
				Text = "Fit",
				LayoutOrder = 5,
				OnClick = Fit,
			},
			Button {
				Text = "1:1",
				LayoutOrder = 6,
				OnClick = function()
					ZoomTo(1)
				end,
			},
			Button {
				Text = function()
					return if Crisp() then "Pixels: sharp" else "Pixels: smooth"
				end,
				LayoutOrder = 7,
				OnClick = function()
					Crisp(not Crisp())
				end,
			},
			Button {
				Text = "Open outside",
				LayoutOrder = 8,
				OnClick = function()
					const Image = Chat.Zoomed()

					if Image then
						task.spawn(Chat.OpenPicture, Image)
					end
				end,
			},
			Create "TextLabel" {
				Name = "Hint",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				LayoutOrder = 9,
				Text = function()
					return `{Natural().X} by {Natural().Y} pixels. Scroll to zoom and drag to move.`
				end,
			},
		},
	}
end
