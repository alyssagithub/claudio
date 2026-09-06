#Requires -Version 5.1
<#
    Removes Claudio.

        irm https://raw.githubusercontent.com/alyssagithub/claudio/main/uninstall.ps1 | iex

    Stops the bridge, removes the Studio plugin, the startup entry and the
    .claudio folder, then uninstalls the npm package. Leaves your chats,
    their transcripts and your Claude Code login alone.

    Pass -Mcp to also remove the robloxstudio-mcp entry from the Claude
    desktop config. It is left in place by default because other Claude apps
    may be using it.
#>

param(
    [switch]$Mcp
)

$ErrorActionPreference = "Stop"

function Say($Text) {
    Write-Host $Text
}

function Has($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Say ""
Say "Removing Claudio."
Say ""

if (Has "claudio") {
    if ($Mcp) {
        & claudio uninstall --mcp
    } else {
        & claudio uninstall
    }
} else {
    Say "The claudio command is not installed, cleaning up its files directly."

    $Plugin = Join-Path $env:LOCALAPPDATA "Roblox\Plugins\Claudio.rbxm"
    $Folder = Join-Path $env:USERPROFILE ".claudio"
    $Startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\Claudio Bridge.vbs"

    foreach ($Target in @($Plugin, $Folder, $Startup)) {
        if (Test-Path $Target) {
            Remove-Item $Target -Recurse -Force
            Say "  removed $Target"
        }
    }
}

if (Has "npm") {
    Say ""
    Say "Removing the npm package."

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & npm uninstall -g claudio
    $ErrorActionPreference = $Previous
}

Say ""
Say "Done. Restart Roblox Studio to drop the plugin from its Plugins tab."
