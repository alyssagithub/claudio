import assert from "node:assert/strict";
import { test } from "node:test";

const { IsNewer, LooksLikeVersion, NewestRelease } = await import("../src/PluginInstaller.js");

test("a version reads with or without a v and with a beta suffix", () => {
  assert.equal(LooksLikeVersion("1.5.0"), true);
  assert.equal(LooksLikeVersion("v1.5.0"), true);
  assert.equal(LooksLikeVersion("1.5.1-beta"), true);
  assert.equal(LooksLikeVersion("1.5.1-beta.2"), true);
  assert.equal(LooksLikeVersion("latest"), false);
  assert.equal(LooksLikeVersion("1.5.0 && calc"), false);
});

test("a higher number is newer, in any position", () => {
  assert.equal(IsNewer("1.5.1", "1.5.0"), true);
  assert.equal(IsNewer("1.10.0", "1.9.9"), true);
  assert.equal(IsNewer("2.0.0", "1.99.99"), true);
  assert.equal(IsNewer("1.5.0", "1.5.0"), false);
  assert.equal(IsNewer("1.4.9", "1.5.0"), false);
});

test("a beta sits above the release before it and below its own release", () => {
  assert.equal(IsNewer("1.5.1-beta", "1.5.0"), true);
  assert.equal(IsNewer("1.5.0", "1.5.1-beta"), false);
  assert.equal(IsNewer("1.5.1", "1.5.1-beta"), true);
  assert.equal(IsNewer("1.5.1-beta", "1.5.1"), false);
});

test("the newest release skips prereleases", () => {
  const Newest = NewestRelease([
    {
      version: "1.5.0",
      prerelease: false,
    },
    {
      version: "1.6.0-beta",
      prerelease: true,
    },
    {
      version: "1.4.0",
      prerelease: false,
    },
  ] as any);

  assert.equal(Newest && Newest.version, "1.5.0");
});