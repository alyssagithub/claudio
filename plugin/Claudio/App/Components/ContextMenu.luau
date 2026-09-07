--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

const function Chosen(): Types.ConversationSummary?
	const Id = Chat.MenuFor()

	if not Id then
		return nil
	end

	for _, Summary in Chat.Conversations() do
		if Summary.id == Id then
			return Summary
		end
	end

	return nil
end

const function Toggle(Flag: "starred" | "archived")
	const Summary = Chosen()

	if not Summary then
		return
	end

	task.spawn(Chat.SetFlag, Summary.id, Flag, not (if Flag == "starred" then Summary.starred else Summary.archived))
end

const function Rename()
	const Summary = Chosen()

	if not Summary then
		return
	end

	Chat.MenuFor(nil)
	Chat.Renaming(Summary.id)
end

const function Fork()
	const Summary = Chosen()

	if not Summary then
		return
	end

	task.spawn(Chat.Fork, Summary.id)
end

const function Delete()
	const Summary = Chosen()

	if not Summary then
		return
	end

	Chat.MenuFor(nil)
	Chat.Confirming(Summary.id)
end

const function Item(Label: () -> string, LayoutOrder: number, Danger: boolean, OnClick: () -> ())
	const Hovered = Vide.source(false)

	return Create "TextButton" {
		Name = "Item",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() then 0 else 1
		end,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = LayoutOrder,
		Activated = OnClick,
		MouseEnter = function()
			Hovered(true)
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
		Create "TextLabel" {
			Name = "Label",
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = function()
				return if Danger then Theme.Colors.Error() else Theme.Colors.Text()
			end,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Label,
		},
	}
end

return function()
	return Create "Frame" {
		Name = "ContextMenu",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 100,
		Visible = function()
			return Chosen() ~= nil
		end,

		Create "TextButton" {
			Name = "Catcher",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 100,
			Activated = function()
				Chat.MenuFor(nil)
			end,

			Vide.action(function(Object: TextButton)
				Vide.cleanup(Object.MouseButton2Click:Connect(function()
					Chat.MenuFor(nil)
				end))
			end),
		},
		Create "Frame" {
			Name = "Menu",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromOffset(160, 0),
			BackgroundColor3 = Theme.Colors.Background,
			ZIndex = 101,
			Position = function()
				return UDim2.fromOffset(Chat.MenuPosition().X, Chat.MenuPosition().Y)
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},
			Item(function()
				const Summary = Chosen()

				return if Summary and Summary.starred then "Unpin" else "Pin"
			end, 1, false, function()
				Toggle("starred")
			end),
			Item(function()
				return "Rename"
			end, 2, false, Rename),
			Item(function()
				return "Fork"
			end, 3, false, Fork),
			Create "Frame" {
				Name = "Divider",
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.Colors.Border,
				BorderSizePixel = 0,
				LayoutOrder = 4,

				Create "UIPadding" {
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
				},
			},
			Item(function()
				const Summary = Chosen()

				return if Summary and Summary.archived then "Unarchive" else "Archive"
			end, 5, false, function()
				Toggle("archived")
			end),
			Item(function()
				return "Delete"
			end, 6, true, Delete),
		},
	}
end