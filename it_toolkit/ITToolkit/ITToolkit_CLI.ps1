# ITToolkit_CLI.ps1
# Menu UI layer (no business logic here)

# Ensure main module is loaded
Import-Module "$PSScriptRoot\ITToolkit.psm1" -Force

$ITBanner = @'
██╗████████╗    ████████╗ ██████╗  ██████╗ ██╗     ██╗  ██╗██╗████████╗
██║╚══██╔══╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██║ ██╔╝██║╚══██╔══╝
██║   ██║          ██║   ██║   ██║██║   ██║██║     █████╔╝ ██║   ██║   
██║   ██║          ██║   ██║   ██║██║   ██║██║     ██╔═██╗ ██║   ██║   
██║   ██║          ██║   ╚██████╔╝╚██████╔╝███████╗██║  ██╗██║   ██║   
╚═╝   ╚═╝          ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝   

                               I T   T O O L K I T
'@

<#
.SYNOPSIS
Displays ASCII text with a short glitch/flicker effect.
.DESCRIPTION
Randomizes foreground color and timing across 6-10 frames to give a quick glitch animation.
.PARAMETER Text
ASCII banner text to render.
#>
function Show-GlitchText {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $frames     = Get-Random -Minimum 6 -Maximum 11
    $colors     = @('Cyan','White','Gray','DarkCyan')
    for ($i = 0; $i -lt $frames; $i++) {
        $color = Get-Random -InputObject $colors
        Clear-Host
        Write-Host $Text -ForegroundColor $color
        Start-Sleep -Milliseconds (Get-Random -Minimum 30 -Maximum 91)
    }
}

<#
.SYNOPSIS
Shows a short ASCII spinning cube animation.
.DESCRIPTION
Loops four cube frames twice with a slight delay, clearing the screen each frame.
#>
function Show-SpinningCube {
    $frames = @(
@'
   +----+
  /    /|
 +----+ |
 |    | +
 |    |/
 +----+
'@,
@'
  +----+
 /    /|
+----+ |
|    | +
|    |/
+----+
'@,
@'
 +----+
/    /|
|----|+
|    |/
|    + 
|----+ 
'@,
@'
 +----+
 |    |
 |    |
 |    |
 |    |
 +----+
'@
    )

    for ($loop = 0; $loop -lt 2; $loop++) {
        foreach ($frame in $frames) {
            Clear-Host
            Write-Host $frame
            Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 151)
        }
    }
}

