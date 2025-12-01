# Reset Windows Update Components Script

Write-Output "Stopping services..."

$services = "wuauserv","cryptSvc","bits","msiserver"
foreach ($s in $services) { Stop-Service $s -Force -ErrorAction SilentlyContinue }

Write-Output "Renaming corrupted folders..."
Rename-Item "C:\Windows\SoftwareDistribution" "SoftwareDistribution.old" -ErrorAction SilentlyContinue
Rename-Item "C:\Windows\System32\catroot2" "catroot2.old" -ErrorAction SilentlyContinue

Write-Output "Restarting services..."
foreach ($s in $services) { Start-Service $s -ErrorAction SilentlyContinue }

Write-Output "Windows Update components reset."
