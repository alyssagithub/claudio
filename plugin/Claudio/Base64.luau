--!strict
const EncodingService = game:GetService("EncodingService")

const Base64 = {}

function Base64.Encode(Data: string): string
	return buffer.tostring(EncodingService:Base64Encode(buffer.fromstring(Data)))
end

function Base64.Decode(Text: string): buffer
	return EncodingService:Base64Decode(buffer.fromstring(Text))
end

return Base64