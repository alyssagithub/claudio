--!strict
const Vide = require(script.Parent.Parent.Packages.vide)
const Bounds = require(script.Parent.Parent.Bounds)

const Covers = {}

const Shown: {GuiObject} = {}

function Covers.Add(Object: GuiObject)
	table.insert(Shown, Object)

	Vide.cleanup(function()
		const Index = table.find(Shown, Object)

		if not Index then
			return
		end

		table.remove(Shown, Index)
	end)
end

const function Seen(Object: GuiObject): boolean
	local Current: Instance? = Object

	while Current and Current:IsA("GuiObject") do
		if not Current.Visible then
			return false
		end

		Current = Current.Parent
	end

	return Current ~= nil
end

function Covers.Over(Object: GuiObject, X: number, Y: number): boolean
	for _, Cover in Shown do
		if Cover ~= Object and not Object:IsDescendantOf(Cover) and Seen(Cover) and Bounds.Contains(Cover, Vector2.new(X, Y)) then
			return true
		end
	end

	return false
end

function Covers.Hover(Hovered: (boolean?) -> boolean): (GuiObject) -> ()
	return function(Object: GuiObject)
		const function Check(X: number, Y: number)
			const Wanted = not Covers.Over(Object, X, Y)

			if Hovered() == Wanted then
				return
			end

			Hovered(Wanted)
		end

		Vide.cleanup(Object.MouseEnter:Connect(Check))
		Vide.cleanup(Object.MouseMoved:Connect(Check))
		Vide.cleanup(Object.MouseLeave:Connect(function()
			Hovered(false)
		end))
	end
end

return Covers