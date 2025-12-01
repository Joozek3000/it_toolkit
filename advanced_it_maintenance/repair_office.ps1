# Repair Office Click-to-Run Script

Write-Output "Repairing Office Click-to-Run..."

$office = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"

if (Test-Path $office) {
    Start-Process $office -ArgumentList "scenario=Repair" -Wait
    Write-Output "Office repair initiated."
} else {
    Write-Output "Office not found on this system."
}
