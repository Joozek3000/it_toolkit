# Teams tools module

<#
.SYNOPSIS
Resets Microsoft Teams cache and restarts the client.
.DESCRIPTION
Stops Teams processes, clears cache folders when requested, and relaunches Teams if installed.
.PARAMETER ClearCache
When set, clears Teams cache directories under AppData.
.EXAMPLE
Invoke-ITT-TeamsRepair -WhatIf
Shows planned actions.
#>
function Invoke-ITT-TeamsRepair {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$ClearCache
    )

    $teamsExe   = Join-Path $env:LOCALAPPDATA "Microsoft\Teams\Update.exe"
    $appRoot    = Join-Path $env:APPDATA "Microsoft\Teams"
    $cachePaths = @($appRoot, (Join-Path $env:APPDATA "Microsoft\TeamsMeetingAddin"))

    Write-Verbose "TeamsRepair: update exe $teamsExe"
    Write-Verbose "TeamsRepair: cache roots $($cachePaths -join ', ')"

    if ($PSCmdlet.ShouldProcess("Microsoft Teams", "Stop, clear cache, restart")) {
        try { Stop-Process -Name "Teams","ms-teams","ms-teamsupdate" -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "Stop-Process Teams: $($_.Exception.Message)" }

        if ($ClearCache) {
            foreach ($path in $cachePaths) {
                if (Test-Path $path) {
                    Write-Verbose "Clearing Teams cache at $path"
                    try { Remove-Item (Join-Path $path '*') -Recurse -Force -ErrorAction Stop } catch { Write-Verbose "Clear cache failed at $path : $($_.Exception.Message)" }
                }
            }
        }

        if (Test-Path $teamsExe) {
            try {
                Start-Process $teamsExe -ArgumentList "--processStart `"Teams.exe`"" -ErrorAction Stop
                Write-Host "Teams restart triggered." -ForegroundColor Green
            } catch {
                Write-Host "Failed to restart Teams: $($_.Exception.Message)" -ForegroundColor Red
                Write-Verbose "Teams start error: $($_.Exception.Message)"
            }
        } else {
            Write-Host "Teams Update.exe not found at $teamsExe" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Teams repair skipped." -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Invoke-ITT-TeamsRepair
