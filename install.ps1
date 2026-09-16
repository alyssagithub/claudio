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
    Fail "This one's Windows only. Elsewhere install Node.js yourself, then npm install -g the .tgz attached to the newest release at https://github.com/alyssagithub/claudio/releases, and run claudio setup"
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

try {
    $Release = Invoke-RestMethod "https://api.github.com/repos/alyssagithub/claudio/releases/latest" -Headers @{
        "User-Agent"    = "claudio-installer"
        "Cache-Control" = "no-cache"
    }
} catch {
    Fail "Couldn't reach GitHub to find the newest release. Check your connection and run this again."
}

$Packed = $Release.assets | Where-Object { $_.name -like "*.tgz" } | Select-Object -First 1

if (-not $Packed) {
    Fail "The newest release ($($Release.tag_name)) has no package attached. Try again later, or tell the author."
}

$Package = $Packed.browser_download_url
$Latest = ""

try {
    $Latest = (Invoke-RestMethod "https://api.github.com/repos/alyssagithub/claudio/commits/$($Release.tag_name)" -Headers @{ "User-Agent" = "claudio-installer" }).sha
} catch {
}

Write-Host "Installing Claudio."
Native { & npm install -g $Package }

if ($LASTEXITCODE -ne 0) {
    Fail "npm couldn't install it. Try a new terminal, or do it yourself: npm install -g $Package"
}

if ($Latest) {
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claudio" | Out-Null
    $Record = [ordered]@{ commit = $Latest; at = (Get-Date).ToString("o") } | ConvertTo-Json

    [System.IO.File]::WriteAllText("$env:USERPROFILE\.claudio\installed.json", $Record)
}

RefreshPath

if (-not (Has "claudio")) {
    Fail "Installed, but the claudio command isn't on PATH yet. Open a new terminal and run: claudio setup"
}

Write-Host ""
& claudio setup
