import { DecodeImage } from "./Images.js";

const Lookup = "https://discord-lookup-api-one.vercel.app/v1/user/";
const Cdn = "https://cdn.discordapp.com";
const HoldMilliseconds = 10 * 60 * 1000;

type Avatar = {
  Id: string;
  At: number;
  Hash: string | null;
  Animated: boolean;
  Name: string;
};

let Held: Avatar | null = null;

async function HashFor(Id: string): Promise<Avatar> {
  if (Held && Held.Id === Id && Date.now() - Held.At < HoldMilliseconds) {
    return Held;
  }

  const Answer = await fetch(`${Lookup}${Id}`, {headers: {"user-agent": "Claudio"}});

  if (!Answer.ok) {
    throw new Error(`the lookup answered ${Answer.status}`);
  }

  const Body = await Answer.json() as { avatar?: { id?: unknown; is_animated?: unknown } | null; username?: unknown };
  const Avatar = Body && Body.avatar;

  Held = {
    Id,
    At: Date.now(),
    Hash: Avatar && typeof Avatar.id === "string" ? Avatar.id : null,
    Animated: Boolean(Avatar && Avatar.is_animated),
    Name: typeof Body.username === "string" ? Body.username : Id,
  };

  return Held;
}

function DefaultFor(Id: string): string {
  return `${Cdn}/embed/avatars/${Number((BigInt(Id) >> 22n) % 6n)}.png`;
}

export async function AvatarFor(Id: string) {
  const Found = await HashFor(Id);
  const Address = Found.Hash ? `${Cdn}/avatars/${Id}/${Found.Hash}.png?size=256` : DefaultFor(Id);
  const Picture = await fetch(Address);

  if (!Picture.ok) {
    throw new Error(`the avatar answered ${Picture.status}`);
  }

  const Decoded = DecodeImage("image/png", Buffer.from(await Picture.arrayBuffer()).toString("base64"));

  if (!Decoded) {
    throw new Error("that avatar could not be decoded");
  }

  return {
    ...Decoded,
    name: Found.Name,
  };
}