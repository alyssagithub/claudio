## Changelogs

- A tool call now appears the moment Claude starts writing one, its arguments filling in as they arrive. Before, a long build script meant a minute of blank panel

- Each call gets its own box. A run of them collapses into one row you can unfold, and the arrow turns when it does

- A picture stays in the call that produced it, instead of being dumped at the bottom of the reply

- What a turn changed reads as a diff now, with line counts, deletions included, and it is still there when you reopen the chat

- Undo sits on that list. It takes the whole turn back, files a script Claude ran wrote included

- You can start a chat without picking a working folder, and clear the folder later from Settings

- The readme says how to point Claude Code or the desktop app at Claudio's tools. They work whether or not the panel is open

- Queued messages are marked Unread, with Send now on the front one

- The token count ticks up while the reply arrives instead of landing all at once at the end

- New chats start on Default, not Auto

- Calls are named the way the desktop app names them. A shell command shows its description; a tool search reads Loaded tools; a failure reads Failed to run, in red. A background command gets its own row when it finishes

- You can fold a call that is still running, which you could not before

- The playtest crosshair comes and goes with the playtest. Saving a place with that setting on used to leave a Claudio script sitting in it

- Setup no longer writes to the Claude desktop config. `--mcp` on uninstall did nothing but clean that up, so it is gone

## Installation

```
irm https://raw.githubusercontent.com/alyssagithub/claudio/main/install.ps1 | iex
```