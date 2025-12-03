# ITToolkit.psm1
# Root module loader (imports only)
$Global:ITT_ScriptsRoot = "C:\Scripts2"

Import-Module (Join-Path $PSScriptRoot "Modules\Core.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Outlook.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Office.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Windows.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Network.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Cleanup.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Profiles.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Printers.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\OneDrive.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\Teams.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\WindowsUpdateAdvanced.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\CredentialManager.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\StartMenuRepair.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\RDPTools.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "Modules\ChromeEdgeRepair.psm1") -Force -DisableNameChecking

Export-ModuleMember -Function 'Invoke-ITT-*'
