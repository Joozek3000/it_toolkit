# Full Windows Repair Script

Write-Output "Starting Windows repair (SFC + DISM)..."

DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow

Write-Output "Windows repair completed."
