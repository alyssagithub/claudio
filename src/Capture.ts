import { PNG } from "pngjs";

type EncodedImage = {
  error?: string;
  data?: string;
};

export function Enlarge(Data: string, Factor: number): { data: string; width: number; height: number } {
  const Image = PNG.sync.read(Buffer.from(Data, "base64"));
  const Scale = Math.max(1, Math.min(Math.floor(Factor), Math.floor(2048 / Math.max(Image.width, Image.height))));
  const Out = new PNG({
    width: Image.width * Scale,
    height: Image.height * Scale,
  });

  for (let Y = 0; Y < Out.height; Y += 1) {
    for (let X = 0; X < Out.width; X += 1) {
      Image.data.copy(Out.data, (Out.width * Y + X) * 4, (Image.width * Math.floor(Y / Scale) + Math.floor(X / Scale)) * 4, (Image.width * Math.floor(Y / Scale) + Math.floor(X / Scale)) * 4 + 4);
    }
  }

  return {
    data: PNG.sync.write(Out).toString("base64"),
    width: Out.width,
    height: Out.height,
  };
}

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