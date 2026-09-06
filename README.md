# Claudio

Claude, inside Roblox Studio.

Claudio adds a chat panel to Studio that can see and edit the place you have open. Ask it to fix a script or explain what something does, and it works on your actual game rather than guessing from what you paste in. Every reply gets its own undo point, so if it makes a mess you can take the whole thing back with one click.

It uses the Claude Code login you already have, so there's no API key to set up.

**A note on Windows:** this was built on Windows and that's where it's tested. The plugin itself should be fine on a Mac, but the "start it automatically" helper and the desktop notifications are Windows-only right now.

## Before you start

You need Roblox Studio, and that's genuinely it — the installer handles Node.js if you don't have it.

You'll be typing a couple of commands, so you need a terminal. Press the Windows key, type `powershell`, and hit Enter. A blue window opens with a blinking cursor. That's the terminal. It doesn't matter what folder it starts in.

## Installing

Paste this into PowerShell and press Enter:

```powershell
irm https://raw.githubusercontent.com/alyssagithub/claudio/main/install.ps1 | iex
```

That installs Node.js if you don't have it, installs Claudio, and then runs setup, which does the fiddly parts: Claude Code if it's missing, the plugin into your Roblox plugins folder, a Roblox MCP server if you don't have one, and starting the bridge in the background so you never have to launch it yourself.

If you'd rather not run a script off the internet, which is fair, do the same thing in two commands:

```bash
npm install -g github:alyssagithub/claudio
claudio setup
```

Either way, setup finishes by printing anything it couldn't do for you:

```
Setup finished. Steps you need to do yourself:

  1. Log in to Claude Code: run `claude` in a terminal, then follow the browser prompt.
  2. Fully close and reopen Roblox Studio so the Roblox MCP plugin loads.
  3. Restart Roblox Studio, then open the Claudio button in the Plugins tab.
```

Work through whatever it lists. If it asked you to log in, type `claude` and press Enter, and a browser tab opens for you to sign in. Once that's done, come back to the terminal and press Ctrl+C to close Claude Code again.

The restarts matter. Studio only looks for new plugins when it starts, so a plugin copied in while Studio is running won't show up until you close it and open it again. If setup also installed the Roblox MCP server, that one installs its own Studio plugin the first time it runs, which is why you can end up restarting twice.

## Using it

Open Roblox Studio. In the **Plugins** tab there'll be a Claudio button — click it and the chat panel appears, docked to the right. Studio will ask once whether to allow HTTP requests. Say yes. That's the panel talking to the bridge on your own machine, nothing leaves your computer.

If the bottom of the panel says it's connected, you're done. The bridge runs quietly in the background and starts with Windows, so Studio is the only thing you ever need to open.

If you'd rather it didn't start on its own, run `claudio uninstall-startup`. After that you start it yourself with `claudio`, which prints `Claudio bridge listening on http://127.0.0.1:47225` and then sits there looking frozen. It isn't — that's the bridge running, so leave the window open. There's also `claudio stop` to shut down a background one and `claudio restart` to pick up changes.

## If something's not working

**The panel says it can't reach the bridge.** The bridge isn't running. Run `claudio restart` to bring the background one back, or `claudio` in a terminal to start it in the foreground.

**You clicked "no" on the HTTP request prompt.** Studio won't ask twice. Open the Plugins tab, click Plugins Folder or Manage Plugins, find Claudio, and allow HTTP requests there.

**Port 47225 is already in use.** Something else grabbed it. Start the bridge on a different one with `claudio start --port 47300`, then set the same number in Claudio's settings, under the gear at the top of the panel.

**Claude replies but says it can't see your game.** That's the MCP server, not Claudio. See the next section.

**Nothing appears in the Plugins tab.** Studio was open when the plugin was installed. Close it completely and open it again.

## No Roblox MCP server yet?

This is the bit that lets Claude actually read your place. Without it the chat still works, but it'll tell you upfront that it can't see anything.

