import { spawn } from "node:child_process";
import readline from "node:readline";

export type ListedTool = { name: string; description: string };

const Cache = new Map<string, { At: number; Tools: ListedTool[] }>();

export function ListServerTools(Command: string, Arguments: string[], Environment?: Record<string, string>): Promise<ListedTool[] | null> {
  const Key = JSON.stringify([Command, Arguments]);
  const Cached = Cache.get(Key);

  if (Cached && Date.now() - Cached.At < 10 * 60 * 1000) {
    return Promise.resolve(Cached.Tools);
  }

  return new Promise((Resolve) => {
    let Finished = false;
    const Child = spawn(Command, Arguments, {
      env: {...process.env, ...Environment},
      stdio: ["pipe", "pipe", "ignore"],
      windowsHide: true,
      shell: process.platform === "win32" && /\.(cmd|bat)$/i.test(Command),
    });

    const Finish = (Tools: ListedTool[] | null) => {
      if (Finished) {
        return;
      }

      Finished = true;
      clearTimeout(Timer);
      Child.kill();

      if (Tools) {
        Cache.set(Key, {At: Date.now(), Tools});
      }

      Resolve(Tools);
    };

    const Timer = setTimeout(() => Finish(null), 15000);
    const Send = (Message: object) => Child.stdin.write(`${JSON.stringify(Message)}\n`);

    Child.on("error", () => Finish(null));
    Child.on("exit", () => Finish(null));

    readline.createInterface({input: Child.stdout}).on("line", (Line) => {
      let Message: { id?: number; result?: { tools?: { name: string; description?: string }[] } };

      try {
        Message = JSON.parse(Line);
      } catch {
        return;
      }

      if (Message.id === 1) {
        Send({jsonrpc: "2.0", method: "notifications/initialized"});
        Send({jsonrpc: "2.0", id: 2, method: "tools/list"});
        return;
      }

      if (Message.id === 2) {
        Finish(((Message.result && Message.result.tools) || []).map((Tool) => ({name: Tool.name, description: Tool.description || ""})));
      }
    });

    Send({jsonrpc: "2.0", id: 1, method: "initialize", params: {protocolVersion: "2024-11-05", capabilities: {}, clientInfo: {name: "claudio", version: "1"}}});
  });
}
