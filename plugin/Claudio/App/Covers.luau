--!strict
const Covers = {}

const Shown: {GuiObject} = {}

function Covers.Add(Object: GuiObject)
	table.insert(Shown, Object)

	Object.Destroying:Once(function()
		const Index = table.find(Shown, Object)

		if Index then
			table.remove(Shown, Index)
		end
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
		if Cover == Object or Object:IsDescendantOf(Cover) or not Seen(Cover) then
			continue
		end

		const Corner = Cover.AbsolutePosition
		const Size = Cover.AbsoluteSize

		if X >= Corner.X and X <= Corner.X + Size.X and Y >= Corner.Y and Y <= Corner.Y + Size.Y then
			return true
		end
	end

	return false
end

function Covers.Hover(Hovered: (boolean?) -> boolean): (GuiObject) -> ()
	return function(Object: GuiObject)
		const function Check(X: number, Y: number)
			const Wanted = not Covers.Over(Object, X, Y)

			if Hovered() ~= Wanted then
				Hovered(Wanted)
			end
		end

		Object.MouseEnter:Connect(Check)
		Object.MouseMoved:Connect(Check)
		Object.MouseLeave:Connect(function()
			Hovered(false)
		end)
	end
end

return Covers