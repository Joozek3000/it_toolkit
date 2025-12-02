# Start-ITToolkit.ps1
# Launcher for the ITToolkit module

Import-Module "$PSScriptRoot\ITToolkit\ITToolkit.psm1" -Force -DisableNameChecking
. "$PSScriptRoot\ITToolkit\ITToolkit_CLI.ps1"
Invoke-ITToolkit
