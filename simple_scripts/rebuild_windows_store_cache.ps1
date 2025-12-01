# Rebuild Windows Store Cache Script (fixes Windows Store and app installation issues)

Write-Output "Resetting Windows Store cache..."
wsreset.exe -i
Write-Output "Windows Store cache reset complete."
