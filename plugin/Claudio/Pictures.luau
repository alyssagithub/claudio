--!strict
const AssetService = game:GetService("AssetService")

const Base64 = require(script.Parent.Base64)

const Pictures = {}

export type Tile = {
	Image: EditableImage,
	Corner: Vector2,
}

export type Full = {
	Size: Vector2,
	Tiles: {Tile},
}

const Side = 1024
const Origins: {[EditableImage]: () -> (boolean, any)} = setmetatable({}, {__mode = "k"}) :: any

function Pictures.Build(Width: number, Height: number, PixelsBase64: string): EditableImage
	const Image = AssetService:CreateEditableImage({Size = Vector2.new(Width, Height)})

	Image:WritePixelsBuffer(Vector2.zero, Vector2.new(Width, Height), Base64.Decode(PixelsBase64))

	return Image
end

function Pictures.Tag(Image: EditableImage, Fetch: () -> (boolean, any)): EditableImage
	Origins[Image] = Fetch

	return Image
end

function Pictures.Tiles(Width: number, Height: number, PixelsBase64: string): {Tile}
	const Pixels = Base64.Decode(PixelsBase64)
	const Tiles = {}

	for Top = 0, Height - 1, Side do
		for Left = 0, Width - 1, Side do
			const Span = Vector2.new(math.min(Side, Width - Left), math.min(Side, Height - Top))
			const Piece = buffer.create(Span.X * Span.Y * 4)

			for Row = 0, Span.Y - 1 do
				buffer.copy(Piece, Row * Span.X * 4, Pixels, ((Top + Row) * Width + Left) * 4, Span.X * 4)
			end

			const Image = AssetService:CreateEditableImage({Size = Span})

			Image:WritePixelsBuffer(Vector2.zero, Span, Piece)
			table.insert(Tiles, {
				Image = Image,
				Corner = Vector2.new(Left, Top),
			})
		end
	end

	return Tiles
end

function Pictures.Full(Image: EditableImage): Full?
	const Fetch = Origins[Image]

	if not Fetch then
		return nil
	end

	const Ok, Found = Fetch()

	if not Ok or typeof(Found) ~= "table" or typeof(Found.pixels) ~= "string" then
		return nil
	end

	if Found.width <= Image.Size.X and Found.height <= Image.Size.Y then
		return nil
	end

	const Made, Tiles = pcall(Pictures.Tiles, Found.width, Found.height, Found.pixels)

	if not Made then
		return nil
	end

	return {
		Size = Vector2.new(Found.width, Found.height),
		Tiles = Tiles,
	}
end

return Pictures
