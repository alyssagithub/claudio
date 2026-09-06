#Requires -Version 5.1
<#
    irm https://raw.githubusercontent.com/alyssagithub/claudio/main/uninstall.ps1 | iex

    Hands off to `claudio uninstall`, then removes the npm package. Add -Mcp to
    drop the Roblox MCP server as well.
#>

param(
    [switch]$Mcp
)

$ErrorActionPreference = "Stop"

function Has($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host ""

if (Has "claudio") {
    if ($Mcp) {
        & claudio uninstall --mcp
    } else {
        & claudio uninstall
    }
} else {
    Write-Host "No claudio command, so clearing its files directly."

    $Targets = @(
        (Join-Path $env:LOCALAPPDATA "Roblox\Plugins\Claudio.rbxm"),
        (Join-Path $env:USERPROFILE ".claudio"),
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\Claudio Bridge.vbs")
    )

    foreach ($Target in $Targets) {
        if (Test-Path $Target) {
            Remove-Item $Target -Recurse -Force
            Write-Host "  $Target"
        }
    }
}

if (Has "npm") {
    Write-Host ""
    Write-Host "Removing the npm package."

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & npm uninstall -g claudio
    } finally {
        $ErrorActionPreference = $Previous
    }
}

Write-Host ""
Write-Host "Done. Restart Studio to clear it out of the Plugins tab."
