# Claudio

Claude in Roblox Studio.

A chat panel that can see and edit the place you have open. It runs on the Claude Code login you already have so there's no API key anywhere in this. Each reply is one undo point, so Ctrl+Z takes a whole reply back.

Windows only. On Mac the plugin itself loads. The startup helper and the notifications don't.

## Install

Paste into PowerShell:

```powershell
irm https://raw.githubusercontent.com/alyssagithub/claudio/main/install.ps1 | iex
```

Or without the script:

```bash
npm install -g https://github.com/alyssagithub/claudio/archive/refs/heads/main.tar.gz
claudio setup
```

If you don't have Claude Code yet it'll open a window for you to log in. Then restart Studio and click **Claudio** in the Plugins tab, allowing HTTP requests when it asks. It'll ask you to pick a folder for Claude to work in before anything else, and you can change that later under settings.

## Using the Claudio tools from other Claude apps

The tools the panel gives Claude are also a normal MCP server, so Claude Code, the desktop app, or anything else that speaks MCP can drive your open place the same way. It needs the bridge running (the installer sets it to start with Windows, or run `claudio`) and Studio open with the plugin installed. The panel does not have to be open.

Installing Claudio puts a `claudio-mcp` command on your PATH, so nothing needs a file path.

Claude Code:

```powershell
claude mcp add claudio -- cmd /c claudio-mcp
```

Claude desktop app, in `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "claudio": {
      "command": "cmd",
      "args": ["/c", "claudio-mcp"]
    }
  }
}
```

It goes through `cmd` because the command npm installs is a `.cmd` file, and apps that start MCP servers do not resolve those on their own. Restart the app after editing the file.

## Uninstall

```powershell
irm https://raw.githubusercontent.com/alyssagithub/claudio/main/uninstall.ps1 | iex
```

Or `claudio uninstall` then `npm uninstall -g claudio`.

## Troubleshooting

Panel says it can't reach the bridge: `claudio restart`.

No Claudio button in the Plugins tab means Studio was open while it installed. Restart Studio.

If you clicked no on the HTTP prompt, Studio won't ask you again. Plugins tab, Manage Plugins, allow it there.

A new version breaking something can be rolled back from Settings, Connection, Plugin version, which lists every release.

Port 47225 being in use is usually another copy of the bridge. `claudio start --port 47300` and set the same number in Claudio's settings.

Claude replying but saying it can't see the place means the plugin isn't connected to the bridge. Open the panel and check the top of it says Connected, and that Studio allowed the plugin's HTTP requests.

## Licence

MIT. Issues and suggestions at [github.com/alyssagithub/claudio/issues](https://github.com/alyssagithub/claudio/issues).
