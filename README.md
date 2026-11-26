# IT Toolkit

A menu driven PowerShell toolkit for first line Windows support. It bundles the fixes a support technician runs every week (Outlook, Teams, OneDrive, Office, Windows Update, network, printers, profiles) into one launcher, so common problems get fixed the same way every time.

## Features

- **Diagnostic scans** in three levels: Safe (read only), Standard (light fixes) and Aggressive (disruptive, asks first)
- **Quick fixes:** restart Explorer, audio or Windows Update services, clear temp files, rebuild the Store cache, repair search, startup impact report
- **Network tools:** port tests, DNS diagnostics, Winsock and network stack reset, full network reset
- **Repairs:** Outlook (profile reset and more), Office, Teams, OneDrive, Chrome and Edge, Start menu, Windows (DISM, SFC, WMI)
- **Cleanup, app installers, BIOS and profile tools, event log tools, RDP cache cleanup and a Credential Manager audit**
- Destructive actions ask for confirmation before they run

## Structure

```
it_toolkit/
  Start-ITToolkit.ps1        launcher
  ITToolkit/
    ITToolkit.psm1           root module
    ITToolkit_CLI.ps1        interactive menus
    ITToolkit_API.ps1        functions that return structured objects (groundwork for a future GUI)
    Modules/                 one module per area (Network, Office, Outlook, Teams, Printers, ...)
simple_scripts/              single purpose fixes the menus call
advanced_it_maintenance/     larger repair and maintenance scripts
app_install/                 silent installers for common apps
```

## Usage

Run from an elevated PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\it_toolkit\Start-ITToolkit.ps1
```

Many fixes change system settings or remove cached data. Read what an option does before running it on a machine you care about.
