# Chrome / Edge repair module

<#
.SYNOPSIS
Performs lightweight repair steps for Chromium-based browsers (Edge/Chrome).
.DESCRIPTION
Clears cache folders when requested and can trigger the browser repair/reinstall page for Edge.
.PARAMETER ClearCache
When set, clears user cache for Edge and Chrome.
.PARAMETER OpenEdgeRepair
When set, opens the Edge download/repair page.
.EXAMPLE
Invoke-ITT-ChromeEdgeRepair -ClearCache -WhatIf
Shows planned actions.
#>
function Invoke-ITT-ChromeEdgeRepair {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$ClearCache,
        [switch]$OpenEdgeRepair
    )

    $edgeCache   = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Cache"
    $chromeCache = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Cache"
    $targets     = @($edgeCache, $chromeCache)

    if ($ClearCache -and $PSCmdlet.ShouldProcess("Edge/Chrome cache", "Clear browser cache folders")) {
        foreach ($path in $targets) {
            if (Test-Path $path) {
                Write-Verbose "Clearing cache at $path"
                try { Remove-Item (Join-Path $path '*') -Recurse -Force -ErrorAction Stop } catch { Write-Verbose "Cache clear failed at $path : $($_.Exception.Message)" }
            } else {
                Write-Verbose "Cache path missing: $path"
            }
        }
        Write-Host "Browser cache cleared (Edge/Chrome where present)." -ForegroundColor Green
    } elseif ($ClearCache) {
        Write-Host "Browser cache clear skipped." -ForegroundColor Yellow
    }

    if ($OpenEdgeRepair) {
        $url = "https://www.microsoft.com/edge/download"
        if ($PSCmdlet.ShouldProcess("Edge download site", "Open browser repair/download page")) {
            try { Start-Process $url -ErrorAction Stop; Write-Verbose "Opened Edge download page $url" } catch { Write-Host "Failed to open Edge download page: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }

    if (-not $ClearCache -and -not $OpenEdgeRepair) {
        Write-Host "No actions requested. Use -ClearCache and/or -OpenEdgeRepair." -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Invoke-ITT-ChromeEdgeRepair
