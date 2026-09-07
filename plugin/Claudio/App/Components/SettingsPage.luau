--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Types = require(script.Parent.Parent.Parent.Types)
const Chat = require(script.Parent.Parent.Parent.Store.Chat)
const Connection = require(script.Parent.Parent.Parent.Store.Connection)
const Toggle = require(script.Parent.Toggle)
const Button = require(script.Parent.Button)
const Config = require(script.Parent.Parent.Parent.Config)
const IconButton = require(script.Parent.IconButton)

const function PromptText(): string
	if not Settings.Get("ExtraPrompt")() then
		return "Turned off. Claude gets Claude Code's own instructions and nothing from Claudio."
	end

	const Health = Connection.Health()

	return if Health and Health.systemPrompt then Health.systemPrompt else "Connect to the bridge to see what gets sent."
end

const Create = Vide.create

const function Choice(Definition: Settings.Definition)
	const function Option(Name: string, LayoutOrder: number)
		const function Chosen(): boolean
			return Settings.Get(Definition.Key)() == Name
		end

		return Create "TextButton" {
			Name = Name,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			BackgroundColor3 = function()
				return if Chosen() then Theme.Colors.Accent() else Theme.Colors.Input()
			end,
			TextColor3 = function()
				return if Chosen() then Theme.Colors.AccentText() else Theme.Colors.DimText()
			end,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			AutoButtonColor = false,
			LayoutOrder = LayoutOrder,
			Text = Name,
			Activated = function()
				Settings.Set(Definition.Key, Name)
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			},
		}
	end

	return Create "Frame" {
		Name = "Choice",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		},
		Vide.indexes(function()
			return Definition.Options :: {string}
		end, function(Name: () -> string, Index: number)
			return Option(Name(), Index)
		end),
	}
end

const function Number(Definition: Settings.Definition)
	local Box: TextBox

	Box = Create "TextBox" {
		Name = "Number",
		Size = UDim2.fromOffset(64, 22),
		BackgroundColor3 = Theme.Colors.Input,
		TextColor3 = Theme.Colors.Text,
		TextSize = Settings.TextSize,
		FontFace = Font.fromEnum(Enum.Font.Code),
		ClearTextOnFocus = false,
		Text = function()
			return tostring(Settings.Get(Definition.Key)())
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		FocusLost = function()
			const Value = tonumber(Box.Text)

			if Value then
				Settings.Set(Definition.Key, math.clamp(math.round(Value), Definition.Minimum :: number, Definition.Maximum :: number))
			end

			Box.Text = tostring(Settings.Get(Definition.Key)())
		end,
	}

	return Box
end

const function Row(Definition: Settings.Definition, LayoutOrder: number)
	return Create "Frame" {
		Name = "Setting",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = LayoutOrder,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		},
		Create "Frame" {
			Name = "Labels",
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 1),
			},
			Create "TextLabel" {
				Name = "Label",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 1,
				Text = Definition.Label,
			},
			Create "TextLabel" {
				Name = "Detail",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = function()
					return Settings.SmallText()
				end,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 2,
				Visible = Definition.Detail ~= "",
				Text = Definition.Detail,
			},
		},
		if Definition.Options then Choice(Definition) elseif Definition.Minimum then Number(Definition) else Toggle(Definition.Key),
	}
end

const function Server(Entry: () -> Types.McpServer, Index: number)
	return Create "Frame" {
		Name = "Server",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 8000 + Index,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 2),
		},
		Create "Frame" {
			Name = "Heading",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			},
			Create "TextLabel" {
				Name = "Title",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Text = function()
					return Entry().name
				end,
			},
		},
		Create "TextLabel" {
			Name = "Command",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.Code),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Text = function()
				return `{Entry().command} {Entry().arguments}`
			end,
		},
	}
end

const function Heading(Text: string, LayoutOrder: number)
	return Create "TextLabel" {
		Name = "Heading",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.DimText,
		TextSize = function()
			return Settings.TextSize() - 1
		end,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = LayoutOrder,
		Text = Text,

		Create "UIPadding" {PaddingTop = UDim.new(0, 8)},
	}
end

const function Groups(): {string}
	const Found = {}

	for _, Definition in Settings.Definitions do
		if not table.find(Found, Definition.Group) then
			table.insert(Found, Definition.Group)
		end
	end

	return Found
end

