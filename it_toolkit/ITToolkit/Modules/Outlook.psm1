# Outlook tools module

<#!
.SYNOPSIS
Performs a full Outlook reset.
.DESCRIPTION
Stops Outlook, restarts Explorer, clears Outlook temp/cache and Office lockfiles.
#>
function Invoke-ITT-OutlookReset {
    Write-Host "`n=== Full Outlook Reset (attachments, crashes, file picker) ===" -ForegroundColor Cyan

    Write-Host "Killing Outlook process..." -ForegroundColor Yellow
    try { Get-Process OUTLOOK -ErrorAction SilentlyContinue | Stop-Process -Force } catch { Write-Verbose "OutlookReset: stop outlook failed $_" }

    Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
    try {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Start-Process explorer.exe -ArgumentList "/n,/e,$($env:USERPROFILE)" -ErrorAction SilentlyContinue
    } catch {
        Write-Verbose "OutlookReset: explorer restart failed $_"
    }

    Write-Host "Clearing Outlook temp cache (Content.Outlook)..." -ForegroundColor Yellow
    $tempPath = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\Content.Outlook"
    if (Test-Path $tempPath) {
        try { Remove-Item -Path (Join-Path $tempPath '*') -Recurse -Force -ErrorAction Stop } catch { Write-Verbose "OutlookReset: clear temp cache failed $_" }
    } else {
        Write-Verbose "OutlookReset: temp path missing $tempPath"
    }

    Write-Host "Clearing temporary Office lockfiles from %TEMP%..." -ForegroundColor Yellow
    $tempRoot = $env:TEMP
    if (Test-Path $tempRoot) {
        try {
            Get-ChildItem -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "~$*" -or $_.Extension -eq ".tmp" } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "OutlookReset: clearing temp lockfiles failed $_"
        }
    }

    Write-Host "Outlook hard reset complete. Re-open Outlook and test attachments again." -ForegroundColor Green
}

<#!
.SYNOPSIS
Disables all Outlook add-ins.
.DESCRIPTION
Sets LoadBehavior to 0 for add-ins under HKCU/HKLM.
#>
function Invoke-ITT-OutlookDisableAddins {
    Write-Host "`n=== Disable ALL Outlook Add-ins ===" -ForegroundColor Cyan
    Write-Host "If Outlook works in Safe Mode but not normally, it's almost always an add-in." -ForegroundColor Yellow

    $addinsPaths = @(
        "HKCU:\Software\Microsoft\Office\16.0\Outlook\Addins",
        "HKLM:\Software\Microsoft\Office\Outlook\Addins"
    )

    foreach ($path in $addinsPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path | ForEach-Object {
                try {
                    Set-ItemProperty -Path $_.PSPath -Name "LoadBehavior" -Value 0 -ErrorAction Stop
                    Write-Host "Disabled add-in: $($_.PSChildName)" -ForegroundColor Yellow
                } catch {
                    Write-Host "Failed to disable add-in at $($_.PSPath): $_" -ForegroundColor Red
                    Write-Verbose "OutlookDisableAddins: failed to set LoadBehavior for $($_.PSPath) : $($_.Exception.Message)"
                }
            }
        } else {
            Write-Verbose "OutlookDisableAddins: path missing $path"
        }
    }

    Write-Host "All add-ins disabled (where registry was accessible). Restart Outlook and test." -ForegroundColor Green
}

