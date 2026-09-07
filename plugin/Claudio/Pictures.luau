--!strict
const AssetService = game:GetService("AssetService")

const Base64 = require(script.Parent.Base64)

const Pictures = {}

function Pictures.Build(Width: number, Height: number, PixelsBase64: string): EditableImage
	const Image = AssetService:CreateEditableImage({Size = Vector2.new(Width, Height)})

	Image:WritePixelsBuffer(Vector2.zero, Vector2.new(Width, Height), Base64.Decode(PixelsBase64))

	return Image
end

return Pictures