Write-Output "Downloading Google Chrome..."

$InstallerPath = "$env:TEMP\chrome.msi"
$DownloadUrl   = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing

Write-Output "Installing Google Chrome silently..."

Start-Process "msiexec.exe" -ArgumentList "/i `"$InstallerPath`" /qn /norestart" -Wait

Write-Output "Cleaning up installer..."
Remove-Item $InstallerPath -Force

Write-Output "Google Chrome installation complete."