<#
.SYNOPSIS
Renders a reusable menu page and executes selected actions.
.DESCRIPTION
Displays numbered items, validates numeric input, confirms when requested, and invokes scriptblocks or commands.
.PARAMETER Title
Menu title text.
.PARAMETER Items
Array of hashtables defining Key, Label, Action, optional Check, Confirm, Arguments.
.PARAMETER Prompt
Input prompt text.
#>
function Invoke-ITT-MenuPage {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [array]$Items,
        [string]$Prompt = "Select option"
    )

    while ($true) {
        Write-Host ""
        Write-Host "========== $Title ==========" -ForegroundColor Cyan

        $visible = @()
        foreach ($item in $Items) {
            $isAvailable = $true
            if ($item.Check -is [scriptblock]) {
                try { $isAvailable = & $item.Check } catch { $isAvailable = $false }
            }
            if ($isAvailable) {
                $visible += $item
                Write-Host ("{0}) {1}" -f $item.Key, $item.Label)
            }
        }

        $choice = Read-Host $Prompt
        $choiceTrimmed = ($choice).Trim()

        # Allow contextual help inside any menu: e.g., "help network tools"
        if (-not [string]::IsNullOrWhiteSpace($choiceTrimmed) -and $choiceTrimmed -match '^(?i)(help|get-help)\b') {
            $parts = $choiceTrimmed -split '\s+'
            $topicArgs = @()
            if ($parts.Length -gt 1) {
                $topicArgs = $parts[1..($parts.Length - 1)]
            }
            try { Help @topicArgs } catch { Write-Host "Unable to display help: $($_.Exception.Message)" -ForegroundColor Yellow }
            continue
        }

        if ([string]::IsNullOrWhiteSpace($choiceTrimmed) -or ($choiceTrimmed -notmatch '^\d+$')) {
            Write-Host "Invalid selection." -ForegroundColor Yellow
            continue
        }
        $selected = $visible | Where-Object { $_.Key -eq $choiceTrimmed }

        if (-not $selected) {
            Write-Host "Invalid selection." -ForegroundColor Yellow
            continue
        }

        if ($selected.Action -eq "BACK") { return }

        if ($selected.Confirm -and -not (Invoke-ITT-AskYesNo $selected.Confirm)) {
            Write-Host "Cancelled." -ForegroundColor Yellow
            continue
        }

        try {
            if ($selected.Action -is [scriptblock]) {
                & $selected.Action
            } elseif ($selected.Action -is [string]) {
                $cmd = Get-Command $selected.Action -ErrorAction SilentlyContinue
                if (-not $cmd) {
                    Write-Host "Action not available: $($selected.Action)" -ForegroundColor Red
                } else {
                    & $cmd @($selected.Arguments)
                }
            }
        } catch {
            Write-Host "Error running action: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
Displays the main IT Toolkit menu.
.DESCRIPTION
Routes to core, repair, maintenance, and advanced menus, calling module functions.
#>
function Invoke-ITT-MainMenu {
    $items = @(
        @{ Key="1"; Label="Hardware Inventory"; Action="Invoke-ITT-HardwareInventory"; Check={ Get-Command Invoke-ITT-HardwareInventory -ErrorAction SilentlyContinue } }
        @{ Key="2"; Label="Diagnostic Scans"; Action={ Invoke-ITT-DiagnosticMenu } }
        @{ Key="3"; Label="Quick Fixes"; Action={ Invoke-ITT-QuickFixMenu } }
        @{ Key="4"; Label="Network Tools"; Action={ Invoke-ITT-NetworkToolsMenu } }
        @{ Key="5"; Label="Windows Update Tools"; Action="Invoke-ITT-ResetWindowsUpdate"; Check={ Get-Command Invoke-ITT-ResetWindowsUpdate -ErrorAction SilentlyContinue } }
        @{ Key="6"; Label="Outlook Tools (7-in-1)"; Action="Invoke-ITT-OutlookToolsMenu"; Check={ Get-Command Invoke-ITT-OutlookToolsMenu -ErrorAction SilentlyContinue } }
        @{ Key="7"; Label="Office & Browser Repair"; Action={ Invoke-ITT-RepairOffice; Invoke-ITT-RepairBrowsers } }
        @{ Key="8"; Label="Windows Repair (DISM / SFC / WMI)"; Action="Invoke-ITT-RepairWindows"; Check={ Get-Command Invoke-ITT-RepairWindows -ErrorAction SilentlyContinue } }
        @{ Key="9"; Label="Cleanup Tools"; Action={ Invoke-ITT-CleanupMenu } }
        @{ Key="10"; Label="App Installers"; Action={ Invoke-ITT-AppInstallMenu } }
        @{ Key="11"; Label="BIOS & Profile Tools"; Action={ Invoke-ITT-ProfilesMenu } }
        @{ Key="12"; Label="Event Log Tools"; Action={ Invoke-ITT-EventLogMenu } }
        @{ Key="13"; Label="Nuclear Tools"; Action={ Invoke-ITT-NuclearMenu } }
        @{ Key="0"; Label="Exit"; Action="BACK" }
    )
    Write-Host "Tip: Type 'help <menu>' (e.g., help network tools) for menu help, or 'help <option>' inside a menu." -ForegroundColor DarkGray
    Invoke-ITT-MenuPage -Title "IT TOOLKIT" -Items $items -Prompt "Select option"
}

<#
.SYNOPSIS
Displays diagnostic scan options.
.DESCRIPTION
Runs Safe, Standard, or Aggressive scans via module diagnostic function.
#>
function Invoke-ITT-DiagnosticMenu {
    $items = @(
        @{ Key="1"; Label="Safe Scan (read-only)"; Action={ Invoke-ITT-DiagnosticScan -Mode "Safe" } }
        @{ Key="2"; Label="Standard Scan (light fixes)"; Action={ Invoke-ITT-DiagnosticScan -Mode "Standard" } }
        @{ Key="3"; Label="Aggressive Scan (disruptive)"; Action={ if (Invoke-ITT-AskYesNo "Proceed with Aggressive Scan?") { Invoke-ITT-DiagnosticScan -Mode "Aggressive" } } }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "DIAGNOSTIC SCANS" -Items $items -Prompt "Select scan mode"
}

<#
.SYNOPSIS
Displays quick fix options.
.DESCRIPTION
Offers lightweight scripts and minor repairs that are fast and low risk.
#>
function Invoke-ITT-QuickFixMenu {
    $items = @(
        @{ Key="1"; Label="Restart Explorer.exe"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\restart_Explorer_exe.ps1" "Restart Explorer.exe" } }
        @{ Key="2"; Label="Restart Audio Services"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\restart_audio_services.ps1" "Restart audio services" } }
        @{ Key="3"; Label="Restart Windows Update services"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\restart_windows_update_services.ps1" "Restart Windows Update services" } }
        @{ Key="4"; Label="Clear TEMP files"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\clear_TEMP_files.ps1" "Clear TEMP files" } }
        @{ Key="5"; Label="Empty Recycle Bin"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\empty_recycle_bin.ps1" "Empty Recycle Bin" } }
        @{ Key="6"; Label="Rebuild Windows Store cache"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\rebuild_windows_store_cache.ps1" "Rebuild Windows Store cache" } }
        @{ Key="7"; Label="Repair Windows Search Index"; Action="Invoke-ITT-RepairSearchIndex" }
        @{ Key="8"; Label="Reset OneDrive client"; Action="Invoke-ITT-ResetOneDrive" }
        @{ Key="9"; Label="Startup Impact Report"; Action="Invoke-ITT-StartupImpactReport" }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "QUICK FIXES" -Items $items
}

<#
.SYNOPSIS
Displays network tools menu.
.DESCRIPTION
Routes to port tests, DNS diagnostics, stack resets, firewall/NLA resets.
#>
function Invoke-ITT-NetworkToolsMenu {
    $items = @(
        @{ Key="1"; Label="Port test to 8.8.8.8 (53,80,443)"; Action={ Invoke-ITT-TestPorts -TargetHost "8.8.8.8" -Ports @(53,80,443) } }
        @{ Key="2"; Label="DNS Diagnostic"; Action="Invoke-ITT-DNSDiagnostic" }
        @{ Key="3"; Label="Reset Winsock & Network Stack"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\reset_winsock_and_network_stack.ps1" "Reset Winsock and network stack" } }
        @{ Key="4"; Label="Flush DNS"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\flush_DNS.ps1" "Flush DNS cache" } }
        @{ Key="5"; Label="Full Network Reset"; Action="Invoke-ITT-ResetNetwork" }
        @{ Key="6"; Label="Reset Firewall to defaults"; Action="Invoke-ITT-ResetFirewallDefaults" }
        @{ Key="7"; Label="Reset Network Location Awareness (NLA)"; Action="Invoke-ITT-ResetNLA" }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "NETWORK TOOLS" -Items $items
}

<#
.SYNOPSIS
Displays cleanup tools menu.
.DESCRIPTION
Provides quick cleanup, system cleanup, and Windows.old removal options.
#>
function Invoke-ITT-CleanupMenu {
    $items = @(
        @{ Key="1"; Label="Quick cleanup (TEMP + Recycle Bin)"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\clear_TEMP_files.ps1" "Clear TEMP files"; Invoke-ITT-RunScriptFile "simple_scripts\empty_recycle_bin.ps1" "Empty Recycle Bin" } }
        @{ Key="2"; Label="System logs & update cache cleanup"; Action="Invoke-ITT-SystemCleanup" }
        @{ Key="3"; Label="Remove Windows.old"; Action="Invoke-ITT-RemoveWindowsOld" }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "CLEANUP" -Items $items
}

<#
.SYNOPSIS
Displays app installer menu.
.DESCRIPTION
Runs installer scripts for common applications.
#>
function Invoke-ITT-AppInstallMenu {
    $items = @(
        @{ Key="1"; Label="Install Google Chrome"; Action={ Invoke-ITT-RunScriptFile "app_install\install_google_chrome.ps1" "Install Google Chrome" } }
        @{ Key="2"; Label="Install Mozilla Firefox"; Action={ Invoke-ITT-RunScriptFile "app_install\install_mozilla_firefox.ps1" "Install Mozilla Firefox" } }
        @{ Key="3"; Label="Install Microsoft Teams"; Action={ Invoke-ITT-RunScriptFile "app_install\install_teams.ps1" "Install Microsoft Teams" } }
        @{ Key="4"; Label="Reinstall Microsoft Teams"; Action={ Invoke-ITT-RunScriptFile "app_install\reinstall_teams.ps1" "Reinstall Microsoft Teams" } }
        @{ Key="5"; Label="Install Slack"; Action={ Invoke-ITT-RunScriptFile "app_install\install_slack.ps1" "Install Slack" } }
        @{ Key="6"; Label="Install 7-Zip"; Action={ Invoke-ITT-RunScriptFile "app_install\install_7-zip.ps1" "Install 7-Zip" } }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "APP INSTALLERS" -Items $items
}

<#
.SYNOPSIS
Displays BIOS and profile tools menu.
.DESCRIPTION
Routes to profile maintenance scripts and OneDrive reset.
#>
function Invoke-ITT-ProfilesMenu {
    $items = @(
        @{ Key="1"; Label="Reset Outlook profile"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\reset_outlook_profile.ps1" "Reset Outlook profile" } }
        @{ Key="2"; Label="Clean old user profiles"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\clean_old_user_profiles.ps1" "Clean old user profiles" } }
        @{ Key="3"; Label="Reset OneDrive client"; Action="Invoke-ITT-ResetOneDrive" }
        @{ Key="4"; Label="BIOS update framework"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\bios_update_framework.ps1" "BIOS update framework" } }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "BIOS & PROFILE TOOLS" -Items $items
}

<#
.SYNOPSIS
Displays event log tools menu.
.DESCRIPTION
Calls log collection and full log bundle functions.
#>
function Invoke-ITT-EventLogMenu {
    $items = @(
        @{ Key="1"; Label="Collect System/Application logs"; Action="Invoke-ITT-CollectLogs" }
        @{ Key="2"; Label="Collect Full Log Bundle (ZIP)"; Action="Invoke-ITT-CollectFullLogBundle" }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "EVENT LOG TOOLS" -Items $items
}

<#
.SYNOPSIS
Displays printing tools menu.
.DESCRIPTION
Offers script-based spooler restart and built-in reset/clear queue.
#>
function Invoke-ITT-PrintToolsMenu {
    $items = @(
        @{ Key="1"; Label="Restart print spooler (script)"; Action={ Invoke-ITT-RunScriptFile "simple_scripts\restart_print_spooler.ps1" "Restart print spooler" } }
        @{ Key="2"; Label="Reset print spooler and clear queue"; Action="Invoke-ITT-ResetPrintSpooler" }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "PRINTING TOOLS" -Items $items
}

<#
.SYNOPSIS
Displays advanced maintenance menu.
.DESCRIPTION
Provides advanced scripts and repairs (WU reset, WMI, AppX, drivers, firewall/NLA).
#>
function Invoke-ITT-AdvancedMaintenanceMenu {
    $items = @(
        @{ Key="1"; Label="Full Windows Repair (DISM/SFC)"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\full_windows_repair.ps1" "Full Windows repair" } }
        @{ Key="2"; Label="Reset Windows Update components"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\reset_windows_update_components.ps1" "Reset Windows Update components" } }
        @{ Key="3"; Label="Repair WMI"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\repair_WMI.ps1" "Repair WMI" } }
        @{ Key="4"; Label="Remove Windows bloatware"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\remove_windows_bloatware.ps1" "Remove Windows bloatware" } }
        @{ Key="5"; Label="Repair Office (advanced script)"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\repair_office.ps1" "Repair Office (advanced)" } }
        @{ Key="6"; Label="Reset Outlook profile"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\reset_outlook_profile.ps1" "Reset Outlook profile" } }
        @{ Key="7"; Label="Clean old user profiles"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\clean_old_user_profiles.ps1" "Clean old user profiles" } }
        @{ Key="8"; Label="BIOS update framework"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\bios_update_framework.ps1" "BIOS update framework" } }
        @{ Key="9"; Label="Reset Windows Firewall"; Action="Invoke-ITT-ResetFirewallDefaults" }
        @{ Key="10"; Label="Reset Network Location Awareness (NLA)"; Action="Invoke-ITT-ResetNLA" }
        @{ Key="11"; Label="Repair Windows Store / AppX"; Action="Invoke-ITT-RepairAppX" }
        @{ Key="12"; Label="Scheduled Tasks Health Check"; Action="Invoke-ITT-RepairScheduledTasks" }
        @{ Key="13"; Label="Driver Health Scan"; Action="Invoke-ITT-DriverHealthScan" }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "ADVANCED MAINTENANCE" -Items $items
}

<#
.SYNOPSIS
Displays nuclear tools menu.
.DESCRIPTION
Offers Deep Health Scan and nuclear-level Windows repair/update reset scripts.
#>
function Invoke-ITT-NuclearMenu {
    $items = @(
        @{ Key="1"; Label="Deep Health Scan (disruptive)"; Action="Invoke-ITT-DeepHealthScan"; Confirm="Proceed with Deep Health Scan? This is disruptive." }
        @{ Key="2"; Label="Full Windows Repair (advanced script)"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\full_windows_repair.ps1" "Full Windows repair (nuclear)" } }
        @{ Key="3"; Label="Reset Windows Update components (advanced script)"; Action={ Invoke-ITT-RunScriptFile "advanced_it_maintenance\reset_windows_update_components.ps1" "Reset Windows Update components (nuclear)" } }
        @{ Key="0"; Label="Back"; Action="BACK" }
    )
    Invoke-ITT-MenuPage -Title "NUCLEAR TOOLS" -Items $items
}

<#
.SYNOPSIS
Entry point for the IT Toolkit CLI.
.DESCRIPTION
Loads the main menu loop.
#>
function Invoke-ITToolkit {
    Clear-Host
    Show-GlitchText -Text $ITBanner
    Show-SpinningCube
    Clear-Host
    Invoke-ITT-MainMenu
}

# Friendly help functions (Get-Help <Name>-Help) for menu/submenu discoverability.
# Note: PowerShell identifiers cannot contain spaces; use the provided names below.

<#
.SYNOPSIS
Help topic for the Network Tools menu.
.DESCRIPTION
Use this to see available network actions (port test, DNS diagnostic, stack resets, firewall/NLA reset).
Run Invoke-ITT-NetworkToolsMenu to open the menu.
#>
function NetworkToolsHelp { param() }

<#
.SYNOPSIS
Help topic for the Quick Fixes menu.
.DESCRIPTION
Quick, low-risk fixes (Explorer restart, audio services, TEMP cleanup, search index repair, OneDrive reset).
Run Invoke-ITT-QuickFixMenu to open the menu.
#>
function QuickFixesHelp { param() }

<#
.SYNOPSIS
Help topic for the Cleanup menu.
.DESCRIPTION
Quick cleanup, system cache cleanup, and Windows.old removal.
Run Invoke-ITT-CleanupMenu to open the menu.
#>
function CleanupToolsHelp { param() }

<#
.SYNOPSIS
Help topic for the App Installers menu.
.DESCRIPTION
Installer scripts for common apps (Chrome, Firefox, Teams, Slack, 7-Zip).
Run Invoke-ITT-AppInstallMenu to open the menu.
#>
function AppInstallersHelp { param() }

<#
.SYNOPSIS
Help topic for BIOS & Profile Tools.
.DESCRIPTION
Profile maintenance scripts, OneDrive reset, and BIOS update framework.
Run Invoke-ITT-ProfilesMenu to open the menu.
#>
function BiosProfileToolsHelp { param() }

<#
.SYNOPSIS
Help topic for Event Log Tools.
.DESCRIPTION
Log collection and full log bundle options.
Run Invoke-ITT-EventLogMenu to open the menu.
#>
function EventLogToolsHelp { param() }

<#
.SYNOPSIS
Help topic for Printing Tools.
.DESCRIPTION
Spooler restart/reset options.
Run Invoke-ITT-PrintToolsMenu to open the menu.
#>
function PrintingToolsHelp { param() }

<#
.SYNOPSIS
Help topic for Advanced Maintenance.
.DESCRIPTION
Advanced scripts (WU reset, WMI repair, AppX repair, drivers, firewall/NLA).
Run Invoke-ITT-AdvancedMaintenanceMenu to open the menu.
#>
function AdvancedMaintenanceHelp { param() }

<#
.SYNOPSIS
Help topic for Nuclear Tools.
.DESCRIPTION
Disruptive actions including Deep Health Scan and advanced Windows repair/reset update components.
Run Invoke-ITT-NuclearMenu to open the menu.
#>
function NuclearToolsHelp { param() }

<#
.SYNOPSIS
Help topic for Diagnostic Scans.
.DESCRIPTION
Safe, Standard, and Aggressive diagnostic scan modes.
Run Invoke-ITT-DiagnosticMenu to open the menu.
#>
function DiagnosticScansHelp { param() }

<#
.SYNOPSIS
Help topic for port testing in Network Tools.
.DESCRIPTION
TCP port test to a target host/ports; runs Invoke-ITT-TestPorts when selected in the menu.
#>
function PortTestHelp { param() }

<#
.SYNOPSIS
Help topic for DNS Diagnostic in Network Tools.
.DESCRIPTION
Adapter/DNS listing and external resolution check; runs Invoke-ITT-DNSDiagnostic.
#>
function DNSDiagnosticHelp { param() }

<#
.SYNOPSIS
Help topic for Full Network Reset in Network Tools.
.DESCRIPTION
Disruptive DNS/Winsock/IP reset, service restart, and adapter cycling; runs Invoke-ITT-ResetNetwork.
#>
function FullNetworkResetHelp { param() }

<#
.SYNOPSIS
Help topic for Reset Firewall (Network Tools).
.DESCRIPTION
Resets Windows Firewall rules to defaults; runs Invoke-ITT-ResetFirewallDefaults.
#>
function ResetFirewallHelp { param() }

<#
.SYNOPSIS
Help topic for Reset NLA (Network Tools).
.DESCRIPTION
Restarts NLA service to refresh network profiles; runs Invoke-ITT-ResetNLA.
#>
function ResetNLAHelp { param() }

# Friendly help router: allows "help network tools" style input by mapping to help stubs above.
function Help {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Name
    )

    if (-not $Name -or $Name.Count -eq 0) {
        try { return Get-Help } catch { Write-Host "Help unavailable: $($_.Exception.Message)" -ForegroundColor Yellow; return }
    }

    $topicParts = @()
    $extraArgs  = @()

    foreach ($token in $Name) {
        if ($topicParts.Count -eq 0 -or ($topicParts.Count -gt 0 -and $token -notmatch '^-[A-Za-z]')) {
            # Accumulate topic words until a switch appears
            if ($token -notmatch '^-[A-Za-z]') {
                $topicParts += $token
                continue
            }
        }
        $extraArgs += $token
    }

    if ($topicParts.Count -eq 0) {
        $topicParts = @($Name[0])
        if ($Name.Length -gt 1) { $extraArgs = $Name[1..($Name.Length - 1)] }
    }

    $topicString = ($topicParts -join " ").Trim()
    $normalized  = (($topicParts -join '') -replace '\s','').ToLower()

    $map = @{
        "networktools"        = "NetworkToolsHelp"
        "quickfixes"          = "QuickFixesHelp"
        "cleanup"             = "CleanupToolsHelp"
        "cleanuptools"        = "CleanupToolsHelp"
        "appinstallers"       = "AppInstallersHelp"
        "biosprofiletools"    = "BiosProfileToolsHelp"
        "biosandprofiletools" = "BiosProfileToolsHelp"
        "eventlogtools"       = "EventLogToolsHelp"
        "printingtools"       = "PrintingToolsHelp"
        "advancedmaintenance" = "AdvancedMaintenanceHelp"
        "nucleartools"        = "NuclearToolsHelp"
        "diagnosticscans"     = "DiagnosticScansHelp"
        "porttest"            = "PortTestHelp"
        "dnsdiagnostic"       = "DNSDiagnosticHelp"
        "fullnetworkreset"    = "FullNetworkResetHelp"
        "resetfirewall"       = "ResetFirewallHelp"
        "resetnla"            = "ResetNLAHelp"
    }

    if ($map.ContainsKey($normalized)) {
        try { return Get-Help -Name $map[$normalized] @extraArgs } catch { Write-Host "Help unavailable: $($_.Exception.Message)" -ForegroundColor Yellow; return }
    }

    # Fallback to the literal topic string with any extra arguments (e.g., -Examples)
    try { return Get-Help -Name $topicString @extraArgs } catch { Write-Host "Help unavailable: $($_.Exception.Message)" -ForegroundColor Yellow; return }
}
