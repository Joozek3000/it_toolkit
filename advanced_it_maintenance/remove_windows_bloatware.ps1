# Remove Windows Bloatware Script

Write-Output "Removing safe bloatware apps..."

$apps = @(
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.XboxApp",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxGameCallableUI",
    "Microsoft.GamingApp",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MixedReality.Portal",
    "Microsoft.MicrosoftOfficeHub"
)

foreach ($app in $apps) {
    Write-Output "Removing: $app"
    Get-AppxPackage -AllUsers $app | Remove-AppxPackage -ErrorAction SilentlyContinue
}

Write-Output "Bloatware removal completed."