return function()
	task.spawn(Chat.LoadMcpServers)

	const Open = Vide.source(Groups()[1])

	const function Tab(Name: string, LayoutOrder: number)
		const function Showing(): boolean
			return Open() == Name
		end

		return Create "TextButton" {
			Name = "Tab",
			BackgroundColor3 = function()
				return if Showing() then Theme.Colors.Accent() else Theme.Colors.Input()
			end,
			TextColor3 = function()
				return if Showing() then Theme.Colors.AccentText() else Theme.Colors.DimText()
			end,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			AutoButtonColor = false,
			LayoutOrder = LayoutOrder,
			Text = Name,
			Activated = function()
				Open(Name)
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		}
	end

	const Tabs: {TextButton} = {}
	const Children: {Frame} = {}
	local Order = 0

	for Index, Name in Groups() do
		table.insert(Tabs, (Tab(Name, Index)))
	end

	for _, Definition in Settings.Definitions do
		Order += 1

		table.insert(Children, (Create "Frame" {
			Name = "Holder",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 100 + Order,
			Visible = function()
				return Open() == Definition.Group
			end,

			Row(Definition, 1),
		}))
	end

	return Create "ScrollingFrame" {
		Name = "SettingsPage",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.Colors.Background,
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
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 10),
		},
		Create "UIListLayout" {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
		Create "Frame" {
			Name = "Actions",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 0,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			},
			Button {
				Text = "Reset to defaults",
				OnClick = Settings.Reset,
			},
		},
		Create "Frame" {
			Name = "Tabs",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,

			Create "UIGridLayout" {
				CellSize = function()
					return UDim2.new(0.5, -3, 0, Settings.TextSize() + 12)
				end,
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirectionMaxCells = 2,
			},
			Tabs,
		},
		Children,
		Create "Frame" {
			Name = "Bridge",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 7899,
			Visible = function()
				return Open() == "Connection"
			end,

			Create "UIListLayout" {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			},
			Heading("Claudio's own instructions", 7900),
			Create "TextBox" {
				Name = "Prompt",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Code,
				TextColor3 = Theme.Colors.CodeText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				MultiLine = true,
				TextEditable = false,
				ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = 7901,
				Text = PromptText,

				Create "UICorner" {CornerRadius = UDim.new(0, 6)},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 34),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				},
				Create "Frame" {
					Name = "CopyCorner",
					Position = UDim2.new(1, 4, 0, -2),
					Size = UDim2.fromScale(0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,

					IconButton {
						Icon = Config.Icons.Copy,
						Size = Settings.SmallText,
						Tooltip = "Copy the prompt",
						OnClick = function()
							task.spawn(Chat.Copy, PromptText())
						end,
					},
				},
			},
			Heading("Working folder", 7930),
			Create "TextLabel" {
				Name = "FolderNow",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 7931,
				Text = function()
					return `Claude runs in {Settings.Get("WorkingFolder")()}`
				end,
			},
			Button {
				Text = "Change folder",
				LayoutOrder = 7932,
				OnClick = function()
					Chat.SettingsOpen(false)
					Settings.Set("WorkingFolder", "")
				end,
			},
			Heading("Plugin version", 7950),
			Create "TextLabel" {
				Name = "VersionNote",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 7951,
				Text = function()
					const Found = Chat.Versions()

					if not Found then
						return "Connect to the bridge to see other versions."
					end

					if #Found.releases == 0 then
						return `You are on {Chat.Installed()}. No published releases were found.`
					end

					const Running = Chat.Installed()

					if Found.current ~= Running then
						return `{Found.current} is installed and loads when you restart Studio. You are running {Running} until then.`
					end

					if Found.bridge and Found.bridge ~= Running then
						return `The plugin is on {Running} and the bridge is on {Found.bridge}. They update separately, so run the installer again to bring the bridge along.`
					end

					return `You are on {Running}. Pick another and switch to install it. Studio has to restart for it to take effect.`
				end,
			},
			Create "Frame" {
				Name = "VersionPicker",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 7952,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				},
				Create "Frame" {
					Name = "Choice",
					Size = UDim2.fromScale(0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,

					Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
					Create "UIListLayout" {
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						Padding = UDim.new(0, 2),
					},
					Create "TextButton" {
						Name = "Selected",
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundColor3 = Theme.Colors.Input,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextXAlignment = Enum.TextXAlignment.Left,
						AutoButtonColor = false,
						LayoutOrder = 1,
						Text = function()
							const Picked = Chat.VersionPick()

							return `  {if Picked == "" then Chat.Installed() else Picked}{if Picked == "" or Picked == Chat.Installed() then "  · installed" else ""}`
						end,
						Activated = function()
							Chat.VersionOpen(not Chat.VersionOpen())
						end,

						Create "UICorner" {CornerRadius = UDim.new(0, 4)},
						Create "TextLabel" {
							Name = "Arrow",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.DimText,
							TextSize = Settings.SmallText,
							FontFace = Config.IconFont,
							Text = function()
								return if Chat.VersionOpen() then Config.Icons.Up else Config.Icons.Down
							end,
						},
					},
					Vide.indexes(function()
						const Found = Chat.Versions()

						return if Found and Chat.VersionOpen() then Found.releases else {}
					end, function(Release: () -> Types.Release, Index: number)
						return Create "TextButton" {
							Name = "Option",
							Size = UDim2.new(1, 0, 0, 24),
							BackgroundColor3 = Theme.Colors.Button,
							TextColor3 = Theme.Colors.Text,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							TextXAlignment = Enum.TextXAlignment.Left,
							AutoButtonColor = false,
							LayoutOrder = 1 + Index,
							Text = function()
								const Entry = Release()

								return `  {Entry.version}{if Entry.prerelease then " (pre-release)" else ""}{if Entry.version == Chat.Installed() then "  · installed" else ""}`
							end,
							Activated = function()
								Chat.VersionPick(Release().version)
								Chat.VersionOpen(false)
							end,

							Create "UICorner" {CornerRadius = UDim.new(0, 4)},
						}
					end),
				},
				Button {
					Text = function()
						return if Chat.Updating() then "Working" else "Switch"
					end,
					Primary = true,
					LayoutOrder = 2,
					Visible = function()
						const Picked = Chat.VersionPick()

						return Picked ~= "" and Picked ~= Chat.Installed()
					end,
					OnClick = function()
						task.spawn(Chat.InstallVersion, Chat.VersionPick())
					end,
				},
			},
			Heading("MCP Servers", 7999),
			Vide.indexes(Chat.McpServers, Server),
			Create "TextLabel" {
				Name = "NoServers",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 8999,
				Visible = function()
					return #Chat.McpServers() == 0
				end,
				Text = "No MCP servers are set up for Claudio. They come from the Claude desktop app's config.",
			},
		},
	}
end