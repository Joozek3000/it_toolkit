# Flush DNS Cache Script (fixes most network issues

Write-Output "Flushing DNS..."
ipconfig /flushdns
Write-Output "DNS flushed successfully."
