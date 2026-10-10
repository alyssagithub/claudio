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

export function Guide(Data: string, Wide: number, Tall: number, Crop: boolean): { data: string; width: number; height: number; x: number; y: number; scale: number } {
  const Image = PNG.sync.read(Buffer.from(Data, "base64"));
  const Fits = Image.width / Image.height > Wide / Tall;
  const Width = Fits ? Math.round(Image.height * Wide / Tall) : Image.width;
  const Height = Fits ? Image.height : Math.round(Image.width * Tall / Wide);
  const Left = Math.floor((Image.width - Width) / 2);
  const Top = Math.floor((Image.height - Height) / 2);

  if (Crop) {
    const Out = new PNG({
      width: Width,
      height: Height,
    });

    PNG.bitblt(Image, Out, Left, Top, Width, Height, 0, 0);

    return {data: PNG.sync.write(Out).toString("base64"), width: Width, height: Height, x: Left, y: Top, scale: Wide / Width};
  }

  for (let Y = 0; Y < Image.height; Y += 1) {
    for (let X = 0; X < Image.width; X += 1) {
      const At = (Image.width * Y + X) * 4;
      const Inside = X >= Left && X < Left + Width && Y >= Top && Y < Top + Height;
      const Edge = Inside && (X === Left || X === Left + Width - 1 || Y === Top || Y === Top + Height - 1);
      const Third = Inside && (X === Left + Math.round(Width / 3) || X === Left + Math.round(Width * 2 / 3) || Y === Top + Math.round(Height / 3) || Y === Top + Math.round(Height * 2 / 3));

      if (Edge) {
        Image.data[At] = 255;
        Image.data[At + 1] = 220;
        Image.data[At + 2] = 0;
      } else if (Third) {
        Image.data[At] = Math.round(Image.data[At] * 0.6 + 102);
        Image.data[At + 1] = Math.round(Image.data[At + 1] * 0.6 + 102);
        Image.data[At + 2] = Math.round(Image.data[At + 2] * 0.6 + 102);
      } else if (!Inside) {
        Image.data[At] = Math.round(Image.data[At] * 0.3);
        Image.data[At + 1] = Math.round(Image.data[At + 1] * 0.3);
        Image.data[At + 2] = Math.round(Image.data[At + 2] * 0.3);
      }
    }
  }

  return {data: PNG.sync.write(Image).toString("base64"), width: Image.width, height: Image.height, x: Left, y: Top, scale: Wide / Width};
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