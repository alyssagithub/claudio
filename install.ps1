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
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") + ";" + $env:Path
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
    Fail "This one's Windows only. Elsewhere install Node.js and Git yourself, then: npm install -g github:alyssagithub/claudio && claudio setup"
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

    if ($LASTEXITCODE -ne 0) {
        Fail "winget could not install Node.js (exit $LASTEXITCODE). That usually needs an elevated terminal, or get it from https://nodejs.org and run this again."
    }

    RefreshPath

    if (-not (Has "node")) {
        Fail "Node installed but isn't on PATH yet. Open a new terminal and run this again."
    }
}

if (-not (Has "git")) {
    if (-not (Has "winget")) {
        Fail "No Git, which npm needs to build Claudio from GitHub. Get it from https://git-scm.com, then run this again."
    }

    Write-Host "No Git, installing it."
    Native { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements --silent }
    RefreshPath

    if (-not (Has "git")) {
        Fail "Git installed but isn't on PATH yet. Open a new terminal and run this again."
    }
}

try {
    $Latest = (Invoke-RestMethod "https://api.github.com/repos/alyssagithub/claudio/commits/main" -Headers @{
        "User-Agent"    = "claudio-installer"
        "Cache-Control" = "no-cache"
    }).sha
} catch {
    Fail "Couldn't reach GitHub to find the newest version. Check your connection and run this again."
}

Write-Host "Building Claudio from the newest commit ($($Latest.Substring(0, 7))). Takes a minute."
Native { & npm install -g "github:alyssagithub/claudio#$Latest" --no-audit --no-fund }

if ($LASTEXITCODE -ne 0) {
    Fail "npm couldn't install it. Try a new terminal, or do it yourself: npm install -g github:alyssagithub/claudio#$Latest"
}

New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claudio" | Out-Null
$Record = [ordered]@{ commit = $Latest; at = (Get-Date).ToString("o") } | ConvertTo-Json

[System.IO.File]::WriteAllText("$env:USERPROFILE\.claudio\installed.json", $Record)

RefreshPath

if (-not (Has "claudio")) {
    Fail "Installed, but the claudio command isn't on PATH yet. Open a new terminal and run: claudio setup"
}

Write-Host ""
& claudio setup
