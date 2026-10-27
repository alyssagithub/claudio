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
export function Shrink(Data: string, Longest: number): { data: string; width: number; height: number; scale: number } {
  const Image = PNG.sync.read(Buffer.from(Data, "base64"));
  const Scale = Math.max(Image.width, Image.height) / Longest;

  if (Scale <= 1) {
    return {data: Data, width: Image.width, height: Image.height, scale: 1};
  }

  const Out = new PNG({width: Math.round(Image.width / Scale), height: Math.round(Image.height / Scale)});

  for (let Y = 0; Y < Out.height; Y += 1) {
    for (let X = 0; X < Out.width; X += 1) {
      const Totals = [0, 0, 0, 0];
      let Count = 0;

      for (let FromY = Math.floor(Y * Scale); FromY < Math.min(Image.height, Math.floor((Y + 1) * Scale)); FromY += 1) {
        for (let FromX = Math.floor(X * Scale); FromX < Math.min(Image.width, Math.floor((X + 1) * Scale)); FromX += 1) {
          const At = (FromY * Image.width + FromX) * 4;

          for (let Channel = 0; Channel < 4; Channel += 1) {
            Totals[Channel] += Image.data[At + Channel];
          }

          Count += 1;
        }
      }

      for (let Channel = 0; Channel < 4; Channel += 1) {
        Out.data[(Y * Out.width + X) * 4 + Channel] = Totals[Channel] / Math.max(1, Count);
      }
    }
  }

  return {data: PNG.sync.write(Out).toString("base64"), width: Out.width, height: Out.height, scale: Scale};
}

export function Changed(Before: string, After: string): { x: number; y: number; width: number; height: number; share: number } | null | "size" {
  const Old = PNG.sync.read(Buffer.from(Before, "base64"));
  const New = PNG.sync.read(Buffer.from(After, "base64"));

  if (Old.width !== New.width || Old.height !== New.height) {
    return "size";
  }

  let Left = New.width;
  let Top = New.height;
  let Right = -1;
  let Bottom = -1;

  for (let Y = 0; Y < New.height; Y += 1) {
    for (let X = 0; X < New.width; X += 1) {
      const At = (Y * New.width + X) * 4;

      if (Math.abs(Old.data[At] - New.data[At]) + Math.abs(Old.data[At + 1] - New.data[At + 1]) + Math.abs(Old.data[At + 2] - New.data[At + 2]) > 48) {
        Left = Math.min(Left, X);
        Top = Math.min(Top, Y);
        Right = Math.max(Right, X);
        Bottom = Math.max(Bottom, Y);
      }
    }
  }

  if (Right < 0) {
    return null;
  }

  const Width = Right - Left + 1;
  const Height = Bottom - Top + 1;

  return {x: Left, y: Top, width: Width, height: Height, share: Width * Height / (New.width * New.height)};
}

export function Cut(Data: string, X: number, Y: number, Width: number, Height: number): string {
  const Image = PNG.sync.read(Buffer.from(Data, "base64"));
  const Out = new PNG({width: Width, height: Height});

  PNG.bitblt(Image, Out, X, Y, Width, Height, 0, 0);

  return PNG.sync.write(Out).toString("base64");
}
