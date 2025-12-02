# Cleanup and storage tools module

<#!
.SYNOPSIS
Removes the Windows.old folder.
.DESCRIPTION
Checks for Windows.old, prompts for confirmation, deletes it if present.
#>
function Invoke-ITT-RemoveWindowsOld {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    $path = "C:\Windows.old"
    if (-not (Test-Path $path)) {
        Write-Host "No Windows.old folder found." -ForegroundColor Yellow
        Write-Verbose "Invoke-ITT-RemoveWindowsOld: path not found $path"
        return
    }

    $sizeBytes = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $sizeGB    = [Math]::Round($sizeBytes / 1GB, 2)

    Write-Host ""
    Write-Host "Windows.old detected at $path (~$sizeGB GB)." -ForegroundColor Cyan
    Write-Host "This folder is only needed to roll back to the previous Windows version." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Do you want to remove Windows.old using manual delete?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    if (-not $PSCmdlet.ShouldProcess($path, "Delete Windows.old folder")) {
        Write-Host "Operation skipped." -ForegroundColor Yellow
        return
    }

    try {
        Write-Verbose "Invoke-ITT-RemoveWindowsOld: removing $path"
        Write-Progress -Activity "Removing Windows.old" -Status "Deleting files..." -PercentComplete 0
        Remove-Item $path -Recurse -Force -ErrorAction Stop
        Write-Progress -Activity "Removing Windows.old" -Completed
        Write-Host "Windows.old removed successfully." -ForegroundColor Green
    } catch {
        Write-Progress -Activity "Removing Windows.old" -Completed
        Write-Host "Failed to remove Windows.old: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Consider using Disk Cleanup / Storage Sense instead." -ForegroundColor Yellow
        Write-Verbose "Invoke-ITT-RemoveWindowsOld failed: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Performs system cleanup of temp/log/update cache locations.
.DESCRIPTION
Prompts for confirmation, clears several known temp/log folders, and reports freed space.
#>
function Invoke-ITT-SystemCleanup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Host ""
    Write-Host "=== System Cleanup (logs, temp, cache) ===" -ForegroundColor Cyan

    if (-not (Invoke-ITT-AskYesNo "Proceed with system cleanup?")) {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        return
    }

    $paths = @(
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Logs",
        "$env:SystemRoot\SoftwareDistribution\Download",
        "$env:SystemRoot\System32\LogFiles",
        "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
        "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
    )

    $before = (Get-PSDrive C).Free

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Write-Host "Cleaning $p" -ForegroundColor Gray
            try {
                if ($PSCmdlet.ShouldProcess($p, "Remove contents")) {
                    Remove-Item (Join-Path $p '*') -Recurse -Force -ErrorAction Stop
                }
            } catch {
                Write-Verbose "Invoke-ITT-SystemCleanup: failed to clean $p : $($_.Exception.Message)"
            }
        } else {
            Write-Verbose "Invoke-ITT-SystemCleanup: path not found $p"
        }
    }

    $after    = (Get-PSDrive C).Free
    $diffGB   = [Math]::Round(($after - $before) / 1GB, 2)
    Write-Host ""
    Write-Host "System cleanup complete. Freed approximately $diffGB GB." -ForegroundColor Green
}

<#!
.SYNOPSIS
Reports common startup impact sources.
.DESCRIPTION
Lists registry Run entries and Startup folder items for review.
#>
function Invoke-ITT-StartupImpactReport {
    Write-Host ""
    Write-Host "=== Startup Impact Report ===" -ForegroundColor Cyan
    Write-Host "Listing common startup entries (registry + Startup folders)." -ForegroundColor Yellow
    Write-Host ""

    $runPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    Write-Host "--- Registry Startup (Run) ---" -ForegroundColor Cyan
    foreach ($path in $runPaths) {
        if (Test-Path $path) {
            Write-Host "[$path]" -ForegroundColor Gray
            Get-ItemProperty $path | Select-Object * | ForEach-Object {
                $_.PSObject.Properties |
                    Where-Object { $_.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider' } |
                    ForEach-Object {
                        "{0,-30} : {1}" -f $_.Name, $_.Value | Write-Host
                    }
            }
            Write-Host ""
        } else {
            Write-Verbose "Invoke-ITT-StartupImpactReport: registry path not found $path"
        }
    }

    Write-Host "--- Startup Folder (per user) ---" -ForegroundColor Cyan
    $startupUser = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $startupUser) {
        Get-ChildItem $startupUser | Select-Object Name, FullName | Format-Table
    } else {
        Write-Host "No user Startup folder items." -ForegroundColor Gray
        Write-Verbose "Invoke-ITT-StartupImpactReport: startup folder missing $startupUser"
    }

    Write-Host ""
    Write-Host "Review high-impact items and disable via Task Manager or msconfig as needed." -ForegroundColor Green
}

Export-ModuleMember -Function Invoke-ITT-RemoveWindowsOld,Invoke-ITT-SystemCleanup,Invoke-ITT-StartupImpactReport
