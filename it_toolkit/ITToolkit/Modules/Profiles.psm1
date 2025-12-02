# Profiles and user data tools module

<#!
.SYNOPSIS
Resets the OneDrive client for the current user.
.DESCRIPTION
Stops running OneDrive processes, runs the reset switch, then restarts OneDrive.
#>
function Invoke-ITT-ResetOneDrive {
    Write-Host ""
    Write-Host "=== OneDrive Reset ===" -ForegroundColor Cyan
    Write-Host "This will reset the OneDrive client for the current user." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Proceed with OneDrive reset?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
    )

    $oneDriveExe = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $oneDriveExe) {
        Write-Host "OneDrive executable not found on this system." -ForegroundColor Red
        Write-Verbose "Invoke-ITT-ResetOneDrive: no executable found in expected paths."
        return
    }

    try {
        Write-Host "Stopping running OneDrive instances..." -ForegroundColor Gray
        Stop-Process -Name OneDrive -ErrorAction SilentlyContinue

        Write-Host "Running OneDrive reset..." -ForegroundColor Gray
        & $oneDriveExe "/reset"

        Start-Sleep -Seconds 5
        Write-Host "Starting OneDrive..." -ForegroundColor Gray
        Start-Process $oneDriveExe -ErrorAction Stop

        Write-Host "OneDrive reset triggered. Sync may take a while." -ForegroundColor Green
    } catch {
        Write-Host "OneDrive reset failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Invoke-ITT-ResetOneDrive error: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Invoke-ITT-ResetOneDrive
