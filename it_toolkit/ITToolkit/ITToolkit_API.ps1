# ITToolkit_API.ps1
# API layer for future Python GUI/SDK integration.
# Rules: API functions return structured objects, do not write to host, and wrap module functions.
# Future Python bindings will call these via subprocess/Remoting/SDK and parse returned objects.

Import-Module "$PSScriptRoot\ITToolkit.psm1" -Force -DisableNameChecking

<#!
.SYNOPSIS
Runs hardware inventory via ITToolkit and reports status.
.DESCRIPTION
Calls Invoke-ITT-HardwareInventory and returns a status object. Host output from the underlying function is not suppressed.
#>
function Invoke-ITTAPI-HardwareInventory {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{
        Action  = 'HardwareInventory'
        Success = $false
        Error   = $null
    }
    try {
        Invoke-ITT-HardwareInventory | Out-Null
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

<#!
.SYNOPSIS
Runs an ITToolkit diagnostic scan.
.DESCRIPTION
Wraps Invoke-ITT-DiagnosticScan with the specified mode and returns a status object.
.PARAMETER Mode
Scan mode: Safe, Standard, Aggressive.
#>
function Invoke-ITTAPI-DiagnosticScan {
    [CmdletBinding()]
    param(
        [ValidateSet('Safe','Standard','Aggressive')]
        [string]$Mode = 'Safe'
    )
    $result = [pscustomobject]@{
        Action  = 'DiagnosticScan'
        Mode    = $Mode
        Success = $false
        Error   = $null
    }
    try {
        Invoke-ITT-DiagnosticScan -Mode $Mode | Out-Null
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

<#!
.SYNOPSIS
Runs network reset via ITToolkit.
.DESCRIPTION
Wraps Invoke-ITT-ResetNetwork and returns a status object.
#>
function Invoke-ITTAPI-ResetNetwork {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{
        Action  = 'ResetNetwork'
        Success = $false
        Error   = $null
    }
    try {
        Invoke-ITT-ResetNetwork | Out-Null
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

<#!
.SYNOPSIS
Runs print spooler reset.
.DESCRIPTION
Wraps Invoke-ITT-ResetPrintSpooler and returns a status object.
#>
function Invoke-ITTAPI-ResetPrintSpooler {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{
        Action  = 'ResetPrintSpooler'
        Success = $false
        Error   = $null
    }
    try {
        Invoke-ITT-ResetPrintSpooler | Out-Null
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

<#!
.SYNOPSIS
Runs Office repair (CTR) and browser repair combo.
.DESCRIPTION
Wraps Invoke-ITT-RepairOffice and Invoke-ITT-RepairBrowsers; returns status object.
#>
function Invoke-ITTAPI-RepairOfficeAndBrowsers {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{
        Action  = 'RepairOfficeAndBrowsers'
        Success = $false
        Error   = $null
    }
    try {
        Invoke-ITT-RepairOffice | Out-Null
        Invoke-ITT-RepairBrowsers | Out-Null
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

<#!
.SYNOPSIS
Collects a full log bundle.
.DESCRIPTION
Wraps Invoke-ITT-CollectFullLogBundle and returns status object with output path if available.
#>
function Invoke-ITTAPI-CollectFullLogBundle {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{
        Action  = 'CollectFullLogBundle'
        Success = $false
        Error   = $null
        Path    = $null
    }
    try {
        Invoke-ITT-CollectFullLogBundle | Out-Null
        # Underlying function reports path to console; leave Path null for now.
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

<#!
.SYNOPSIS
Resets OneDrive via Profiles module.
.DESCRIPTION
Wraps Invoke-ITT-ResetOneDrive and returns status object.
#>
function Invoke-ITTAPI-ResetOneDrive {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{
        Action  = 'ResetOneDrive'
        Success = $false
        Error   = $null
    }
    try {
        Invoke-ITT-ResetOneDrive | Out-Null
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

Export-ModuleMember -Function 'Invoke-ITTAPI-*'
