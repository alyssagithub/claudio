#Requires -Version 5.1
<#
    Installs Claudio.

        irm https://raw.githubusercontent.com/alyssagithub/claudio/main/install.ps1 | iex

    Installs Node.js if it is missing, installs Claudio from GitHub, then runs
    `claudio setup`, which handles Claude Code, the Studio plugin, the Roblox
    MCP server, and starting the bridge with Windows.
#>

$ErrorActionPreference = "Stop"

function Say($Text) {
    Write-Host $Text
}

function Fail($Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Red
    exit 1
}

function Has($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function RefreshPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

Say ""
Say "Installing Claudio."
Say ""

if ($IsMacOS -or $IsLinux) {
    Fail "This installer is for Windows. On Mac or Linux, install Node.js yourself, then run: npm install -g github:alyssagithub/claudio && claudio setup"
}

if (Has "node") {
    $Version = (& node --version).TrimStart("v").Split(".")[0]

    if ([int]$Version -lt 18) {
        Fail "Node.js $Version is too old. Claudio needs 18 or newer. Update it at https://nodejs.org and run this again."
    }

    Say "Node.js is already installed."
} else {
    if (-not (Has "winget")) {
        Fail "Node.js is missing and winget is not available to install it. Install the LTS version from https://nodejs.org, then run this again."
    }

    Say "Node.js is missing, installing it. This takes a couple of minutes."
    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements --silent
    $ErrorActionPreference = $Previous
    RefreshPath

    if (-not (Has "node")) {
        Fail "Node.js was installed but is not on PATH yet. Close this window, open a new one, and run this again."
    }

    Say "Installed Node.js."
}

Say "Installing Claudio from GitHub. This takes a minute."

$Previous = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& npm install -g github:alyssagithub/claudio
$ErrorActionPreference = $Previous

if ($LASTEXITCODE -ne 0) {
    Fail "npm could not install Claudio. Try running this in a new terminal, or install it yourself with: npm install -g github:alyssagithub/claudio"
}

RefreshPath

if (-not (Has "claudio")) {
    Fail "Claudio installed but its command is not on PATH yet. Close this window, open a new one, and run: claudio setup"
}

Say ""
& claudio setup
