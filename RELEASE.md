## Changelogs

### Additions

- Tool calls appear while Claude is still writing them
- A box per call, and a run of them folds into one row
- Pictures stay in the call that took them
- Line counts and deletions in the change list, kept when you reopen the chat
- Undo on the change list, which takes back the whole turn
- Chats with no working folder
- Readme section on using Claudio's tools from other Claude apps
- Unread on queued messages, Send now on the front one

### Changes

- Calls are named the way the desktop app names them
- The token count ticks up as the reply arrives
- New chats start on Default instead of Auto
- A call that is still running can be folded
- The playtest crosshair installs for the playtest and goes when it ends
- Setup leaves the Claude desktop config alone

### Removals

- The `--mcp` flag on uninstall

## Installation

```
irm https://raw.githubusercontent.com/alyssagithub/claudio/main/install.ps1 | iex
```