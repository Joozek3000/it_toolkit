# Restart Windows Update Services Script (fixes Windows Update issues)

Write-Output "Restarting Windows Update services..."

$services = @(
    "wuauserv",
    "bits",
    "cryptsvc",
    "msiserver"
)

foreach ($s in $services) {
    try {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Start-Service -Name $s -ErrorAction SilentlyContinue
        Write-Output "Restarted: $s"
    } catch {
        Write-Output "Failed: $s"
    }
}

Write-Output "Windows Update services restarted."
