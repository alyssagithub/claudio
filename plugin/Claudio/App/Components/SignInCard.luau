--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Config = require(script.Parent.Parent.Parent.Config)
const Client = require(script.Parent.Parent.Parent.Client.Client)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

return function(Retry: () -> (), LayoutOrder: number)
	const State = Vide.source("idle")

	const function Begin()
		if State() == "waiting" then
			return
		end

		State("waiting")

		task.spawn(function()
			local Ok, Answer = Client.SignIn(true)

			while Ok and typeof(Answer) == "table" and Answer.state == "waiting" and task.wait(2) do
				Ok, Answer = Client.SignIn(false)
			end

			if Ok and typeof(Answer) == "table" and Answer.state == "signed in" then
				State("signed in")
				Retry()

				return
			end

			State("failed")
		end)
	end

	return Create "Frame" {
		Name = "SignInCard",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,
		LayoutOrder = LayoutOrder,

		Create "UICorner" {CornerRadius = UDim.new(0, 8)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Create "Frame" {
			Name = "Heading",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			LayoutOrder = 1,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			},
			Icon {
				Name = Config.Icons.Warning,
				Size = Settings.TextSize,
				Colour = Theme.Colors.Error,
				LayoutOrder = 1,
			},
			Create "TextLabel" {
				Name = "Title",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 2,
				Text = "Authentication failed",
			},
		},
		Create "Frame" {
			Name = "Body",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 10),
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
				LayoutOrder = 1,
				Text = function()
					const Now = State()

					if Now == "waiting" then
						return "Finish signing in in the window that opened. Claudio continues once you're done."
					end

					if Now == "failed" then
						return "Signing in didn't finish. Try again."
					end

					return if Now == "signed in" then "Signed in. Continuing." else "Sign in again to continue."
				end,
			},
			Create "Frame" {
				Name = "Actions",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Visible = function()
					return State() ~= "signed in"
				end,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
				},
				Create "TextButton" {
					Name = "SignIn",
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundColor3 = Color3.new(1, 1, 1),
					TextColor3 = Color3.new(0, 0, 0),
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					AutoButtonColor = true,
					Text = function()
						return if State() == "waiting" then "Waiting" else "Sign in again"
					end,
					Activated = Begin,

					Create "UICorner" {CornerRadius = UDim.new(0, 4)},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
						PaddingTop = UDim.new(0, 3),
						PaddingBottom = UDim.new(0, 3),
					},
				},
			},
		},
	}
end
