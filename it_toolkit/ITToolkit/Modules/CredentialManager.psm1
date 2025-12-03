# Credential Manager tools module

<#
.SYNOPSIS
Audits and optionally clears stored Windows Credentials.
.DESCRIPTION
Lists current user credentials via cmdkey; when -ClearAll is specified and confirmed, removes them using cmdkey /delete.
.PARAMETER ClearAll
When set, removes all listed credentials (subject to ShouldProcess).
.EXAMPLE
Invoke-ITT-CredentialManagerAudit -ClearAll -WhatIf
Shows planned deletions without executing.
#>
function Invoke-ITT-CredentialManagerAudit {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$ClearAll
    )

    Write-Verbose "CredentialManagerAudit: listing credentials via cmdkey /list"
    $output = cmdkey /list 2>$null
    if (-not $output) {
        Write-Host "No credentials found or cmdkey unavailable." -ForegroundColor Yellow
        return
    }

    Write-Host "Stored credentials:" -ForegroundColor Cyan
    $output | ForEach-Object { Write-Host "  $_" }

    if (-not $ClearAll) {
        Write-Host "Use -ClearAll to remove all listed credentials (with confirmation)." -ForegroundColor DarkGray
        return
    }

    if ($PSCmdlet.ShouldProcess("Credential Manager entries", "Delete all")) {
        Write-Verbose "CredentialManagerAudit: clearing all credentials"
        # cmdkey /list output contains "Target: XXX"; extract targets
        $targets = ($output | Where-Object { $_ -match 'Target:' }) -replace 'Target:\s*',''
        foreach ($t in $targets) {
            if ([string]::IsNullOrWhiteSpace($t)) { continue }
            try {
                cmdkey /delete:$t 2>$null | Out-Null
                Write-Host "Deleted credential: $t" -ForegroundColor Yellow
            } catch {
                Write-Verbose "Failed to delete credential $t : $($_.Exception.Message)"
            }
        }
        Write-Host "Credential cleanup complete." -ForegroundColor Green
    } else {
        Write-Host "Credential cleanup skipped." -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Invoke-ITT-CredentialManagerAudit
