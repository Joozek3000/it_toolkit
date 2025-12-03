# Windows Update advanced tools module

<#
.SYNOPSIS
Runs an advanced Windows Update reset workflow.
.DESCRIPTION
Invokes the existing core Windows Update reset function if available; provides verbose routing and ShouldProcess control.
.EXAMPLE
Invoke-ITT-WindowsUpdateAdvancedReset -Verbose
Triggers advanced reset with verbose output.
#>
function Invoke-ITT-WindowsUpdateAdvancedReset {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $target = "Advanced Windows Update reset"
    if (-not (Get-Command Invoke-ITT-ResetWindowsUpdate -ErrorAction SilentlyContinue)) {
        Write-Host "Windows Update reset function not available." -ForegroundColor Yellow
        return
    }

    if ($PSCmdlet.ShouldProcess($target, "Invoke advanced reset pipeline")) {
        Write-Verbose "Calling Invoke-ITT-ResetWindowsUpdate (advanced wrapper)."
        try {
            Invoke-ITT-ResetWindowsUpdate
        } catch {
            Write-Host "Advanced Windows Update reset failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Verbose "WindowsUpdateAdvancedReset error: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Advanced Windows Update reset skipped." -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Invoke-ITT-WindowsUpdateAdvancedReset
