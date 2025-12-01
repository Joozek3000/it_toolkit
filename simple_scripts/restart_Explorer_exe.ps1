# Restart Explorer.exe Script (fixes taskbar and start menu issues)

Write-Output "Restarting Explorer.exe..."
Stop-Process -Name explorer -Force
Start-Process explorer.exe
Write-Output "Explorer restarted."
