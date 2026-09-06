#Requires -Version 5.1
<#
    irm https://raw.githubusercontent.com/alyssagithub/claudio/main/install.ps1 | iex

    Gets Node.js if it's missing, installs Claudio, hands off to `claudio setup`.
#>

$ErrorActionPreference = "Stop"

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

# npm and winget write warnings to stderr, which a Stop preference turns into
# a terminating error. Run them with that turned off and check the exit code.
function Native([scriptblock]$Command) {
    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $Command
    } finally {
        $ErrorActionPreference = $Previous
    }
}

if ($IsMacOS -or $IsLinux) {
    Fail "This one's Windows only. Elsewhere install Node.js yourself, then: npm install -g https://github.com/alyssagithub/claudio/archive/refs/heads/main.tar.gz && claudio setup"
}

Write-Host ""

if (Has "node") {
    $Major = [int]((& node --version).TrimStart("v").Split(".")[0])

    if ($Major -lt 18) {
        Fail "Node $Major is too old, Claudio needs 18 or newer. Grab the LTS from https://nodejs.org and run this again."
    }

    Write-Host "Node $Major, fine."
} else {
    if (-not (Has "winget")) {
        Fail "No Node.js and no winget to install it with. Get the LTS from https://nodejs.org, then run this again."
    }

    Write-Host "No Node.js, installing it. Takes a couple of minutes."
    Native { winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements --silent }
    RefreshPath

    if (-not (Has "node")) {
        Fail "Node installed but isn't on PATH yet. Open a new terminal and run this again."
    }
}

# A branch archive sits behind a CDN for a few minutes, so someone reinstalling
# to pick up a fix can quietly get the version they already had. A commit
# archive is immutable and never cached wrong, so ask GitHub what main points at
# and install that exact commit.
$Latest = "main"

try {
    $Head = Invoke-RestMethod "https://api.github.com/repos/alyssagithub/claudio/commits/main" -Headers @{
        "User-Agent"    = "claudio-installer"
        "Cache-Control" = "no-cache"
    }

    if ($Head.sha) {
        $Latest = $Head.sha
    }
} catch {
    Write-Host "Couldn't reach GitHub to check the newest version, carrying on with main." -ForegroundColor DarkYellow
}

$Package = "https://github.com/alyssagithub/claudio/archive/$Latest.tar.gz"

Write-Host "Installing Claudio."
Native { & npm install -g $Package }

if ($LASTEXITCODE -ne 0) {
    Fail "npm couldn't install it. Try a new terminal, or do it yourself: npm install -g $Package"
}

New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claudio" | Out-Null
[ordered]@{ commit = $Latest; at = (Get-Date).ToString("o") } |
    ConvertTo-Json |
    Out-File "$env:USERPROFILE\.claudio\installed.json" -Encoding utf8

RefreshPath

if (-not (Has "claudio")) {
    Fail "Installed, but the claudio command isn't on PATH yet. Open a new terminal and run: claudio setup"
}

Write-Host ""
& claudio setup
