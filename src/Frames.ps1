param([string]$Video, [string]$OutFolder, [string]$Seconds)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Editing.MediaComposition, Windows.Media.Editing, ContentType = WindowsRuntime]
$null = [Windows.Media.Editing.MediaClip, Windows.Media.Editing, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]

$AsTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

function Await($Operation, [Type]$ResultType) {
    $Task = $AsTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $Task.Wait() | Out-Null
    $Task.Result
}

$File = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Video)) ([Windows.Storage.StorageFile])
$Clip = Await ([Windows.Media.Editing.MediaClip]::CreateFromFileAsync($File)) ([Windows.Media.Editing.MediaClip])
$Composition = New-Object Windows.Media.Editing.MediaComposition

[System.Collections.Generic.ICollection[Windows.Media.Editing.MediaClip]].GetMethod("Add").Invoke($Composition.Clips, @($Clip)) | Out-Null

$Length = $Composition.Duration.TotalSeconds
"length $Length"

$Index = 0

foreach ($Text in ($Seconds -split ",")) {
    $At = [math]::Min([math]::Max([double]::Parse($Text, [Globalization.CultureInfo]::InvariantCulture), 0), [math]::Max($Length - 0.01, 0))
    $Stream = Await ($Composition.GetThumbnailAsync([TimeSpan]::FromSeconds($At), 0, 0, [Windows.Media.Editing.VideoFramePrecision]::NearestFrame)) ([Windows.Graphics.Imaging.ImageStream])
    $Path = Join-Path $OutFolder ("frame_{0:D3}.jpg" -f $Index)
    $Reader = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($Stream)
    $Out = [System.IO.File]::Create($Path)

    try {
        $Reader.CopyTo($Out)
    } finally {
        $Out.Close()
        $Reader.Close()
    }

    $Path
    $Index += 1
}
