$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$Mode = if ($env:CLAUDIO_CLIPBOARD_MODE) { $env:CLAUDIO_CLIPBOARD_MODE } else { "read" }
$Marker = $env:CLAUDIO_CLIPBOARD_MARKER

function Set-PrivateClipboard {
    param($Bundle)

    foreach ($Format in @("CanIncludeInClipboardHistory", "CanUploadToCloudClipboard", "ExcludeClipboardContentFromMonitorProcessing")) {
        $Stream = New-Object System.IO.MemoryStream
        $Writer = New-Object System.IO.BinaryWriter($Stream)
        $Writer.Write([uint32]0)
        $Writer.Flush()
        $Bundle.SetData($Format, $Stream)
    }

    [System.Windows.Forms.Clipboard]::SetDataObject($Bundle, $true)
}

function Get-ClipboardImage {
    if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
        return [System.Windows.Forms.Clipboard]::GetImage()
    }

    if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
        $File = [System.Windows.Forms.Clipboard]::GetFileDropList() | Where-Object { $_ -match "\.(png|jpg|jpeg|bmp|gif)$" } | Select-Object -First 1

        if ($File) {
            return [System.Drawing.Image]::FromFile($File)
        }
    }

    return $null
}

function Get-ClipboardText {
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        return [System.Windows.Forms.Clipboard]::GetText()
    }

    return $null
}

if ($Mode -eq "arm") {
    $Picture = Get-ClipboardImage

    if (-not $Picture) {
        "noimage"
        exit
    }

    if ((Get-ClipboardText) -eq $Marker) {
        $Picture.Dispose()
        "already"
        exit
    }

    $Bundle = New-Object System.Windows.Forms.DataObject
    $Bundle.SetImage($Picture)
    $Bundle.SetText($Marker)
    Set-PrivateClipboard $Bundle
    $Picture.Dispose()
    "armed"
    exit
}

if ($Mode -eq "disarm") {
    if ((Get-ClipboardText) -ne $Marker) {
        "notours"
        exit
    }

    $Picture = Get-ClipboardImage

    if (-not $Picture) {
        "noimage"
        exit
    }

    $Bundle = New-Object System.Windows.Forms.DataObject
    $Bundle.SetImage($Picture)
    Set-PrivateClipboard $Bundle
    $Picture.Dispose()
    "disarmed"
    exit
}

$Picture = Get-ClipboardImage

if (-not $Picture) {
    "none"
    exit
}

$Limit = 1400

if ($Picture.Width -gt $Limit -or $Picture.Height -gt $Limit) {
    $Scale = [Math]::Min($Limit / $Picture.Width, $Limit / $Picture.Height)
    $Resized = New-Object System.Drawing.Bitmap($Picture, [int] ($Picture.Width * $Scale), [int] ($Picture.Height * $Scale))
    $Picture.Dispose()
    $Picture = $Resized
}

$Stream = New-Object System.IO.MemoryStream
$Picture.Save($Stream, [System.Drawing.Imaging.ImageFormat]::Png)
$Picture.Dispose()

[Convert]::ToBase64String($Stream.ToArray())
$Stream.Dispose()
