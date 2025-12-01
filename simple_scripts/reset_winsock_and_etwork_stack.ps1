# Reset Winsock and IP Stack Script (Fixes internet “connected but no internet” and Teams/Zoom issues.)

Write-Output "Resetting Winsock and IP Stack..."

netsh winsock reset
netsh int ip reset

Write-Output "Network stack reset. A restart may be required."

