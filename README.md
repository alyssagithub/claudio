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

Claude Code:

```powershell
claude mcp add claudio -- node "$(npm root -g)\claudio\bin\mcp.js"
```

Claude desktop app, in `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "claudio": {
      "command": "node",
      "args": ["C:\\Users\\you\\AppData\\Roaming\\npm\\node_modules\\claudio\\bin\\mcp.js"]
    }
  }
}
```

`npm root -g` prints the folder the path above starts from. Restart the app after editing the file.

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

## What it does

Tool calls show up in the reply and expand so you can see what it actually ran.

Underneath that it lists what changed in the place. It gets that by watching the data model while the turn runs. Anything you edit yourself while it's working stays credited to you.

Ctrl+Z undoes a whole turn. Hovering your own message also gives you a Rewind button, which goes back further.

The + button attaches things to your message: your selection, the open script, the Output window, an image. Each one becomes a tag that you write around, so you end up sending things like "the object [Baseplate] is handled by [Chat.luau], see [Output]". Ctrl+V pastes screenshots. During a playtest there's a crosshair for clicking something and sending it over.

Instance paths in a reply select the object. Script paths open the script at that line.

Usage limits and running cost are in the panel too. You can queue messages while it's still replying, mark chapters, fork a chat. Subagent activity shows under whatever spawned it. The model picker starts on Default, Claude Code's own default model. Auto picks a model and effort per message from the effort slider.

## Known issues

Studio only loads plugins when it starts, so setup usually means restarting it twice.

Opening a very long chat is slow, a few seconds for a transcript in the hundreds of megabytes, because the whole thing gets parsed to rebuild the messages.

Claude Code doesn't store what a turn cost anywhere, so for chats from before you installed this the cost is worked out from the token counts in the transcript. Prices are checked against real turns but hardcoded, so they'll drift if Anthropic changes them. Anything sent after installing records the real number instead.

The npm name `claudio` belongs to someone else, hence installing from git.

## Licence

MIT. Issues and suggestions at [github.com/alyssagithub/claudio/issues](https://github.com/alyssagithub/claudio/issues).
