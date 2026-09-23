import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import zlib from "node:zlib";

const Home = fs.mkdtempSync(path.join(os.tmpdir(), "claudio-test-"));

process.env.USERPROFILE = Home;
process.env.HOME = Home;
process.env.APPDATA = path.join(Home, "Roaming");

const { DeleteConversation, GetConversation, GetConversationImage, LatestContext, StripContext, ExtractContext } = await import("../src/Conversations.js");
const { MostCallText } = await import("../src/Config.js");

const Picture = {
  type: "image",
  source: {
    type: "base64",
    media_type: "image/png",
    data: "aGk=",
  },
};

function Line(Type: string, Content: unknown, Extra?: Record<string, unknown>) {
  return JSON.stringify({
    type: Type,
    timestamp: "2026-09-13T10:00:00.000Z",
    message: {
      role: Type === "assistant" ? "assistant" : "user",
      content: Content,
    },
    ...Extra,
  });
}

function WriteTranscript(Id: string, Lines: string[]) {
  const Folder = path.join(Home, ".claude", "projects", "C--Users-Test-Place");

  fs.mkdirSync(Folder, {recursive: true});
  fs.writeFileSync(path.join(Folder, `${Id}.jsonl`), Lines.join("\n") + "\n");
}

test("a reply keeps its calls with their arguments and results", () => {
  WriteTranscript("calls", [
    Line("user", [{
      type: "text",
      text: "count the parts",
    }]),
    Line("assistant", [{
      type: "tool_use",
      id: "t1",
      name: "mcp__claudio__execute",
      input: {
        code: "return 4",
        readOnly: true,
      },
    }]),
    Line("user", [{
      type: "tool_result",
      tool_use_id: "t1",
      content: [{
        type: "text",
        text: "4",
      }],
    }]),
    Line("assistant", [{
      type: "text",
      text: "There are 4.",
    }]),
  ]);

  const Found = GetConversation("calls")!;

  assert.equal(Found.messages.length, 2);
  assert.equal(Found.messages[1].role, "assistant");
  assert.equal(Found.messages[1].calls!.length, 1);
  assert.equal(Found.messages[1].calls![0].name, "mcp__claudio__execute");
  assert.equal(Found.messages[1].calls![0].input, "code: return 4\nreadOnly: true");
  assert.equal(Found.messages[1].calls![0].output, "4");
  assert.equal(Found.messages[1].calls![0].status, "done");
  assert.equal(Found.messages[1].calls![0].image, null);
});

test("a failed call is marked and its output kept", () => {
  WriteTranscript("failed", [
    Line("user", [{
      type: "text",
      text: "go",
    }]),
    Line("assistant", [{
      type: "tool_use",
      id: "t1",
      name: "Bash",
      input: {
        command: "ls /nope",
        description: "Look",
      },
    }]),
    Line("user", [{
      type: "tool_result",
      tool_use_id: "t1",
      is_error: true,
      content: [{
        type: "text",
        text: "No such file",
      }],
    }]),
    Line("assistant", [{
      type: "text",
      text: "It is not there.",
    }]),
  ]);

  const Call = GetConversation("failed")!.messages[1].calls![0];

  assert.equal(Call.status, "error");
  assert.equal(Call.output, "No such file");
});

test("a picture a call produced is tied to that call and counted for the message", () => {
  WriteTranscript("pictures", [
    Line("user", [{
      type: "text",
      text: "look",
    }]),
    Line("assistant", [{
      type: "tool_use",
      id: "t1",
      name: "mcp__claudio__capture",
      input: {of: "viewport"},
    }]),
    Line("user", [{
      type: "tool_result",
      tool_use_id: "t1",
      content: [
        {
          type: "text",
          text: "800x600",
        },
        Picture,
      ],
    }]),
    Line("assistant", [{
      type: "tool_use",
      id: "t2",
      name: "Read",
      input: {file_path: "C:/a.png"},
    }]),
    Line("user", [{
      type: "tool_result",
      tool_use_id: "t2",
      content: [Picture],
    }]),
    Line("assistant", [{
      type: "text",
      text: "Two pictures.",
    }]),
  ]);

  const Reply = GetConversation("pictures")!.messages[1];

  assert.deepEqual(Reply.images, [1, 2]);
  assert.equal(Reply.calls![0].image, 1);
  assert.equal(Reply.calls![1].image, 2);
  assert.equal(Reply.calls![0].output, "800x600");
});

test("a message sent mid turn splits the reply where it landed", () => {
  WriteTranscript("midturn", [
    Line("user", [{
      type: "text",
      text: "start",
    }]),
    Line("assistant", [{
      type: "text",
      text: "First half.",
    }]),
    Line("user", [{
      type: "text",
      text: "also this",
    }]),
    Line("assistant", [{
      type: "text",
      text: "Second half.",
    }]),
  ]);

  const Roles = GetConversation("midturn")!.messages.map((Message) => `${Message.role}:${Message.text}`);

  assert.deepEqual(Roles, ["user:start", "assistant:First half.", "user:also this", "assistant:Second half."]);
});

