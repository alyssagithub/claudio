import fs from "node:fs";
import zlib from "node:zlib";

type Chunk = { Name: string; Body: Buffer };

function Lz4(Input: Buffer, Size: number): Buffer {
  const Output = Buffer.alloc(Size);
  let In = 0;
  let Out = 0;

  while (In < Input.length) {
    const Token = Input[In++];
    let Literal = Token >> 4;

    if (Literal === 15) {
      let More = 255;

      while (More === 255) {
        More = Input[In++];
        Literal += More;
      }
    }

    Input.copy(Output, Out, In, In + Literal);
    In += Literal;
    Out += Literal;

    if (In >= Input.length) {
      break;
    }

    const Back = Input[In] | (Input[In + 1] << 8);
    let Match = (Token & 15) + 4;

    In += 2;

    if ((Token & 15) === 15) {
      let More = 255;

      while (More === 255) {
        More = Input[In++];
        Match += More;
      }
    }

    for (let Step = 0; Step < Match; Step++) {
      Output[Out] = Output[Out - Back];
      Out++;
    }
  }

  return Output;
}

function Chunks(Data: Buffer): Chunk[] {
  const Found: Chunk[] = [];
  let At = 32;

  while (At < Data.length) {
    const Name = Data.toString("latin1", At, At + 4);
    const Packed = Data.readUInt32LE(At + 4);
    const Plain = Data.readUInt32LE(At + 8);

    At += 16;

    const Raw = Data.subarray(At, At + (Packed || Plain));

    At += Packed || Plain;

    const Body = Packed === 0 ? Raw : Raw.readUInt32BE(0) === 0x28b52ffd ? zlib.zstdDecompressSync(Raw) : Lz4(Raw, Plain);

    Found.push({Name, Body});

    if (Name === "END\0") {
      break;
    }
  }

  return Found;
}

class Reader {
  At = 0;

  constructor(public Body: Buffer) {}

  Byte() {
    return this.Body[this.At++];
  }

  Int() {
    this.At += 4;
    return this.Body.readInt32LE(this.At - 4);
  }

  Text() {
    const Size = this.Body.readUInt32LE(this.At);

    this.At += 4 + Size;

    return this.Body.subarray(this.At - Size, this.At);
  }

  Interleaved(Count: number, Width = 4): bigint[] {
    const Raw = this.Body.subarray(this.At, this.At + Count * Width);
    const Values: bigint[] = [];

    this.At += Count * Width;

    for (let Index = 0; Index < Count; Index++) {
      let Value = 0n;

      for (let Byte = 0; Byte < Width; Byte++) {
        Value = (Value << 8n) | BigInt(Raw[Byte * Count + Index]);
      }

      Values.push(Value);
    }

    return Values;
  }

  Zigzag(Count: number, Width = 4): number[] {
    return this.Interleaved(Count, Width).map((Value) => Number((Value >> 1n) ^ -(Value & 1n)));
  }

  Floats(Count: number): number[] {
    const Scratch = Buffer.alloc(4);

    return this.Interleaved(Count).map((Value) => {
      const Bits = Number(Value);

      Scratch.writeUInt32BE(((Bits >>> 1) | ((Bits & 1) << 31)) >>> 0);

      return Math.round(Scratch.readFloatBE(0) * 10000) / 10000;
    });
  }

  Referents(Count: number): number[] {
    let Last = 0;

    return this.Zigzag(Count).map((Value) => (Last += Value));
  }
}

export type HiddenValue = { kind: string; value: unknown };

