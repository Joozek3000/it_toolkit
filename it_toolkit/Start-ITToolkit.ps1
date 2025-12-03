# Start-ITToolkit.ps1
# Launcher for the ITToolkit module

# Force UTF-8 before anything loads to keep banner characters intact
try {
    chcp 65001 > $null
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    Write-Verbose "UTF-8 setup failed: $($_.Exception.Message)"
}

Import-Module "$PSScriptRoot\ITToolkit\ITToolkit.psm1" -Force -DisableNameChecking
. "$PSScriptRoot\ITToolkit\ITToolkit_CLI.ps1"
Invoke-ITToolkit
