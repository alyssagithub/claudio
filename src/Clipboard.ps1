$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class ClipboardSequence { [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber(); }'

$Seen = [uint32]0

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

function Get-Png {
    param($Picture)

    $Limit = 1400

    if ($Picture.Width -gt $Limit -or $Picture.Height -gt $Limit) {
        $Scale = [Math]::Min($Limit / $Picture.Width, $Limit / $Picture.Height)
        $Picture = New-Object System.Drawing.Bitmap($Picture, [int] ($Picture.Width * $Scale), [int] ($Picture.Height * $Scale))
    }

    $Stream = New-Object System.IO.MemoryStream
    $Picture.Save($Stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $Encoded = [Convert]::ToBase64String($Stream.ToArray())
    $Stream.Dispose()

    return $Encoded
}

function Set-Armed {
    param($Marker)

    $Picture = Get-ClipboardImage

    if (-not $Picture) {
        $script:Seen = [ClipboardSequence]::GetClipboardSequenceNumber()
        return "noimage"
    }

    if ((Get-ClipboardText) -eq $Marker) {
        $Picture.Dispose()
        $script:Seen = [ClipboardSequence]::GetClipboardSequenceNumber()
        return "already"
    }

    $Bundle = New-Object System.Windows.Forms.DataObject
    $Bundle.SetImage($Picture)
    $Bundle.SetText($Marker)
    Set-PrivateClipboard $Bundle
    $script:Seen = [ClipboardSequence]::GetClipboardSequenceNumber()
    $Encoded = Get-Png $Picture
    $Picture.Dispose()

    return "armed`t$Encoded"
}

function Set-Disarmed {
    param($Marker)

    if ((Get-ClipboardText) -ne $Marker) {
        return "notours"
    }

    $Picture = Get-ClipboardImage

    if (-not $Picture) {
        return "noimage"
    }

    $Bundle = New-Object System.Windows.Forms.DataObject
    $Bundle.SetImage($Picture)
    Set-PrivateClipboard $Bundle
    $Picture.Dispose()

    return "disarmed"
}

function Get-Read {
    $Picture = Get-ClipboardImage

    if (-not $Picture) {
        return "none"
    }

    $Encoded = Get-Png $Picture
    $Picture.Dispose()

    return $Encoded
}

while ($null -ne ($Line = [Console]::In.ReadLine())) {
    $Parts = $Line.Split("`t", 2)
    $Marker = if ($Parts.Count -gt 1) { $Parts[1] } else { "" }

    try {
        $Answer = switch ($Parts[0]) {
            "arm" { Set-Armed $Marker }
            "check" { if ([ClipboardSequence]::GetClipboardSequenceNumber() -eq $Seen) { "same" } else { Set-Armed $Marker } }
            "disarm" { Set-Disarmed $Marker }
            "read" { Get-Read }
            default { "ready" }
        }
    } catch {
        $Answer = "failed"
    }

    [Console]::Out.WriteLine($Answer)
    [Console]::Out.Flush()
}