function Decode(Kind: number, Reading: Reader, Count: number): HiddenValue[] | null {
  switch (Kind) {
    case 0x01:
      return Array.from({length: Count}, () => ({kind: "string", value: Reading.Text().toString("utf8").slice(0, 300)}));
    case 0x02:
      return Array.from({length: Count}, () => ({kind: "bool", value: Reading.Byte() !== 0}));
    case 0x03:
      return Reading.Zigzag(Count).map((Value) => ({kind: "int", value: Value}));
    case 0x04:
      return Reading.Floats(Count).map((Value) => ({kind: "float", value: Value}));
    case 0x05:
      return Array.from({length: Count}, () => {
        Reading.At += 8;

        return {kind: "double", value: Reading.Body.readDoubleLE(Reading.At - 8)};
      });
    case 0x0b:
      return Reading.Interleaved(Count).map((Value) => ({kind: "BrickColor", value: Number(Value)}));
    case 0x0c:
    case 0x0e: {
      const [First, Second, Third] = [Reading.Floats(Count), Reading.Floats(Count), Reading.Floats(Count)];

      return First.map((Value, Index) => ({kind: Kind === 0x0c ? "Color3" : "Vector3", value: [Value, Second[Index], Third[Index]]}));
    }
    case 0x12:
      return Reading.Interleaved(Count).map((Value) => ({kind: "enum", value: Number(Value)}));
    case 0x1a: {
      const Bytes = [0, 1, 2].map(() => Array.from({length: Count}, () => Reading.Byte()));

      return Bytes[0].map((Value, Index) => ({kind: "Color3", value: [Value / 255, Bytes[1][Index] / 255, Bytes[2][Index] / 255].map((Part) => Math.round(Part * 1000) / 1000)}));
    }
    case 0x1b:
      return Reading.Zigzag(Count, 8).map((Value) => ({kind: "int64", value: Value}));
    default:
      return null;
  }
}

export function ReadHidden(File: string, Path: string): { properties: Record<string, HiddenValue>; skipped: string[] } | { error: string } {
  const Found = Chunks(fs.readFileSync(File));
  const Classes = new Map<number, { Class: string; Refs: number[] }>();
  const Names = new Map<number, string>();
  const Parents = new Map<number, number>();
  const ClassOf = new Map<number, string>();

  for (const {Name, Body} of Found) {
    const Reading = new Reader(Body);

    if (Name === "INST") {
      const Id = Reading.Int();
      const Class = Reading.Text().toString("latin1");

      Reading.Byte();

      const Refs = Reading.Referents(Reading.Int());

      Classes.set(Id, {Class, Refs});
      Refs.forEach((Ref) => ClassOf.set(Ref, Class));
    } else if (Name === "PROP") {
      const Id = Reading.Int();

      if (Reading.Text().toString("latin1") !== "Name" || Reading.Byte() !== 0x01) {
        continue;
      }

      for (const Ref of (Classes.get(Id) as { Refs: number[] }).Refs) {
        Names.set(Ref, Reading.Text().toString("utf8"));
      }
    } else if (Name === "PRNT") {
      Reading.Byte();

      const Count = Reading.Int();
      const Children = Reading.Referents(Count);
      const Ups = Reading.Referents(Count);

      Children.forEach((Child, Index) => Parents.set(Child, Ups[Index]));
    }
  }

  const Wanted = Path.replace(/^game\./, "").split(".");
  let Target: number | null = null;

  for (const [Ref, Name] of Names) {
    if (Name !== Wanted[Wanted.length - 1]) {
      continue;
    }

    let Walk = Ref;
    let Matches = true;

    for (let Step = Wanted.length - 1; Step >= 0; Step--) {
      if (Names.get(Walk) !== Wanted[Step]) {
        Matches = false;
        break;
      }

      Walk = Parents.get(Walk) ?? -1;
    }

    if (Matches && !Names.has(Walk)) {
      Target = Ref;
      break;
    }
  }

  if (Target === null) {
    return {error: `Nothing at "${Path}" in the place file.`};
  }

  const Properties: Record<string, HiddenValue> = {};
  const Skipped: string[] = [];

  for (const {Name, Body} of Found) {
    if (Name !== "PROP") {
      continue;
    }

    const Reading = new Reader(Body);
    const Entry = Classes.get(Reading.Int()) as { Class: string; Refs: number[] };

    if (Entry.Class !== ClassOf.get(Target)) {
      continue;
    }

    const Property = Reading.Text().toString("latin1");
    const Values = Decode(Reading.Byte(), Reading, Entry.Refs.length);

    if (!Values) {
      Skipped.push(Property);
      continue;
    }

    Properties[Property] = Values[Entry.Refs.indexOf(Target)];
  }

  return {properties: Properties, skipped: Skipped};
}