test("two replies with nothing between them join as one, and their pictures follow", () => {
  WriteTranscript("joined", [
    Line("user", [{
      type: "text",
      text: "go",
    }]),
    Line("assistant", [{
      type: "text",
      text: "One.",
    }]),
    Line("assistant", [{
      type: "tool_use",
      id: "t1",
      name: "mcp__claudio__capture",
      input: {},
    }]),
    Line("user", [{
      type: "tool_result",
      tool_use_id: "t1",
      content: [Picture],
    }]),
    Line("assistant", [{
      type: "text",
      text: "Two.",
    }]),
  ]);

  const Messages = GetConversation("joined")!.messages;

  assert.equal(Messages.length, 2);
  assert.equal(Messages[1].text, "One.\n\nTwo.");
  assert.deepEqual(Messages[1].images, [1]);
  assert.equal(Messages[1].calls![0].image, 1);
});

test("attached context is stripped from what the user is shown to have said", () => {
  WriteTranscript("context", [
    Line("user", [{
      type: "text",
      text: "fix it\n\n<studio_context>\nlots\n</studio_context>",
    }]),
    Line("assistant", [{
      type: "text",
      text: "Done.",
    }]),
  ]);

  assert.equal(GetConversation("context")!.messages[0].text, "fix it");
});

test("sidechain and meta lines are not messages", () => {
  WriteTranscript("side", [
    Line("user", [{
      type: "text",
      text: "real",
    }]),
    Line("user", [{
      type: "text",
      text: "<system-reminder>ignored</system-reminder>",
    }], {isMeta: true}),
    Line("assistant", [{
      type: "text",
      text: "sub agent",
    }], {isSidechain: true}),
    Line("assistant", [{
      type: "text",
      text: "Reply.",
    }]),
  ]);

  const Messages = GetConversation("side")!.messages;

  assert.equal(Messages.length, 2);
  assert.equal(Messages[1].text, "Reply.");
});

test("tool output is kept whole up to the call text cap", () => {
  WriteTranscript("long", [
    Line("user", [{
      type: "text",
      text: "go",
    }]),
    Line("assistant", [{
      type: "tool_use",
      id: "t1",
      name: "Bash",
      input: {command: "cat big"},
    }]),
    Line("user", [{
      type: "tool_result",
      tool_use_id: "t1",
      content: [{
        type: "text",
        text: "x".repeat(5000),
      }],
    }]),
    Line("user", [{
      type: "tool_result",
      tool_use_id: "t1",
      content: [{
        type: "text",
        text: "y".repeat(MostCallText + 500),
      }],
    }]),
    Line("assistant", [{
      type: "text",
      text: "Long.",
    }]),
  ]);

  const Calls = GetConversation("long")!.messages[1].calls!;

  assert.equal(Calls[0].output.length, MostCallText);
});

test("an unknown conversation is null", () => {
  assert.equal(GetConversation("missing"), null);
});

test("StripContext and ExtractContext split a prompt into its halves", () => {
  const Text = "hello\n\n<studio_place>\nMyPlace\n</studio_place>\n\nI changed these in Studio myself since my last message:\n- Moved Part";

  assert.equal(StripContext(Text), "hello");
  assert.ok(ExtractContext(Text).includes("<studio_place>"));
  assert.ok(ExtractContext(Text).includes("Moved Part"));
  assert.equal(StripContext("plain"), "plain");
  assert.equal(ExtractContext("plain"), "");
});
test("a stopped reply keeps its work and does not show the interruption as a message", () => {
  WriteTranscript("stopped", [
    Line("user", [{
      type: "text",
      text: "count the parts, then write an essay",
    }]),
    Line("assistant", [{
      type: "thinking",
      thinking: "I should count first",
    }]),
    Line("assistant", [{
      type: "tool_use",
      id: "t1",
      name: "mcp__claudio__execute",
      input: {
        code: "return 4",
      },
    }]),
    Line("user", [{
      type: "text",
      text: "[Request interrupted by user for tool use]",
    }]),
  ]);

  const Built = GetConversation("stopped")!;

  assert.equal(Built.messages.length, 2);
  assert.equal(Built.messages[1].role, "assistant");
  assert.deepEqual(Built.messages[1].parts!.map((Part) => Part.kind), ["thinking", "call"]);
  assert.equal(Built.messages[1].calls![0].name, "mcp__claudio__execute");
});

test("a reply stopped before it produced anything reads as stopped", () => {
  WriteTranscript("stopped-early", [
    Line("user", [{
      type: "text",
      text: "hello",
    }]),
    Line("user", [{
      type: "text",
      text: "[Request interrupted by user]",
    }]),
    Line("user", [{
      type: "text",
      text: "try again",
    }]),
  ]);

  const Built = GetConversation("stopped-early")!;

  assert.deepEqual(Built.messages.map((Message) => `${Message.role}:${Message.text}`), ["user:hello", "assistant:Stopped.", "user:try again"]);
});