`claudio setup` sets up [robloxstudio-mcp](https://github.com/Chrrxs/robloxstudio-mcp) for you, and saves your old settings as `claude_desktop_config.json.claudio-backup` first in case you want them back.

If you'd rather do it by hand, the file lives at `%APPDATA%\Claude\claude_desktop_config.json` — paste that straight into the address bar of File Explorer to get there. Create the file if it isn't there yet, and if it already has an `mcpServers` section, add this entry inside it rather than replacing the whole thing:

```json
{
  "mcpServers": {
    "robloxstudio-mcp": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@chrrxs/robloxstudio-mcp@latest", "--auto-install-plugin"]
    }
  }
}
```

On Mac or Linux the file is at `~/Library/Application Support/Claude/claude_desktop_config.json`, and the entry is slightly different:

```json
{
  "mcpServers": {
    "robloxstudio-mcp": {
      "command": "npx",
      "args": ["-y", "@chrrxs/robloxstudio-mcp@latest", "--auto-install-plugin"]
    }
  }
}
```

It's a JSON file, so a stray comma will break it. Then close Studio fully and open it again, and check the Roblox MCP plugin's own panel says **Connected**.

Yes, that's the Claude *desktop app's* config file even though Claudio runs on Claude Code. That's deliberate: it's where MCP servers are already configured on most machines, so Claudio reads from there instead of asking you to set them up twice. Claudio only uses servers it recognises by name: `robloxstudio-mcp`, `Roblox_Studio` and `roblox-docs`. If yours is called something else, it will be ignored, and the easiest fix is to add the entry above alongside it.

## Updating

When there's a new version Claudio will offer it. If you say no, it won't ask about that version again, but it will mention the next one.

Claudio's own settings (the gear at the top of the panel) has a **Connection** section listing every release, so you can switch to a newer one or drop back to an older one if something breaks. Either way it loads next time Studio starts.

## What it can do

**Work on your place.** Claude uses the Roblox tools directly. Every tool call shows up in the reply and expands so you can see exactly what it ran.

**Tell you what changed.** Each reply lists the instances it created, deleted or edited. This is read back out of the game rather than guessed from what Claude said it would do, and anything you change yourself while it's working stays attributed to you.

**Undo a whole reply.** Ctrl+Z takes back everything from one reply instead of one property at a time. Hover a message you sent and there's a Rewind button that puts the place back to how it was before you sent it.

**Show it things.** The + button attaches your Explorer selection, the script you have open, the Output window, or an image. Each becomes a tag you write around, like "the object [Baseplate] is handled by [Chat.luau], see [Output]". You can also paste screenshots with Ctrl+V, and during a playtest a crosshair button lets you click any part or UI element to send it over.

**Click the paths it mentions.** An instance path selects that object in the Explorer. A script path opens the script at that line.

Beyond that: it shows your usage limits and what the chat has cost, you can queue messages while it's still replying, mark chapters in a long conversation or fork one to try something different, and when Claude spins up a subagent you can see what that agent is doing underneath the call that started it.

By default it picks its own model, starting cheap and moving up if a task turns out to be harder than it looked. Each reply says what it went with.

## Removing it

```powershell
irm https://raw.githubusercontent.com/alyssagithub/claudio/main/uninstall.ps1 | iex
```

Or by hand:

```bash
claudio uninstall
npm uninstall -g claudio
```

Either way it stops the bridge, deletes the plugin from your Roblox plugins folder, removes the `.claudio` folder holding its logs and caches, and takes out the startup entry. Your chats, their transcripts and your Claude Code login are left alone, since those belong to Claude Code rather than Claudio. The Roblox MCP server is also left in place, because other Claude apps may be using it — add `-Mcp` to the script, or `--mcp` to the command, if you want that gone too.

Restart Studio afterwards to drop the plugin from the Plugins tab.

## Licence

MIT. Bugs and suggestions welcome at [github.com/alyssagithub/claudio/issues](https://github.com/alyssagithub/claudio/issues).
