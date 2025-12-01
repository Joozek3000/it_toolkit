# Install Microsoft Teams

$installer = "teams.exe"
$url = "https://statics.teams.cdn.office.net/production-windows-x64/Teams_windows_x64.exe"

Write-Output "Downloading Microsoft Teams..."
Invoke-WebRequest -Uri $url -OutFile $installer

Write-Output "Installing Teams..."
Start-Process $installer -ArgumentList "-s" -Wait

Remove-Item $installer -Force
Write-Output "Teams installed successfully."