<#!
.SYNOPSIS
Rebuilds Outlook OST by renaming existing cache.
.DESCRIPTION
Lists OSTs, prompts for selection, renames the chosen OST to force rebuild.
#>
function Invoke-ITT-OutlookRebuildOST {
    Write-Host "`n=== Rebuild Outlook OST (offline cache) ===" -ForegroundColor Cyan
    Write-Host "This forces Outlook to download a fresh mailbox cache. Close Outlook before continuing." -ForegroundColor Yellow

    $ostRoot = Join-Path $env:LOCALAPPDATA "Microsoft\Outlook"
    if (-not (Test-Path $ostRoot)) {
        Write-Host "No OST folder found at $ostRoot" -ForegroundColor Red
        Write-Verbose "OutlookRebuildOST: ost root missing $ostRoot"
        return
    }

    $ostFiles = Get-ChildItem -Path $ostRoot -Filter *.ost -ErrorAction SilentlyContinue
    if (-not $ostFiles -or $ostFiles.Count -eq 0) {
        Write-Host "No .ost files found under $ostRoot" -ForegroundColor Red
        return
    }

    Write-Host "Detected OST files:" -ForegroundColor Yellow
    $index = 1
    $ostFiles | ForEach-Object {
        $sizeGB = [Math]::Round($_.Length / 1GB, 2)
        Write-Host ("  {0}) {1} ({2} GB)" -f $index, $_.FullName, $sizeGB)
        $index++
    }

    $choice = Read-Host "Enter number of OST to rename (or press Enter to cancel)"
    if ([string]::IsNullOrWhiteSpace($choice) -or ($choice -notmatch '^\d+$')) {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    $selectedIndex = [int]$choice
    if ($selectedIndex -lt 1 -or $selectedIndex -gt $ostFiles.Count) {
        Write-Host "Selection out of range." -ForegroundColor Red
        return
    }

    $target = $ostFiles[$selectedIndex - 1]
    $newName = $target.FullName + ".bak_{0:yyyyMMddHHmmss}" -f (Get-Date)

    try {
        Rename-Item -Path $target.FullName -NewName $newName -ErrorAction Stop
        Write-Host "Renamed OST to: $newName" -ForegroundColor Green
        Write-Host "Re-open Outlook. It will build a fresh OST. First sync may be slow." -ForegroundColor Yellow
    } catch {
        Write-Host "Failed to rename OST: $_" -ForegroundColor Red
        Write-Verbose "OutlookRebuildOST: rename failed $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Opens WebView2 download page for repair.
.DESCRIPTION
Launches default browser to the WebView2 download section.
#>
function Invoke-ITT-OutlookRepairWebView2 {
    Write-Host "`n=== Repair WebView2 Runtime for Outlook ===" -ForegroundColor Cyan
    Write-Host "Modern Outlook uses WebView2 for UI, auth popups and file dialogs." -ForegroundColor Yellow
    Write-Host "This will try to launch the official WebView2 runtime installer site." -ForegroundColor Yellow

    $url = "https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section"
    try {
        Start-Process $url -ErrorAction Stop
        Write-Host "Opened WebView2 download page. Download the Evergreen Runtime and run a repair / reinstall." -ForegroundColor Green
    } catch {
        Write-Host "Failed to open browser automatically. Open this URL manually:" -ForegroundColor Red
        Write-Host $url -ForegroundColor Cyan
        Write-Verbose "OutlookRepairWebView2: failed to start browser $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Resets Outlook navigation pane.
.DESCRIPTION
Runs Outlook with /resetnavpane switch.
#>
function Invoke-ITT-OutlookResetNavPane {
    Write-Host "`n=== Reset Outlook Navigation Pane ===" -ForegroundColor Cyan
    Write-Host "This fixes 'Cannot start Microsoft Outlook' and broken / missing sidebars." -ForegroundColor Yellow

    $outlookPath = "outlook.exe"
    try {
        Start-Process $outlookPath -ArgumentList "/resetnavpane" -ErrorAction Stop
        Write-Host "Launched Outlook with /resetnavpane. If Outlook was closed, it will open with a fresh navigation pane." -ForegroundColor Green
    } catch {
        Write-Host "Failed to start Outlook with /resetnavpane. Is Outlook installed for this user?" -ForegroundColor Red
        Write-Verbose "OutlookResetNavPane failed: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Opens Indexing Options for search rebuild.
.DESCRIPTION
Launches srchadmin.dll control panel to rebuild the search index.
#>
function Invoke-ITT-OutlookRebuildSearchIndex {
    Write-Host "`n=== Rebuild Outlook / Windows Search Index ===" -ForegroundColor Cyan
    Write-Host "Use when Outlook search is empty, missing recent items or very slow." -ForegroundColor Yellow

    try {
        Start-Process "control.exe" -ArgumentList "srchadmin.dll" -ErrorAction Stop
        Write-Host "Indexing Options opened. From there, choose Advanced -> Rebuild." -ForegroundColor Green
    } catch {
        Write-Host "Could not open Indexing Options automatically. Search for 'Indexing Options' in Control Panel." -ForegroundColor Red
        Write-Verbose "OutlookRebuildSearchIndex failed: $($_.Exception.Message)"
    }
}

<#! 
.SYNOPSIS
Lists Outlook profiles if present.
.DESCRIPTION
Shows XML profiles under %APPDATA%\Microsoft\Outlook if they exist.
#>
function Invoke-ITT-OutlookProfileCheck {
    Write-Host "`n=== Outlook Profile Check ===" -ForegroundColor Cyan

    $profilesPath = "$env:APPDATA\Microsoft\Outlook"
    try {
        $profiles = Get-ChildItem $profilesPath -Filter *.xml -ErrorAction Stop
    } catch {
        Write-Host "Failed to read Outlook profiles: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "OutlookProfileCheck: Get-ChildItem failed $($_.Exception.Message)"
        return
    }

    if (-not $profiles -or $profiles.Count -eq 0) {
        Write-Host "No Outlook XML profile definitions found in $profilesPath" -ForegroundColor Yellow
    }
    else {
        Write-Host "Profiles detected:" -ForegroundColor Yellow
        $profiles | ForEach-Object { Write-Host " - $($_.Name)" }
    }
}

function Invoke-ITT-OutlookToolsMenu {
    while ($true) {
        Write-Host ""
        Write-Host "========== OUTLOOK TOOLS (REAL-LIFE FIXES) ==========" -ForegroundColor Cyan
        Write-Host "1) Full Outlook Reset           (attachments, crashes, file picker)"
        Write-Host "2) Disable ALL Add-ins          (Safe Mode works, normal mode crashes)"
        Write-Host "3) Rebuild OST                  (missing mail, broken sync, slow Outlook)"
        Write-Host "4) Repair WebView2 Runtime      (blank windows, auth popups, file dialogs)"
        Write-Host "5) Reset Navigation Pane        ('Cannot start Outlook', broken sidebar)"
        Write-Host "6) Rebuild Search Index         (search empty or missing recent items)"
        Write-Host "7) Office Quick Repair          (busted binaries / DLL issues)"
        Write-Host "0) Back to main menu"
        Write-Host "====================================================="
        $choice = Read-Host "Select Outlook fix (0-7)"

        switch ($choice) {
            "1" { Invoke-ITT-OutlookReset }
            "2" { Invoke-ITT-OutlookDisableAddins }
            "3" { Invoke-ITT-OutlookRebuildOST }
            "4" { Invoke-ITT-OutlookRepairWebView2 }
            "5" { Invoke-ITT-OutlookResetNavPane }
            "6" { Invoke-ITT-OutlookRebuildSearchIndex }
            "7" { Invoke-ITT-OfficeRepair }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}

Export-ModuleMember -Function Invoke-ITT-OutlookReset,Invoke-ITT-OutlookDisableAddins,Invoke-ITT-OutlookRebuildOST,Invoke-ITT-OutlookRepairWebView2,Invoke-ITT-OutlookResetNavPane,Invoke-ITT-OutlookRebuildSearchIndex,Invoke-ITT-OutlookProfileCheck,Invoke-ITT-OutlookToolsMenu
