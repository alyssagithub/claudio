$ErrorActionPreference = "Stop"

$Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$Had = Get-ItemProperty -Path $Key -Name TaskbarFlashing -ErrorAction SilentlyContinue
$Before = if ($Had) { [int]$Had.TaskbarFlashing } else { -1 }

if ($Before -ne 0) {
    Set-ItemProperty -Path $Key -Name TaskbarFlashing -Value 0 -Type DWord
}

[Console]::Out.WriteLine("quiet")
[Console]::Out.Flush()

$Until = (Get-Date).AddSeconds([double]$env:CLAUDIO_QUIET_SECONDS)
$Reader = [Console]::In

while ((Get-Date) -lt $Until) {
    if ($Reader.Peek() -ge 0) {
        $Reader.ReadLine() | Out-Null
        Start-Sleep -Seconds 3

        break
    }

    Start-Sleep -Milliseconds 200
}

if ($Before -eq -1) {
    Remove-ItemProperty -Path $Key -Name TaskbarFlashing -ErrorAction SilentlyContinue
} elseif ($Before -ne 0) {
    Set-ItemProperty -Path $Key -Name TaskbarFlashing -Value $Before -Type DWord
}

[Console]::Out.WriteLine("restored")