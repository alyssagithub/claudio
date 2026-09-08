import { PNG } from "pngjs";
import jpeg from "jpeg-js";
import { MaxImageWidth } from "./Config.js";

function DecodeBytes(MediaType, Bytes) {
  try {
    if (MediaType === "image/png") {
      const Decoded = PNG.sync.read(Bytes);
      return { width: Decoded.width, height: Decoded.height, data: Decoded.data };
    }

    if (MediaType === "image/jpeg" || MediaType === "image/jpg") {
      return jpeg.decode(Bytes, { useTArray: true, formatAsRGBA: true });
    }
  } catch {
    return null;
  }

  return null;
}

export function DecodeImage(MediaType, Base64) {
  const Decoded = DecodeBytes(MediaType, Buffer.from(Base64, "base64"));

  if (!Decoded) {
    return null;
  }

  const Scale = Math.min(1, MaxImageWidth / Decoded.width);
  const Width = Math.max(1, Math.round(Decoded.width * Scale));
  const Height = Math.max(1, Math.round(Decoded.height * Scale));
  const Source = Buffer.from(Decoded.data.buffer, Decoded.data.byteOffset, Decoded.data.byteLength);
  const Pixels = Buffer.alloc(Width * Height * 4);

  for (let Y = 0; Y < Height; Y += 1) {
    const SourceY = Math.min(Decoded.height - 1, Math.floor(Y / Scale));

    for (let X = 0; X < Width; X += 1) {
      const SourceIndex = (SourceY * Decoded.width + Math.min(Decoded.width - 1, Math.floor(X / Scale))) * 4;

      Source.copy(Pixels, (Y * Width + X) * 4, SourceIndex, SourceIndex + 4);
    }
  }

  return { width: Width, height: Height, pixels: Pixels.toString("base64") };
}

export function ImagesInContent(Content) {
  const Images = [];

  for (const Block of Array.isArray(Content) ? Content : []) {
    if (Block.type === "tool_result") {
      Images.push(...ImagesInContent(Block.content));
    } else if (Block.type === "image" && Block.source && Block.source.type === "base64") {
      Images.push({ mediaType: Block.source.media_type, data: Block.source.data });
    }
  }

  return Images;
}