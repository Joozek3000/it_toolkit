# Clean Old User Profiles Script

Write-Output "Cleaning old user profiles..."

$cutoff = (Get-Date).AddDays(-60)

Get-WmiObject Win32_UserProfile | Where-Object {
    $_.LocalPath -notlike "*Administrator*" -and
    $_.LastUseTime -lt $cutoff.ToFileTime()
} | ForEach-Object {
    Write-Output "Deleting profile: $($_.LocalPath)"
    $_.Delete()
}

Write-Output "Old user profiles cleaned."
