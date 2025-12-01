# Restart Audio Services Script (fixes audio issues)

Write-Output "Restarting audio services..."

$services = @(
    "Audiosrv",      # Windows Audio
    "AudioEndpointBuilder"
)

foreach ($s in $services) {
    try {
        Restart-Service -Name $s -Force
        Write-Output "Restarted: $s"
    } catch {
        Write-Output "Failed: $s"
    }
}

Write-Output "Audio services restarted."