test("the saved context is the last reply's usage, or the size after a later compaction", () => {
  const Reply = (Input: number) => JSON.stringify({
    type: "assistant",
    timestamp: "2026-09-13T10:00:00.000Z",
    message: {
      role: "assistant",
      model: "claude-opus-5-5",
      content: [{
        type: "text",
        text: "done",
      }],
      usage: {
        input_tokens: Input,
        cache_creation_input_tokens: 100,
        cache_read_input_tokens: 1000,
        output_tokens: 50,
      },
    },
  });

  WriteTranscript("context", [
    Line("user", [{
      type: "text",
      text: "hi",
    }]),
    Reply(10),
    Reply(20),
  ]);

  assert.deepEqual({...LatestContext("context"), at: 0}, {
    total: 1170,
    model: "claude-opus-5-5",
    at: 0,
  });

  WriteTranscript("compacted", [
    Line("user", [{
      type: "text",
      text: "hi",
    }]),
    Reply(90000),
    JSON.stringify({
      type: "system",
      subtype: "compact_boundary",
      compactMetadata: {
        trigger: "manual",
        preTokens: 91150,
        postTokens: 3000,
      },
    }),
  ]);

  assert.equal(LatestContext("compacted")!.total, 3000);
  assert.equal(LatestContext("compacted")!.model, "claude-opus-5-5");
});
test("a chat renamed twice shows its latest name", () => {
  WriteTranscript("renamed", [
    Line("user", [{
      type: "text",
      text: "hello",
    }]),
    JSON.stringify({
      type: "custom-title",
      customTitle: "First name",
    }),
    JSON.stringify({
      type: "custom-title",
      customTitle: "Second name",
    }),
  ]);

  assert.equal(GetConversation("renamed")!.title, "Second name");
});

test("deleting a chat removes its desktop record from an older organization too", () => {
  WriteTranscript("elsewhere", [Line("user", "hello")]);

  const Account = path.join(Home, "Roaming", "Claude", "claude-code-sessions", "account");
  const Older = path.join(Account, "older");
  const Newer = path.join(Account, "newer");
  const Record = path.join(Older, "local_elsewhere.json");

  fs.mkdirSync(Older, {recursive: true});
  fs.writeFileSync(Record, JSON.stringify({
    sessionId: "local_elsewhere",
    cliSessionId: "elsewhere",
  }));
  fs.utimesSync(Older, new Date(2020, 0, 1), new Date(2020, 0, 1));
  fs.mkdirSync(Newer, {recursive: true});

  assert.equal(DeleteConversation("elsewhere"), true);
  assert.equal(fs.existsSync(Record), false);
});

function Square(Size: number) {
  const Chunk = (Kind: string, Data: Buffer) => {
    const Named = Buffer.concat([Buffer.from(Kind), Data]);
    const Length = Buffer.alloc(4);
    const Check = Buffer.alloc(4);

    Length.writeUInt32BE(Data.length);
    Check.writeUInt32BE(zlib.crc32(Named));

    return Buffer.concat([Length, Named, Check]);
  };
  const Header = Buffer.alloc(13);

  Header.writeUInt32BE(Size, 0);
  Header.writeUInt32BE(Size, 4);
  Header[8] = 8;
  Header[9] = 6;

  const Rows = Buffer.alloc(Size * (Size * 4 + 1), 255);

  for (let Row = 0; Row < Size; Row += 1) {
    Rows[Row * (Size * 4 + 1)] = 0;
  }

  return {
    type: "image",
    source: {
      type: "base64",
      media_type: "image/png",
      data: Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), Chunk("IHDR", Header), Chunk("IDAT", zlib.deflateSync(Rows)), Chunk("IEND", Buffer.alloc(0))]).toString("base64"),
    },
  };
}

test("an image in the recent part of a long chat opens as itself, not an earlier one", () => {
  const Lines = [Line("user", [Square(1), {
    type: "text",
    text: "first",
  }])];

  for (let Round = 0; Round < 4; Round += 1) {
    Lines.push(Line("user", `question ${Round}`), Line("assistant", [{
      type: "text",
      text: "x".repeat(1100000),
    }], {requestId: `round-${Round}`}));
  }

  Lines.push(Line("user", [Square(2), {
    type: "text",
    text: "last",
  }]), Line("assistant", [{
    type: "text",
    text: "seen",
  }], {requestId: "last"}));
  WriteTranscript("pictured", Lines);

  const Recent = GetConversation("pictured", 1)!;
  const Last = Recent.messages.find((Message) => Message.text === "last")!;

  assert.equal(Recent.partial, true);
  assert.equal(GetConversationImage("pictured", Last.images[0])!.width, 2);
});
