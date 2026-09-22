--!strict
const Bounds = {}

function Bounds.Contains(Object: GuiObject, Point: Vector2): boolean
	const Corner = Object.AbsolutePosition
	const Size = Object.AbsoluteSize

	return Point.X >= Corner.X and Point.X <= Corner.X + Size.X and Point.Y >= Corner.Y and Point.Y <= Corner.Y + Size.Y
end

return Bounds