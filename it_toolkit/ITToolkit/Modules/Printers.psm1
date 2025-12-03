# Printer tools module

<#!
.SYNOPSIS
Resets the print spooler and clears queued jobs.
.DESCRIPTION
Stops the spooler service, clears the PRINTERS queue if it exists, then restarts the service.
#>
function Invoke-ITT-ResetPrintSpooler {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Host ""
    Write-Host "=== Resetting Print Spooler and Clearing Queue ===" -ForegroundColor Cyan

    $spoolPath = "C:\Windows\System32\spool\PRINTERS"

    if (-not $PSCmdlet.ShouldProcess("Print Spooler service", "Stop, clear queue, start")) {
        Write-Host "Print spooler reset skipped." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Stopping Print Spooler service..." -ForegroundColor Yellow
        Stop-Service -Name spooler -Force -ErrorAction Stop
        try { Wait-Service -Name spooler -Status Stopped -Timeout 10 } catch {}

        if (Test-Path $spoolPath) {
            Write-Host "Clearing queued print jobs at $spoolPath" -ForegroundColor Yellow
            try {
                Remove-Item (Join-Path $spoolPath '*') -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Verbose "Invoke-ITT-ResetPrintSpooler: failed to clear $spoolPath : $($_.Exception.Message)"
            }
        } else {
            Write-Host "Spool directory not found at $spoolPath" -ForegroundColor Yellow
            Write-Verbose "Invoke-ITT-ResetPrintSpooler: spool path missing $spoolPath"
            try {
                New-Item -ItemType Directory -Path $spoolPath -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {
                Write-Verbose "Invoke-ITT-ResetPrintSpooler: failed to recreate $spoolPath : $($_.Exception.Message)"
            }
        }

        Write-Host "Starting Print Spooler service..." -ForegroundColor Yellow
        Start-Service -Name spooler -ErrorAction Stop
        try { Wait-Service -Name spooler -Status Running -Timeout 10 } catch {}

        Write-Host "Print spooler reset complete." -ForegroundColor Green
    } catch {
        Write-Host "Failed to reset print spooler: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Invoke-ITT-ResetPrintSpooler error: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Invoke-ITT-ResetPrintSpooler
