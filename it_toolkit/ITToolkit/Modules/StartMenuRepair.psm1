# Start Menu repair module

<#
.SYNOPSIS
Attempts to repair the Windows Start Menu experience.
.DESCRIPTION
Re-registers the Start Menu Experience Host package and restarts Explorer if requested.
.PARAMETER RestartExplorer
When set, restarts explorer.exe after package reset.
.EXAMPLE
Invoke-ITT-StartMenuRepair -RestartExplorer -WhatIf
Shows planned actions without executing.
#>
function Invoke-ITT-StartMenuRepair {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$RestartExplorer
    )

    $packageName = "Microsoft.Windows.StartMenuExperienceHost"
    Write-Verbose "StartMenuRepair: targeting package $packageName"

    if ($PSCmdlet.ShouldProcess("Start Menu Experience Host", "Reset package")) {
        try {
            Get-AppxPackage -Name $packageName -AllUsers | Reset-AppxPackage -ErrorAction Stop
            Write-Host "Start Menu package reset triggered." -ForegroundColor Green
        } catch {
            Write-Host "Failed to reset Start Menu package: $($_.Exception.Message)" -ForegroundColor Red
            Write-Verbose "StartMenuRepair reset error: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Start Menu repair skipped." -ForegroundColor Yellow
    }

    if ($RestartExplorer -and $PSCmdlet.ShouldProcess("explorer.exe", "Restart")) {
        try {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Process explorer.exe
            Write-Host "Explorer restarted." -ForegroundColor Green
        } catch {
            Write-Host "Failed to restart Explorer: $($_.Exception.Message)" -ForegroundColor Red
            Write-Verbose "StartMenuRepair explorer restart error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Invoke-ITT-StartMenuRepair
