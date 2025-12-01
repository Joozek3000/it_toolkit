Write-Output "Removing Teams (All Users)..."

# Remove new Teams
Get-AppxPackage -AllUsers *MSTeams* |
    Remove-AppxPackage -ErrorAction SilentlyContinue

Get-AppxProvisionedPackage -Online |
    Where-Object { $_.DisplayName -Like "*MSTeams*" } |
    Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

Write-Output "Downloading latest Teams installer..."
$Installer = "$env:TEMP\TeamsInstall.exe"
Invoke-WebRequest "https://aka.ms/teams32bitmsi" -OutFile $Installer

Write-Output "Installing Teams..."
Start-Process $Installer -ArgumentList "-s" -Wait

Write-Output "Teams reinstalled successfully."
