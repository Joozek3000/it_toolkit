# OneDrive tools module

<#
.SYNOPSIS
Resets and restarts the OneDrive client.
.DESCRIPTION
Stops OneDrive, optionally clears the client cache, and restarts the executable if found.
.PARAMETER ClearCache
When specified, clears the OneDrive cache folder before restart.
.EXAMPLE
Invoke-ITT-OneDriveRepair -WhatIf
Shows the actions that would be taken.
#>
function Invoke-ITT-OneDriveRepair {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$ClearCache
    )

    $exePath    = Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive\OneDrive.exe"
    $cachePath  = Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive"

    Write-Verbose "OneDriveRepair: exe path $exePath"
    Write-Verbose "OneDriveRepair: cache path $cachePath"

    if ($PSCmdlet.ShouldProcess("OneDrive client", "Stop and restart")) {
        try { Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "Stop-Process OneDrive: $($_.Exception.Message)" }

        if ($ClearCache -and (Test-Path $cachePath)) {
            Write-Verbose "Clearing OneDrive cache at $cachePath"
            try { Remove-Item (Join-Path $cachePath '*') -Recurse -Force -ErrorAction Stop } catch { Write-Verbose "Clear cache failed: $($_.Exception.Message)" }
        }

        if (Test-Path $exePath) {
            try {
                Start-Process $exePath -ErrorAction Stop
                Write-Host "OneDrive restarted." -ForegroundColor Green
            } catch {
                Write-Host "Failed to start OneDrive: $($_.Exception.Message)" -ForegroundColor Red
                Write-Verbose "OneDrive start error: $($_.Exception.Message)"
            }
        } else {
            Write-Host "OneDrive executable not found at $exePath" -ForegroundColor Yellow
        }
    } else {
        Write-Host "OneDrive repair skipped." -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Invoke-ITT-OneDriveRepair
