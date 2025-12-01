# Fixes almost every printer problem.

Write-Output "Restarting Print Spooler..."

Stop-Service -Name spooler -Force
Start-Service -Name spooler

Write-Output "Print Spooler restarted successfully."
