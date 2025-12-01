# Empty Recycle Bin Script (frees up disk space by emptying the Recycle Bin)

Write-Output "Emptying Recycle Bin..."
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Write-Output "Recycle Bin emptied."
