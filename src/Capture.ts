import { PNG } from "pngjs";

type EncodedImage = {
  error?: string;
  data?: string;
};

export function EncodePixels(Width: number, Height: number, Base64Pixels: string): EncodedImage {
  const Bytes = Buffer.from(Base64Pixels, "base64");
  const Wanted = Width * Height * 4;

  if (Bytes.length < Wanted) {
    return {error: `Studio sent ${Bytes.length} bytes for a ${Width} by ${Height} image, which needs ${Wanted}.`};
  }

  const Image = new PNG({
    width: Width,
    height: Height,
  });

  Bytes.copy(Image.data, 0, 0, Wanted);

  return {data: PNG.sync.write(Image).toString("base64")};
}