# Repair WMI Script

Write-Output "Repairing WMI..."

Stop-Service winmgmt -Force

winmgmt /salvagerepository
winmgmt /resetrepository

Start-Service winmgmt

Write-Output "WMI repaired."
