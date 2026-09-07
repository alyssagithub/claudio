--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	Stops: () -> {string},
	Chosen: () -> string,
	OnChange: (string) -> (),
	LayoutOrder: number?,
}

return function(Props: Props)
	local Track: Frame
	local Range: Frame

	const function Fraction(): number
		const Stops = Props.Stops()
		const Index = table.find(Stops, Props.Chosen()) or 1

		return if #Stops < 2 then 0 else (Index - 1) / (#Stops - 1)
	end

	const function Choose(PositionX: number)
		const Stops = Props.Stops()

		if #Stops < 2 or Range.AbsoluteSize.X <= 0 then
			return
		end

		const Along = math.clamp((PositionX - Range.AbsolutePosition.X) / Range.AbsoluteSize.X, 0, 1)
		const Index = math.clamp(math.round(Along * (#Stops - 1)) + 1, 1, #Stops)

		if Stops[Index] == Props.Chosen() then
			return
		end

		Props.OnChange(Stops[Index])
	end

	Range = Create "Frame" {
			Name = "Range",
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			BackgroundTransparency = 1,

			Vide.indexes(Props.Stops, function(Stop: () -> string, Index: number)
				return Create "Frame" {
					Name = "Stop",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = function()
						const Total = #Props.Stops()

						return UDim2.new(if Total < 2 then 0 else (Index - 1) / (Total - 1), 0, 0.5, 0)
					end,
					Size = UDim2.fromOffset(4, 4),
					BackgroundColor3 = Theme.Colors.DimText,
					ZIndex = 2,

					Create "UICorner" {CornerRadius = UDim.new(1, 0)},
				}
			end),
			Create "Frame" {
				Name = "Knob",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = function()
					return UDim2.new(Fraction(), 0, 0.5, 0)
				end,
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Theme.Colors.Text,
				ZIndex = 3,

				Create "UICorner" {CornerRadius = UDim.new(0, 5)},
			},
	}

	Track = Create "Frame" {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = Props.LayoutOrder,

		Create "Frame" {
			Name = "Line",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundColor3 = Theme.Colors.Button,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		},
		Range,
		Create "UIDragDetector" {
			ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomScale,

			Vide.action(function(Detector: UIDragDetector)
				Vide.cleanup(Detector.DragStart:Connect(function(Position: Vector2)
					Choose(Position.X)
				end))
				Vide.cleanup(Detector.DragContinue:Connect(function(Position: Vector2)
					Choose(Position.X)
				end))
			end),
		},
	}

	return Track
end