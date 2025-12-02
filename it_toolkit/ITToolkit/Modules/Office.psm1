# Office repair and browser repair module

<#!
.SYNOPSIS
Runs Office 365 repair/reset steps.
.DESCRIPTION
Attempts Click-to-Run repair, resets Outlook nav pane, renames OST files, and reinstalls WebView2.
#>
function Invoke-ITT-RepairOffice {
    Write-Output "=== Office 365 Repair / Reset ==="

    $ctrPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    if (-not (Test-Path $ctrPath)) {
        $ctrPath = "C:\Program Files (x86)\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    }

    if (Test-Path $ctrPath) {
        Write-Output "Running Office Click-to-Run repair..."
        try {
            Start-Process $ctrPath -ArgumentList "scenario=Repair displaylevel=False forceappshutdown=True" -Wait -ErrorAction Stop
        } catch {
            Write-Output "Click-to-Run repair failed: $($_.Exception.Message)"
            Write-Verbose "Invoke-ITT-RepairOffice CTR repair failed: $($_.Exception.Message)"
        }
    } else {
        Write-Output "OfficeClickToRun.exe not found - skipping CTR repair."
        Write-Verbose "Invoke-ITT-RepairOffice: CTR not found"
    }

    Write-Output "Resetting Outlook navigation pane (if installed)..."
    try {
        $outlook = Get-ChildItem "C:\Program Files*" -Recurse -Filter OUTLOOK.EXE -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($outlook) {
            Start-Process $outlook.FullName -ArgumentList "/resetnavpane" -Wait -ErrorAction Stop
            Write-Output "Outlook navigation pane reset."
        } else {
            Write-Output "Outlook.exe not found - skipping Outlook reset."
        }
    } catch {
        Write-Output "Failed to reset Outlook navigation pane: $($_.Exception.Message)"
        Write-Verbose "Invoke-ITT-RepairOffice navpane failed: $($_.Exception.Message)"
    }

    Write-Output "Renaming OST files (forces fresh resync)..."
    $ostPath = "$env:USERPROFILE\AppData\Local\Microsoft\Outlook"
    if (Test-Path $ostPath) {
        Get-ChildItem $ostPath -Filter *.ost -ErrorAction SilentlyContinue | ForEach-Object {
            $backup = "$($_.FullName).bak"
            if (-not (Test-Path $backup)) {
                try {
                    Rename-Item $_.FullName $backup -ErrorAction Stop
                    Write-Output "Renamed: $($_.Name) -> $(Split-Path $backup -Leaf)"
                } catch {
                    Write-Verbose "Invoke-ITT-RepairOffice: failed to rename $($_.FullName) : $($_.Exception.Message)"
                }
            }
        }
    } else {
        Write-Output "No OST folder found - skipping OST rename."
    }

    Write-Output "Reinstalling WebView2..."
    if (Invoke-ITT-ReinstallWebView2 -Quiet) {
        Write-Output "WebView2 reinstall completed."
    } else {
        Write-Output "WebView2 installation failed. Check network or proxy settings."
    }

    Write-Output "=== Office 365 Repair Complete ==="
}

<#!
.SYNOPSIS
Repairs common browser caches and reinstalls WebView2.
.DESCRIPTION
Clears Chrome/Edge/Firefox caches and triggers WebView2 reinstall.
#>
function Invoke-ITT-RepairBrowsers {
    Write-Output "=== Browser Reset and Repair ==="

    $u = $env:USERPROFILE

    Invoke-ITT-ClearFolder "$u\AppData\Local\Google\Chrome\User Data\Default\Cache"
    Invoke-ITT-ClearFolder "$u\AppData\Local\Google\Chrome\User Data\Default\Code Cache"

    Invoke-ITT-ClearFolder "$u\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
    Invoke-ITT-ClearFolder "$u\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"

    $ffRoot = "$u\AppData\Local\Mozilla\Firefox\Profiles"
    if (Test-Path $ffRoot) {
        Get-ChildItem $ffRoot -Directory | ForEach-Object {
            Invoke-ITT-ClearFolder "$($_.FullName)\cache2"
        }
    } else {
        Write-Verbose "Invoke-ITT-RepairBrowsers: firefox profile root missing"
    }

    Write-Output "Reinstalling WebView2..."
    if (Invoke-ITT-ReinstallWebView2 -Quiet) {
        Write-Output "WebView2 reinstall completed."
    } else {
        Write-Output "WebView2 installation failed. Check network or proxy settings."
    }

    Write-Output "=== Browser Repair Complete ==="
}

<#!
.SYNOPSIS
Runs Office Click-to-Run quick repair.
.DESCRIPTION
Launches OfficeC2RClient.exe /repair user if present.
#>
function Invoke-ITT-OfficeRepair {
    Write-Host "`n=== Office Quick Repair ===" -ForegroundColor Cyan
    Write-Host "This runs Office Click-to-Run repair. Use when Outlook binaries / DLLs are corrupted." -ForegroundColor Yellow

    $c2rPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    if (-not (Test-Path $c2rPath)) {
        $c2rPath = "C:\Program Files (x86)\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    }

    if (-not (Test-Path $c2rPath)) {
        Write-Host "OfficeC2RClient.exe not found. Office may not be Click-to-Run or is not installed in the default path." -ForegroundColor Red
        Write-Verbose "Invoke-ITT-OfficeRepair: C2R client not found"
        return
    }

    try {
        Start-Process $c2rPath -ArgumentList "/repair user" -ErrorAction Stop
        Write-Host "Office repair launched. Follow the on-screen wizard." -ForegroundColor Green
    } catch {
        Write-Host "Failed to launch Office repair: $_" -ForegroundColor Red
        Write-Verbose "Invoke-ITT-OfficeRepair failed: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Invoke-ITT-RepairOffice,Invoke-ITT-RepairBrowsers,Invoke-ITT-OfficeRepair
