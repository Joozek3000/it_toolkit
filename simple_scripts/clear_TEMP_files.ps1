# Clear TEMP files from common TEMP directories

Write-Output "Clearing TEMP folders..."

$paths = @(
    "$env:TEMP\*",
    "$env:TMP\*",
    "$env:windir\Temp\*",
    "C:\Windows\Temp\*"
)

foreach ($p in $paths) {
    try {
        Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Cleared: $p"
    } catch {
        Write-Output "Failed to clear: $p"
    }
}

Write-Output "TEMP cleanup complete."
