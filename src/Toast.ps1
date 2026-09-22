$ErrorActionPreference = "Stop"

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$Escape = { param($Text) [System.Security.SecurityElement]::Escape($Text) }
$Title = & $Escape $env:CLAUDIO_TITLE
$Body = & $Escape $env:CLAUDIO_BODY
$Icon = & $Escape ("file:///" + ($env:CLAUDIO_ICON -replace "\\", "/"))

$Xml = @"
<toast scenario="reminder">
  <visual>
    <binding template="ToastGeneric">
      <image placement="appLogoOverride" src="$Icon"/>
      <text>$Title</text>
      <text>$Body</text>
    </binding>
  </visual>
  <audio silent="true"/>
  <actions>
    <action content="Dismiss" arguments="dismiss" activationType="system"/>
  </actions>
</toast>
"@

$Document = New-Object Windows.Data.Xml.Dom.XmlDocument
$Document.LoadXml($Xml)

$Toast = New-Object Windows.UI.Notifications.ToastNotification $Document
$Toast.Tag = "claudio-" + [guid]::NewGuid().ToString("N").Substring(0, 12)
$Toast.Group = "claudio"

$Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($env:CLAUDIO_APP_ID)
$Notifier.Show($Toast)

[Console]::Out.WriteLine("shown")
[Console]::Out.Flush()

$Seconds = [double]$env:CLAUDIO_TOAST_SECONDS

if ($Seconds -gt 0) {
    Start-Sleep -Seconds $Seconds
    [Windows.UI.Notifications.ToastNotificationManager]::History.Remove($Toast.Tag, $Toast.Group, $env:CLAUDIO_APP_ID)
}