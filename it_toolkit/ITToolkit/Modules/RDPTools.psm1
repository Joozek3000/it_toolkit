# RDP tools module

<#
.SYNOPSIS
Cleans RDP cache/history and launches MSTSC.
.DESCRIPTION
Clears Terminal Server Client cache files under AppData and opens Remote Desktop Connection if requested.
.PARAMETER LaunchClient
When set, launches mstsc.exe after cleanup.
.EXAMPLE
Invoke-ITT-RDPCacheCleanup -LaunchClient -WhatIf
Shows planned actions.
#>
function Invoke-ITT-RDPCacheCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$LaunchClient
    )

    $cachePaths = @(
        Join-Path $env:APPDATA "Microsoft\Terminal Server Client\Cache",
        Join-Path $env:APPDATA "Microsoft\Terminal Server Client\Default.rdp"
    )

    if ($PSCmdlet.ShouldProcess("RDP cache", "Clear cached connections")) {
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                Write-Verbose "Clearing RDP cache at $path"
                try {
                    if (Test-Path $path -PathType Container) {
                        Remove-Item (Join-Path $path '*') -Recurse -Force -ErrorAction Stop
                    } else {
                        Remove-Item $path -Force -ErrorAction Stop
                    }
                } catch {
                    Write-Verbose "RDP cache clear failed at $path : $($_.Exception.Message)"
                }
            } else {
                Write-Verbose "RDP cache path missing: $path"
            }
        }
        Write-Host "RDP cache cleanup complete." -ForegroundColor Green
    } else {
        Write-Host "RDP cache cleanup skipped." -ForegroundColor Yellow
    }

    if ($LaunchClient) {
        if ($PSCmdlet.ShouldProcess("mstsc.exe", "Launch RDP client")) {
            try { Start-Process mstsc.exe -ErrorAction Stop } catch { Write-Host "Failed to launch mstsc.exe: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
}

Export-ModuleMember -Function Invoke-ITT-RDPCacheCleanup
