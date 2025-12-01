# Clear Windows Update Cache Script (fixes Windows Update issues)

Write-Output "Stopping Windows Update services..."

Stop-Service wuauserv -Force
Stop-Service bits -Force

Write-Output "Clearing Update cache folder..."
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Force -Recurse -ErrorAction SilentlyContinue

Write-Output "Starting Windows Update services..."
Start-Service wuauserv
Start-Service bits

Write-Output "Windows Update cache cleared."
