# ITToolkit.psm1
# Root folder where all your script collections live
# e.g. C:\Scripts2 with subfolders:
#   - simple_scripts
#   - advanced_it_maintenance
#   - app_install
$Global:ITT_ScriptsRoot = "C:\Scripts2"
# Simple IT technician toolkit module (console based)

# -----------------------
# Helper: Yes/No prompt
# -----------------------
function Invoke-ITT-AskYesNo {
    param(
        [string]$Message
    )
    while ($true) {
       $userInput = Read-Host "$Message [y/n]"
       switch ($userInput.ToLower()) {
         "y" { return $true }
         "n" { return $false }
         default { Write-Host "Please answer y or n." -ForegroundColor Yellow }
       }

    }
}

# -----------------------
# Helper: Report output
# -----------------------
function Invoke-ITT-SaveReport {
    param(
        [string]$ReportText,
        [string]$DefaultFileName = "IT_Diagnostic_Report"
    )

    Write-Host ""
    Write-Host "Where should I output the report?" -ForegroundColor Cyan
    Write-Host "1) Show in console"
    Write-Host "2) Save to Desktop"
    Write-Host "3) Show and Save"
    Write-Host "4) Cancel"
    $choice = Read-Host "Select (1-4)"

    $desktop = [Environment]::GetFolderPath("Desktop")
    $filePath = Join-Path $desktop ("{0}_{1}.txt" -f $DefaultFileName, (Get-Date -Format "yyyyMMdd_HHmmss"))

    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host $ReportText
        }
        "2" {
            $ReportText | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "Report saved to: $filePath" -ForegroundColor Green
        }
        "3" {
            Write-Host ""
            Write-Host $ReportText
            $ReportText | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host ""
            Write-Host "Report saved to: $filePath" -ForegroundColor Green
        }
        "4" {
            Write-Host "Report output cancelled." -ForegroundColor Yellow
        }
        default {
            Write-Host "Invalid choice. Showing in console." -ForegroundColor Yellow
            Write-Host ""
            Write-Host $ReportText
        }
    }
}

function Invoke-ITT-RunScriptFile {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,     # e.g. "simple_scripts\flush_DNS.ps1"
        [string]$Description = ""
    )

    $fullPath = Join-Path $Global:ITT_ScriptsRoot $RelativePath

    if (-not (Test-Path $fullPath)) {
        Write-Host "Script not found: $fullPath" -ForegroundColor Red
        return
    }

    if ($Description) {
        Write-Host ""
        Write-Host "=== $Description ===" -ForegroundColor Cyan
    }

    try {
        Write-Progress -Activity "IT Toolkit" -Status $Description -PercentComplete 0
        & $fullPath
        Write-Progress -Activity "IT Toolkit" -Completed -Status "$Description - done"
        Write-Host ""
        Write-Host "$Description completed." -ForegroundColor Green
    } catch {
        Write-Progress -Activity "IT Toolkit" -Completed
        Write-Host "Error running $Description : $($_.Exception.Message)" -ForegroundColor Red
    }
}


# -----------------------
# Hardware Inventory
# -----------------------
function Invoke-ITT-HardwareInventory {
    Write-Host ""
    Write-Host "=== Hardware Inventory ===" -ForegroundColor Cyan
    Write-Host ""

    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $bios = Get-CimInstance Win32_BIOS

    $info = [ordered]@{
        "Computer Name"          = $env:COMPUTERNAME
        "Manufacturer"           = $cs.Manufacturer
        "Model"                  = $cs.Model
        "Serial Number"          = $bios.SerialNumber
        "BIOS Version"           = $bios.SMBIOSBIOSVersion
        "BIOS Date Raw"          = $bios.ReleaseDate
        "CPU"                    = (Get-CimInstance Win32_Processor).Name
        "RAM (GB)"               = [Math]::Round($cs.TotalPhysicalMemory / 1GB)
        "OS"                     = $os.Caption
        "OS Version"             = $os.Version
        "System Drive Free (GB)" = [Math]::Round((Get-PSDrive C).Free / 1GB, 2)
    }

    foreach ($item in $info.GetEnumerator()) {
        "{0,-25}: {1}" -f $item.Key, $item.Value | Write-Host
    }

    Write-Host ""
    Write-Host "Disk Health:" -ForegroundColor Cyan
    Get-PhysicalDisk | Select-Object FriendlyName, Size, MediaType, HealthStatus | Format-Table

    Write-Host ""
    Write-Host "Network Adapters:" -ForegroundColor Cyan
    Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table

    Write-Host ""
    Write-Host "=== Inventory Complete ===" -ForegroundColor Cyan
}

# -----------------------
# Office 365 Repair
# -----------------------
function Invoke-ITT-RepairOffice {
    Write-Output "=== Office 365 Repair / Reset ==="

    $ctrPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    if (-not (Test-Path $ctrPath)) {
        $ctrPath = "C:\Program Files (x86)\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    }

    if (Test-Path $ctrPath) {
        Write-Output "Running Office Click-to-Run repair..."
        Start-Process $ctrPath -ArgumentList "scenario=Repair displaylevel=False forceappshutdown=True" -Wait
    } else {
        Write-Output "OfficeClickToRun.exe not found - skipping CTR repair."
    }

    Write-Output "Resetting Outlook navigation pane (if installed)..."
    $outlook = Get-ChildItem "C:\Program Files*" -Recurse -Filter OUTLOOK.EXE -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($outlook) {
        Start-Process $outlook.FullName -ArgumentList "/resetnavpane" -Wait
        Write-Output "Outlook navigation pane reset."
    } else {
        Write-Output "Outlook.exe not found - skipping Outlook reset."
    }

    Write-Output "Renaming OST files (forces fresh resync)..."
    $ostPath = "$env:USERPROFILE\AppData\Local\Microsoft\Outlook"
    if (Test-Path $ostPath) {
        Get-ChildItem $ostPath -Filter *.ost -ErrorAction SilentlyContinue | ForEach-Object {
            $backup = "$($_.FullName).bak"
            if (-not (Test-Path $backup)) {
                Rename-Item $_.FullName $backup -ErrorAction SilentlyContinue
                Write-Output "Renamed: $($_.Name) -> $(Split-Path $backup -Leaf)"
            }
        }
    } else {
        Write-Output "No OST folder found - skipping OST rename."
    }

    Write-Output "Reinstalling WebView2..."
    $web = "$env:TEMP\EdgeWebView2.exe"

    try {
        Invoke-WebRequest "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $web -UseBasicParsing
        Start-Process $web -ArgumentList "/silent /install" -Wait
        Remove-Item $web -Force
        Write-Output "WebView2 reinstall completed."
    } catch {
        Write-Output "WebView2 installation failed: $($_.Exception.Message)"
    }

    Write-Output "=== Office 365 Repair Complete ==="
}

# -----------------------
# Browser Repair
# -----------------------
function Invoke-ITT-RepairBrowsers {
    Write-Output "=== Browser Reset and Repair ==="

    function Clear-ITT-Folder {
        param([string]$Path)
        if (Test-Path $Path) {
            Write-Output "Clearing: $Path"
            Remove-Item "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $u = $env:USERPROFILE

    Clear-ITT-Folder "$u\AppData\Local\Google\Chrome\User Data\Default\Cache"
    Clear-ITT-Folder "$u\AppData\Local\Google\Chrome\User Data\Default\Code Cache"

    Clear-ITT-Folder "$u\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
    Clear-ITT-Folder "$u\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"

    $ffRoot = "$u\AppData\Local\Mozilla\Firefox\Profiles"
    if (Test-Path $ffRoot) {
        Get-ChildItem $ffRoot -Directory | ForEach-Object {
            Clear-ITT-Folder "$($_.FullName)\cache2"
        }
    }

    Write-Output "Reinstalling WebView2..."
    $wv = "$env:TEMP\EdgeWebView2.exe"
    try {
        Invoke-WebRequest "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $wv -UseBasicParsing
        Start-Process $wv -ArgumentList "/silent /install" -Wait
        Remove-Item $wv -Force
        Write-Output "WebView2 reinstall completed."
    } catch {
        Write-Output "WebView2 installation failed: $($_.Exception.Message)"
    }

    Write-Output "=== Browser Repair Complete ==="
}

# -----------------------
# Windows Corruption Repair
# -----------------------
function Invoke-ITT-RepairWindows {
    Write-Output "=== Windows Corruption Repair ==="

    Write-Output "Running DISM /RestoreHealth..."
    DISM /Online /Cleanup-Image /RestoreHealth

    Write-Output "Running SFC /scannow..."
    sfc /scannow

    Write-Output "Repairing WMI repository..."
    try {
        net stop winmgmt /y
        winmgmt /salvagerepository
        winmgmt /resetrepository
        net start winmgmt
    } catch {
        Write-Output "WMI repair error: $($_.Exception.Message)"
    }

    Write-Output "=== Corruption Repair Complete (reboot recommended) ==="
}

#----------------------
# Remove Windows.old
#-----------------------
function Invoke-ITT-RemoveWindowsOld {
    $path = "C:\Windows.old"
    if (-not (Test-Path $path)) {
        Write-Host "No Windows.old folder found." -ForegroundColor Yellow
        return
    }

    $sizeBytes = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $sizeGB    = [Math]::Round($sizeBytes / 1GB, 2)

    Write-Host ""
    Write-Host "Windows.old detected at $path (~$sizeGB GB)." -ForegroundColor Cyan
    Write-Host "This folder is only needed to roll back to the previous Windows version." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Do you want to remove Windows.old using manual delete?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    try {
        Write-Progress -Activity "Removing Windows.old" -Status "Deleting files..." -PercentComplete 0
        Remove-Item $path -Recurse -Force -ErrorAction Stop
        Write-Progress -Activity "Removing Windows.old" -Completed
        Write-Host "Windows.old removed successfully." -ForegroundColor Green
    } catch {
        Write-Progress -Activity "Removing Windows.old" -Completed
        Write-Host "Failed to remove Windows.old: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Consider using Disk Cleanup / Storage Sense instead." -ForegroundColor Yellow
    }
}


# -----------------------
# Network Reset (Disruptive)
# -----------------------
function Invoke-ITT-ResetNetwork {
    Write-Output "=== Network Reset (Disruptive) ==="

    ipconfig /flushdns
    ipconfig /release
    ipconfig /renew
    netsh winsock reset
    netsh int ip reset

    $services = @("Dhcp","Dnscache","NlaSvc","Netman","LanmanServer","LanmanWorkstation")
    foreach ($svc in $services) {
        Restart-Service $svc -ErrorAction SilentlyContinue
    }

    Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Write-Output "Cycling adapter: $($_.Name)"
        Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Enable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
    }

    Write-Output "=== Network Reset Complete ==="
}

# -----------------------
# Windows Update Reset
# -----------------------
function Invoke-ITT-ResetWindowsUpdate {
    Write-Output "=== Windows Update Reset ==="

    $services = @("wuauserv","bits","cryptsvc","msiserver")

    Write-Output "Stopping services..."
    foreach ($svc in $services) {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
    }

    Write-Output "Renaming SoftwareDistribution and catroot2..."
    Rename-Item "C:\Windows\SoftwareDistribution" ("SoftwareDistribution.old_" + (Get-Date -Format "yyyyMMddHHmmss")) -ErrorAction SilentlyContinue
    Rename-Item "C:\Windows\System32\catroot2" ("catroot2.old_" + (Get-Date -Format "yyyyMMddHHmmss")) -ErrorAction SilentlyContinue

    Write-Output "Starting services..."
    foreach ($svc in $services) {
        Start-Service $svc -ErrorAction SilentlyContinue
    }

    Write-Output "Triggering Windows Update scan..."
    Start-Process "UsoClient" -ArgumentList "StartScan" -ErrorAction SilentlyContinue

    Write-Output "=== Windows Update Reset Complete ==="
}

#-----------------------
#System cleanup
#-----------------------
function Invoke-ITT-SystemCleanup {
    Write-Host ""
    Write-Host "=== System Cleanup (logs, temp, cache) ===" -ForegroundColor Cyan

    if (-not (Invoke-ITT-AskYesNo "Proceed with system cleanup?")) {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        return
    }

    $paths = @(
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Logs",
        "$env:SystemRoot\SoftwareDistribution\Download",
        "$env:SystemRoot\System32\LogFiles",
        "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
        "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
    )

    $before = (Get-PSDrive C).Free

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Write-Host "Cleaning $p" -ForegroundColor Gray
            try {
                Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }

    $after    = (Get-PSDrive C).Free
    $diffGB   = [Math]::Round(($after - $before) / 1GB, 2)
    Write-Host ""
    Write-Host "System cleanup complete. Freed approximately $diffGB GB." -ForegroundColor Green
}

#------------------------
#Network port test (simple)
#-----------------------
function Invoke-ITT-TestPorts {
    param(
    [string]$TargetHost = "8.8.8.8",
    [int[]]$Ports = @(53,80,443)
  )

    Write-Host ""
    Write-Host "=== Port test to $Host ===" -ForegroundColor Cyan

    foreach ($port in $Ports) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $iar = $client.BeginConnect($Host, $port, $null, $null)
            $success = $iar.AsyncWaitHandle.WaitOne(2000, $false)

            if ($success -and $client.Connected) {
                Write-Host "Port ${port}: OPEN/REACHABLE" -ForegroundColor Green
            } else {
                Write-Host "Port ${port}: BLOCKED/TIMEOUT" -ForegroundColor Yellow
            }

            $client.Close()
        } catch {
            Write-Host "Port ${port}: ERROR ($($_.Exception.Message))" -ForegroundColor Red
        }
    }
}



# -----------------------
# Deep Health Scan (combo repairs)
# -----------------------
function Invoke-ITT-DeepHealthScan {
    Write-Output "=== Deep Health Scan (Combo) ==="
    Invoke-ITT-RepairWindows
    Invoke-ITT-ResetWindowsUpdate
    Invoke-ITT-ResetNetwork
    Write-Output "=== Deep Health Scan Done (reboot strongly recommended) ==="
}

# -----------------------
# Event Log Collector
# -----------------------
function Invoke-ITT-CollectLogs {
    Write-Output "Collecting System and Application logs..."

    $outDir = "$env:USERPROFILE\Desktop\EventLogs_" + (Get-Date -Format "yyyyMMddHHmmss")
    New-Item $outDir -ItemType Directory -Force | Out-Null

    wevtutil epl System "$outDir\system.evtx"
    wevtutil epl Application "$outDir\application.evtx"

    Write-Output "Logs saved to: $outDir"
}


# ==========================================
# FULL MODULE with integrated Outlook Tools
# ==========================================

# ROOT: Scripts folder
$Global:ITT_ScriptsRoot = "C:\Scripts2"

# -----------------------------------------------------
# Helper: Yes/No prompt
# -----------------------------------------------------
function Invoke-ITT-AskYesNo {
    param([string]$Message)
    while ($true) {
        $userInput = Read-Host "$Message [y/n]"
        switch ($userInput.ToLower()) {
            "y" { return $true }
            "n" { return $false }
            default { Write-Host "Please answer y or n." -ForegroundColor Yellow }
        }
    }
}

# -----------------------------------------------------
# Helper: Report Output
# -----------------------------------------------------
function Invoke-ITT-Report {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Cyan
}

# -----------------------------------------------------
# Simple Diagnostics
# -----------------------------------------------------
function Invoke-ITT-DiagnosticScan {
    param([string]$Mode)

    Invoke-ITT-Report "Running Diagnostic Scan ($Mode)..."

    Write-Host "Checking internet connectivity..." -ForegroundColor Yellow
    Test-Connection -Count 2 google.com | Out-Null

    Write-Host "Checking DNS resolution..." -ForegroundColor Yellow
    Resolve-DnsName microsoft.com -ErrorAction SilentlyContinue | Out-Null

    if ($Mode -eq "Standard") {
        Write-Host "Refreshing IP stack..." -ForegroundColor Yellow
        ipconfig /flushdns | Out-Null
        ipconfig /renew | Out-Null
    }

    if ($Mode -eq "Aggressive") {
        Write-Host "Resetting Winsock..." -ForegroundColor Yellow
        netsh winsock reset | Out-Null
    }

    if ($Mode -eq "Ultimate") {
        Write-Host "Performing deep scan (services & system logs)..." -ForegroundColor Yellow
        Get-Service | Out-Null
        Get-EventLog -LogName System -Newest 20 | Out-Null
    }

    Write-Host "Scan complete." -ForegroundColor Green
}

# -----------------------------------------------------
# Outlook Tools Section
# -----------------------------------------------------
# These are the ONLY 7 real-world Outlook fixes you usually need.

# 1) FULL Outlook Reset (kills Outlook, restarts Explorer, clears temp + lockfiles)
function Invoke-ITT-OutlookReset {
    Write-Host "`n=== Full Outlook Reset (attachments, crashes, file picker) ===" -ForegroundColor Cyan

    # Kill Outlook
    Write-Host "Killing Outlook process..." -ForegroundColor Yellow
    Get-Process OUTLOOK -ErrorAction SilentlyContinue | Stop-Process -Force

    # Restart Explorer (fixes file picker / attachments not opening)
    Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
    taskkill /f /im explorer.exe | Out-Null
    Start-Process explorer.exe | Out-Null

    # Clear Outlook temp cache (Content.Outlook)
    Write-Host "Clearing Outlook temp cache (Content.Outlook)..." -ForegroundColor Yellow
    $tempPath = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\Content.Outlook"
    if (Test-Path $tempPath) {
        Remove-Item -Path (Join-Path $tempPath '*') -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Clear common Office lockfiles from %TEMP%
    Write-Host "Clearing temporary Office lockfiles from %TEMP%..." -ForegroundColor Yellow
    $tempRoot = $env:TEMP
    if (Test-Path $tempRoot) {
        Get-ChildItem -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "~$*" -or $_.Extension -eq ".tmp" } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Outlook hard reset complete. Re-open Outlook and test attachments again." -ForegroundColor Green
}

# 2) Disable ALL Outlook add-ins (classic Safe Mode -> add-in issue)
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
                }
            }
        }
    }

    Write-Host "All add-ins disabled (where registry was accessible). Restart Outlook and test." -ForegroundColor Green
}

# 3) Rebuild OST (rename .ost so Outlook creates a fresh cache)
function Invoke-ITT-OutlookRebuildOST {
    Write-Host "`n=== Rebuild Outlook OST (offline cache) ===" -ForegroundColor Cyan
    Write-Host "This forces Outlook to download a fresh mailbox cache. Close Outlook before continuing." -ForegroundColor Yellow

    $ostRoot = Join-Path $env:LOCALAPPDATA "Microsoft\Outlook"
    if (-not (Test-Path $ostRoot)) {
        Write-Host "No OST folder found at $ostRoot" -ForegroundColor Red
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
    if ([string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    if (-not ([int]::TryParse($choice, [ref]$null))) {
        Write-Host "Invalid selection." -ForegroundColor Red
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
    }
}

# 4) Repair / reinstall WebView2 Runtime (modern Outlook shell)
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
    }
}

# 5) Reset Outlook Navigation Pane
function Invoke-ITT-OutlookResetNavPane {
    Write-Host "`n=== Reset Outlook Navigation Pane ===" -ForegroundColor Cyan
    Write-Host "This fixes 'Cannot start Microsoft Outlook' and broken / missing sidebars." -ForegroundColor Yellow

    $outlookPath = "outlook.exe"
    try {
        Start-Process $outlookPath -ArgumentList "/resetnavpane" -ErrorAction Stop
        Write-Host "Launched Outlook with /resetnavpane. If Outlook was closed, it will open with a fresh navigation pane." -ForegroundColor Green
    } catch {
        Write-Host "Failed to start Outlook with /resetnavpane. Is Outlook installed for this user?" -ForegroundColor Red
    }
}

# 6) Rebuild Outlook search index (via Windows Search)
function Invoke-ITT-OutlookRebuildSearchIndex {
    Write-Host "`n=== Rebuild Outlook / Windows Search Index ===" -ForegroundColor Cyan
    Write-Host "Use when Outlook search is empty, missing recent items or very slow." -ForegroundColor Yellow

    try {
        # This opens the classic Indexing Options control panel
        Start-Process "control.exe" -ArgumentList "srchadmin.dll" -ErrorAction Stop
        Write-Host "Indexing Options opened. From there, choose Advanced -> Rebuild." -ForegroundColor Green
    } catch {
        Write-Host "Could not open Indexing Options automatically. Search for 'Indexing Options' in Control Panel." -ForegroundColor Red
    }
}

# 7) Office Quick Repair
function Invoke-ITT-OfficeRepair {
    Write-Host "`n=== Office Quick Repair ===" -ForegroundColor Cyan
    Write-Host "This runs Office Click-to-Run repair. Use when Outlook binaries / DLLs are corrupted." -ForegroundColor Yellow

    $c2rPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    if (-not (Test-Path $c2rPath)) {
        $c2rPath = "C:\Program Files (x86)\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    }

    if (-not (Test-Path $c2rPath)) {
        Write-Host "OfficeC2RClient.exe not found. Office may not be Click-to-Run or is not installed in the default path." -ForegroundColor Red
        return
    }

    try {
        Start-Process $c2rPath -ArgumentList "/repair user" -ErrorAction Stop
        Write-Host "Office repair launched. Follow the on-screen wizard." -ForegroundColor Green
    } catch {
        Write-Host "Failed to launch Office repair: $_" -ForegroundColor Red
    }
}

# (Optional) Profile listing helper - kept for reference / advanced troubleshooting
function Invoke-ITT-OutlookProfileCheck {
    Write-Host "`n=== Outlook Profile Check ===" -ForegroundColor Cyan

    $profilesPath = "$env:APPDATA\Microsoft\Outlook"
    $profiles = Get-ChildItem $profilesPath -Filter *.xml -ErrorAction SilentlyContinue

    if (-not $profiles -or $profiles.Count -eq 0) {
        Write-Host "No Outlook XML profile definitions found in $profilesPath" -ForegroundColor Yellow
    }
    else {
        Write-Host "Profiles detected:" -ForegroundColor Yellow
        $profiles | ForEach-Object { Write-Host " - $($_.Name)" }
    }
}

# Outlook Tools menu (7 core fixes in one place)
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


# Export visible functions
Export-ModuleMember -Function *


# -----------------------
# Diagnostic Scan Engine
# -----------------------
function Invoke-ITT-DiagnosticScan {
    param(
        [ValidateSet("Safe","Standard","Aggressive")]
        [string]$Mode = "Safe"
    )

    $issues   = @()
    $warnings = @()
    $info     = @()
    $reco     = @()
    $score    = 100

    $info += "Scan mode: $Mode"
    $info += "Scan time: $(Get-Date)"

    # -------------------------
    # Progress tracking config
    # -------------------------
    # Base steps:
    #  1) C: free space
    #  2) Physical disk health
    #  3) Event logs
    #  4) WMI service
    #  5) Windows Update service
    #  6) Network / connectivity
    #  7) Browser cache
    #  8) Outlook OST size
    #  9) BIOS age
    #
    # Standard adds:
    # 10) DNS flush
    # 11) WebView2 check
    #
    # Aggressive adds:
    # 12) DISM /ScanHealth
    # 13) SFC /verifyonly

    switch ($Mode) {
        "Safe"       { $stepTotal = 9  }
        "Standard"   { $stepTotal = 11 }
        "Aggressive" { $stepTotal = 13 }
    }

    $stepIndex = 0

    function Get-ITTResultColor {
        param([string]$Result)
        switch ($Result) {
            "OK"   { "Green" }
            "WARN" { "Yellow" }
            "FAIL" { "Red" }
            "INFO" { "Cyan" }
            default { "Gray" }
        }
    }

    function Show-ITTStep {
        param(
            [string]$ModeLabel,
            [int]$StepIndex,
            [int]$StepTotal,
            [string]$StepLabel,
            [string]$Result
        )
        $pct   = [int](($StepIndex / $StepTotal) * 100)
        $color = Get-ITTResultColor $Result

        Write-Progress -Activity "IT Diagnostic Scan ($ModeLabel)" -Status "$StepLabel [$Result]" -PercentComplete $pct
        Write-Host ("[{0,3}%] {1} [{2}]" -f $pct, $StepLabel, $Result) -ForegroundColor $color
    }

    # -------------------------
    # 1) Disk space on C:
    # -------------------------
    $stepIndex++
    $label      = "Checking C: free space"
    $cDrive     = Get-PSDrive C
    $freeGB     = [Math]::Round($cDrive.Free / 1GB, 2)
    $stepResult = "OK"

    if ($freeGB -lt 10) {
        $issues   += "System drive low on space ($freeGB GB free)."
        $score    -= 10
        $stepResult = "FAIL"
    } elseif ($freeGB -lt 20) {
        $warnings += "System drive getting low on space ($freeGB GB free)."
        $score    -= 5
        $stepResult = "WARN"
    } else {
        $info     += "Disk space OK ($freeGB GB free)."
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 2) Physical disk health
    # -------------------------
    $stepIndex++
    $label      = "Checking physical disk health"
    $stepResult = "OK"

    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
        foreach ($d in $disks) {
            if ($d.HealthStatus -ne "Healthy") {
                $issues += "Disk '$($d.FriendlyName)' health is '$($d.HealthStatus)'."
                $score  -= 15
                $stepResult = "FAIL"
            }
        }
    } catch {
        $warnings += "Could not read physical disk health (Get-PhysicalDisk failed)."
        $stepResult = "WARN"
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 3) Event logs (last 24h)
    # -------------------------
    $stepIndex++
    $label      = "Checking event logs (last 24h)"
    $stepResult = "OK"

    $since     = (Get-Date).AddDays(-1)
    $sysErrors = (Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$since} -ErrorAction SilentlyContinue).Count
    $appErrors = (Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=$since} -ErrorAction SilentlyContinue).Count

    if ($sysErrors -gt 10 -or $appErrors -gt 10) {
        $warnings += "Many critical errors in last 24h (System: $sysErrors, Application: $appErrors)."
        $score    -= 5
        $stepResult = "WARN"
    } else {
        $info     += "Event logs OK (System: $sysErrors, Application: $appErrors critical errors in last 24h)."
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 4) WMI service
    # -------------------------
    $stepIndex++
    $label      = "Checking WMI service"
    $stepResult = "OK"

    $wmiService = Get-Service winmgmt -ErrorAction SilentlyContinue
    if ($wmiService.Status -ne "Running") {
        $issues += "WMI service not running (status: $($wmiService.Status))."
        $score  -= 10
        $stepResult = "FAIL"
    } else {
        $info   += "WMI service running."
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 5) Windows Update service
    # -------------------------
    $stepIndex++
    $label      = "Checking Windows Update service"
    $stepResult = "OK"

    $wuService = Get-Service wuauserv -ErrorAction SilentlyContinue
    if ($wuService.Status -ne "Running") {
        $warnings += "Windows Update service not running (status: $($wuService.Status))."
        $score    -= 5
        $stepResult = "WARN"
    } else {
        $info     += "Windows Update service running."
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 6) Network / connectivity (corporate-safe)
    # -------------------------
    $stepIndex++
    $label      = "Checking network & internet connectivity"
    $stepResult = "OK"

    try {
        $activeAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if (-not $activeAdapters) {
            $warnings += "No active physical network adapters detected."
            $score    -= 5
            $stepResult = "WARN"
        } else {
            $names = $activeAdapters | Select-Object -ExpandProperty Name
            $info += "Active adapters: $($names -join ', ')."
        }

        $ipConfigs = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
                     Where-Object { $_.NetAdapter.Status -eq "Up" }

        if (-not ($ipConfigs | Where-Object { $_.IPv4Address })) {
            $warnings += "No IPv4 address assigned to any active adapter."
            $score    -= 5
            $stepResult = "WARN"
        } else {
            $info += "IPv4 address present on at least one active adapter."
        }

        if (-not ($ipConfigs | Where-Object { $_.DNSServer.ServerAddresses })) {
            $warnings += "No DNS servers configured on active adapters."
            $score    -= 5
            $stepResult = "WARN"
        } else {
            $info += "DNS servers are configured."
        }

        # DNS resolution check (external, but via DNS only - no ping)
        try {
            Resolve-DnsName -Name "www.microsoft.com" -ErrorAction Stop | Out-Null
            $info += "DNS resolution OK for www.microsoft.com."
        } catch {
            $warnings += "DNS resolution failed for www.microsoft.com."
            $score    -= 5
            $stepResult = "WARN"
        }

        # HTTPS connectivity test (corporate-friendly, but may still be blocked by proxy/firewall)
        if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
            $httpsOk = Test-NetConnection -ComputerName "www.microsoft.com" -Port 443 -InformationLevel Quiet
            if ($httpsOk) {
                $info += "HTTPS connectivity OK (443 to www.microsoft.com)."
            } else {
                $warnings += "HTTPS connectivity to www.microsoft.com:443 failed (may be proxy/firewall or VPN)."
                $score    -= 3
                if ($stepResult -eq "OK") { $stepResult = "WARN" }
            }
        } else {
            $info += "Test-NetConnection not available; skipped direct HTTPS connectivity test."
        }
    } catch {
        $warnings += "Network check failed: $($_.Exception.Message)"
        $stepResult = "WARN"
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 7) Browser cache size
    # -------------------------
    $stepIndex++
    $label        = "Checking browser cache size"
    $stepResult   = "OK"
    $u            = $env:USERPROFILE
    $totalCacheMB = 0

    $chromeCache = "$u\AppData\Local\Google\Chrome\User Data\Default\Cache"
    $edgeCache   = "$u\AppData\Local\Microsoft\Edge\User Data\Default\Cache"

    foreach ($path in @($chromeCache, $edgeCache)) {
        if (Test-Path $path) {
            $size = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            $totalCacheMB += [Math]::Round(($size / 1MB),2)
        }
    }

    if ($totalCacheMB -gt 500) {
        $warnings += "Browser cache is large (about $totalCacheMB MB)."
        $score    -= 3
        $stepResult = "WARN"
    } else {
        $info     += "Browser cache size is reasonable (about $totalCacheMB MB)."
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 8) Outlook OST size
    # -------------------------
    $stepIndex++
    $label      = "Checking Outlook OST size"
    $stepResult = "INFO"

    $ostDir = "$u\AppData\Local\Microsoft\Outlook"
    if (Test-Path $ostDir) {
        $ostSize = (Get-ChildItem $ostDir -Filter *.ost -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        if ($ostSize -gt 0) {
            $ostGB = [Math]::Round($ostSize / 1GB, 2)
            if ($ostGB -gt 10) {
                $warnings += "Outlook OST total size is large (about $ostGB GB)."
                $score    -= 3
                $stepResult = "WARN"
            } else {
                $info     += "Outlook OST size is about $ostGB GB."
                $stepResult = "OK"
            }
        }
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 9) BIOS age (safer parsing)
    # -------------------------
    $stepIndex++
    $label      = "Checking BIOS age"
    $stepResult = "OK"

    try {
        $bios    = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $rawDate = $bios.ReleaseDate

        if (-not $rawDate) {
            throw "No BIOS release date reported."
        }

        if ($rawDate -is [string] -and $rawDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
            # Proper DMTF string
            $biosDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($rawDate)
        } elseif ($rawDate -is [datetime]) {
            # Some vendors already convert it
            $biosDate = $rawDate
        } else {
            # Fallback - try normal DateTime parse (handles strings like '30/06/2020 01:00:00')
            $biosDate = [datetime]::Parse($rawDate, [System.Globalization.CultureInfo]::InvariantCulture)
        }

        $ageYears = ((Get-Date) - $biosDate).TotalDays / 365
        $ageText  = [Math]::Round($ageYears,1)
        if ($ageYears -gt 5) {
            $warnings += "BIOS is old (about $ageText years). Consider update during maintenance window."
            $score    -= 3
            $stepResult = "WARN"
        } else {
            $info     += "BIOS age OK (about $ageText years)."
        }
    } catch {
        $warnings += "Could not determine BIOS age: $($_.Exception.Message)"
        $stepResult = "WARN"
    }
    Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

    # -------------------------
    # 10+) Standard / Aggressive extra actions
    # -------------------------
    if ($Mode -in @("Standard","Aggressive")) {
        $info += "Standard or Aggressive mode: running light repairs (DNS flush, WebView2 check)."

        # a) Ensure Windows Update service running
        if ($wuService.Status -ne "Running") {
            try {
                Start-Service wuauserv -ErrorAction SilentlyContinue
                $info += "Windows Update service restarted."
            } catch {
                $warnings += "Failed to restart Windows Update service in scan."
            }
        }

        # b) DNS flush
        $stepIndex++
        $label      = "Flushing DNS cache"
        $stepResult = "OK"
        try {
            ipconfig /flushdns | Out-Null
            $info += "DNS cache flushed."
        } catch {
            $warnings += "Failed to flush DNS during scan."
            $stepResult = "WARN"
        }
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

        # c) WebView2 check/reinstall
        $stepIndex++
        $label      = "Verifying WebView2 runtime"
        $stepResult = "OK"
        try {
            $wv = "$env:TEMP\EdgeWebView2.exe"
            Invoke-WebRequest "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $wv -UseBasicParsing
            Start-Process $wv -ArgumentList "/silent /install" -Wait
            Remove-Item $wv -Force
            $info += "WebView2 verified or reinstalled."
        } catch {
            $warnings += "WebView2 reinstall failed during scan."
            $stepResult = "WARN"
        }
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
    }

    if ($Mode -eq "Aggressive") {
        $info += "Aggressive mode: running DISM /ScanHealth and SFC /verifyonly (diagnostic only)."

        # DISM /ScanHealth
        $stepIndex++
        $label      = "DISM /ScanHealth"
        $stepResult = "OK"
        Write-Host ""
        Write-Host "Running DISM /ScanHealth... this can take several minutes, please wait." -ForegroundColor Cyan
        try {
            DISM /Online /Cleanup-Image /ScanHealth | Out-Null
        } catch {
            $issues += "DISM /ScanHealth reported a problem or failed."
            $score  -= 10
            $stepResult = "FAIL"
        }
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult

        # SFC /verifyonly
        $stepIndex++
        $label      = "SFC /verifyonly"
        $stepResult = "OK"
        Write-Host "Running SFC /verifyonly (no changes will be made)..." -ForegroundColor Cyan
        try {
            sfc /verifyonly | Out-Null
        } catch {
            $issues += "SFC /verifyonly reported a problem or failed."
            $score  -= 10
            $stepResult = "FAIL"
        }
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
    }

    # Ensure score doesn't go negative
    if ($score -lt 0) { $score = 0 }

    # -------------------------
    # Recommendations based on flags
    # -------------------------
    if ($freeGB -lt 10) {
        $reco += "Free disk space on C: (move large files, clean temp, or extend disk)."
    }

    if ($issues -like "*health is*") {
        $reco += "Disk health issues found. Plan disk replacement and backup user data."
    }

    if ($issues -like "*WMI service*") {
        $reco += "Run 'Windows Corruption Repair' and consider 'Deep Health Scan' if WMI stays unstable."
    }

    if ($warnings -like "*Many critical errors*") {
        $reco += "Review Application and System logs or use 'Collect Event Logs' for further analysis."
    }

    if ($warnings -like "*No IPv4 address assigned*" -or
        $warnings -like "*No DNS servers configured*" -or
        $warnings -like "*DNS resolution failed*" -or
        $warnings -like "*HTTPS connectivity*failed*") {
        $reco += "Network issues detected. If user is impacted, check adapter status, DNS settings, VPN, proxy, or run 'Network Reset'."
    }

    if ($warnings -like "*Browser cache is large*") {
        $reco += "Run 'Repair Browsers' to clear cache for web app issues."
    }

    if ($warnings -like "*OST total size is large*") {
        $reco += "Large Outlook OST. Consider 'Repair Office' or mailbox/archive split."
    }

    if ($warnings -like "*BIOS is old*") {
        $reco += "Consider BIOS update during a controlled maintenance window."
    }

    if ($Mode -eq "Aggressive" -and ($issues -like "*DISM /ScanHealth*" -or $issues -like "*SFC /verifyonly*")) {
        $reco += "Corruption detected. Run 'Windows Corruption Repair' from toolkit."
    }

    if ($reco.Count -eq 0) {
        $reco += "No major issues found. No immediate remediation required."
    }

    # -------------------------
    # Build report + output
    # -------------------------
    $lines = @()
    $lines += "IT Diagnostic Report"
    $lines += "===================="
    $lines += "Mode: $Mode"
    $lines += "Date: $(Get-Date)"
    $lines += ""
    $lines += "Health Score: $score / 100"
    $lines += ""
    $lines += "INFO:"
    if ($info.Count -gt 0) { $info | ForEach-Object { $lines += " - $_" } } else { $lines += " - (none)" }
    $lines += ""
    $lines += "WARNINGS:"
    if ($warnings.Count -gt 0) { $warnings | ForEach-Object { $lines += " - $_" } } else { $lines += " - (none)" }
    $lines += ""
    $lines += "ISSUES:"
    if ($issues.Count -gt 0) { $issues | ForEach-Object { $issuesLine = $_; $lines += " - $issuesLine" } } else { $lines += " - (none)" }
    $lines += ""
    $lines += "RECOMMENDED NEXT STEPS:"
    $reco | ForEach-Object { $lines += " - $_" }
    $lines += ""

    $reportText = $lines -join "`r`n"
    Invoke-ITT-SaveReport -ReportText $reportText -DefaultFileName ("IT_Diagnostic_" + $Mode)

    # Clear the progress bar at the end
    Write-Progress -Activity "IT Diagnostic Scan ($Mode)" -Completed -Status "Done"
}


# -----------------------
# Diagnostic Scan Menu
# -----------------------
function Invoke-ITT-ScanMenu {
    while ($true) {
        Write-Host ""
        Write-Host "========== DIAGNOSTIC SCANS ==========" -ForegroundColor Cyan
        Write-Host "1) Safe Scan      (read-only, no disruption)"
        Write-Host "2) Standard Scan  (light fixes, low risk)"
        Write-Host "3) Aggressive Scan (deep diagnostics, disruptive)"
        Write-Host "4) Back to main menu"
        Write-Host "======================================="
        $choice = Read-Host "Select scan mode (1-4)"

        switch ($choice) {
            "1" { Invoke-ITT-DiagnosticScan -Mode "Safe" }
            "2" { Invoke-ITT-DiagnosticScan -Mode "Standard" }
            "3" {
                Write-Host ""
                Write-Host "AGGRESSIVE SCAN WARNING:" -ForegroundColor Yellow
                Write-Host " - Can interrupt connectivity and VPN"
                Write-Host " - Should be used only when machine is already in bad state"
                if (Invoke-ITT-AskYesNo "Proceed with Aggressive Scan?") {
                    Invoke-ITT-DiagnosticScan -Mode "Aggressive"
                } else {
                    Write-Host "Aggressive scan cancelled." -ForegroundColor Yellow
                }
            }
            "4" { return }
            default { Write-Host "Invalid choice." -ForegroundColor Yellow }
        }
    }
}

#-----------------------
#Quick fixes menu
#----------------------
function Invoke-ITT-QuickFixMenu {
    while ($true) {
        Write-Host ""
        Write-Host "========== QUICK FIXES ==========" -ForegroundColor Cyan
        Write-Host "1) Flush DNS"
        Write-Host "2) Reset Winsock + Network Stack"
        Write-Host "3) Restart Explorer.exe"
        Write-Host "4) Restart Audio Services"
        Write-Host "5) Restart Print Spooler"
        Write-Host "6) Restart Windows Update Services"
        Write-Host "7) Clear TEMP files"
        Write-Host "8) Empty Recycle Bin"
        Write-Host "9) Rebuild Windows Store cache"
        Write-Host "10) Repair Windows Search Index"
        Write-Host "11) Reset OneDrive client"
        Write-Host "12) Startup Impact Report"
        Write-Host "0) Back to main menu"
        Write-Host "================================="
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Invoke-ITT-RunScriptFile "simple_scripts\flush_DNS.ps1" "Flush DNS cache" }
            "2" { Invoke-ITT-RunScriptFile "simple_scripts\reset_winsock_and_network_stack.ps1" "Reset Winsock and network stack" }
            "3" { Invoke-ITT-RunScriptFile "simple_scripts\restart_Explorer_exe.ps1" "Restart Explorer.exe" }
            "4" { Invoke-ITT-RunScriptFile "simple_scripts\restart_audio_services.ps1" "Restart audio services" }
            "5" { Invoke-ITT-RunScriptFile "simple_scripts\restart_print_spooler.ps1" "Restart print spooler" }
            "6" { Invoke-ITT-RunScriptFile "simple_scripts\restart_windows_update_services.ps1" "Restart Windows Update services" }
            "7" { Invoke-ITT-RunScriptFile "simple_scripts\clear_TEMP_files.ps1" "Clear TEMP files" }
            "8" { Invoke-ITT-RunScriptFile "simple_scripts\empty_recycle_bin.ps1" "Empty Recycle Bin" }
            "9" { Invoke-ITT-RunScriptFile "simple_scripts\rebuild_windows_store_cache.ps1" "Rebuild Windows Store cache" }
            "10"{ Invoke-ITT-RepairSearchIndex }
            "11"{ Invoke-ITT-ResetOneDrive }
            "12"{ Invoke-ITT-StartupImpactReport }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}

#-----------------------
# App nstaller menu
#----------------------

function Invoke-ITT-AppInstallMenu {
    while ($true) {
        Write-Host ""
        Write-Host "========== APP INSTALLERS ==========" -ForegroundColor Cyan
        Write-Host "1) Install Google Chrome"
        Write-Host "2) Install Mozilla Firefox"
        Write-Host "3) Install Microsoft Teams"
        Write-Host "4) Reinstall Microsoft Teams"
        Write-Host "5) Install Slack"
        Write-Host "6) Install 7-Zip"
        Write-Host "0) Back to main menu"
        Write-Host "===================================="
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Invoke-ITT-RunScriptFile "app_install\install_google_chrome.ps1" "Install Google Chrome" }
            "2" { Invoke-ITT-RunScriptFile "app_install\install_mozilla_firefox.ps1" "Install Mozilla Firefox" }
            "3" { Invoke-ITT-RunScriptFile "app_install\install_teams.ps1" "Install Microsoft Teams" }
            "4" { Invoke-ITT-RunScriptFile "app_install\reinstall_teams.ps1" "Reinstall Microsoft Teams" }
            "5" { Invoke-ITT-RunScriptFile "app_install\install_slack.ps1" "Install Slack" }
            "6" { Invoke-ITT-RunScriptFile "app_install\install_7-zip.ps1" "Install 7-Zip" }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}

#-----------------------
# Advanced maintenece menu
#-----------------------

function Invoke-ITT-AdvancedMaintenanceMenu {
    while ($true) {
        Write-Host ""
        Write-Host "====== ADVANCED MAINTENANCE ======" -ForegroundColor Cyan
        Write-Host "1) Full Windows Repair (DISM/SFC)"
        Write-Host "2) Reset Windows Update components"
        Write-Host "3) Repair WMI"
        Write-Host "4) Remove Windows bloatware"
        Write-Host "5) Repair Office (advanced script)"
        Write-Host "6) Reset Outlook profile"
        Write-Host "7) Clean old user profiles"
        Write-Host "8) BIOS update framework"
        Write-Host "9) Reset Windows Firewall"
        Write-Host "10) Reset Network Location Awareness (NLA)"
        Write-Host "11) Repair Windows Store / AppX"
        Write-Host "12) Scheduled Tasks Health Check"
        Write-Host "13) Driver Health Scan"
        Write-Host "0) Back to main menu"
        Write-Host "=================================="
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\full_windows_repair.ps1" "Full Windows repair" }
            "2" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\reset_windows_update_components.ps1" "Reset Windows Update components" }
            "3" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\repair_WMI.ps1" "Repair WMI" }
            "4" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\remove_windows_bloatware.ps1" "Remove Windows bloatware" }
            "5" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\repair_office.ps1" "Repair Office (advanced)" }
            "6" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\reset_outlook_profile.ps1" "Reset Outlook profile" }
            "7" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\clean_old_user_profiles.ps1" "Clean old user profiles" }
            "8" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\bios_update_framework.ps1" "BIOS update framework" }
            "9"  { Invoke-ITT-ResetFirewallDefaults }
            "10" { Invoke-ITT-ResetNLA }
            "11" { Invoke-ITT-RepairAppX }
            "12" { Invoke-ITT-RepairScheduledTasks }
            "13" { Invoke-ITT-DriverHealthScan }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}


#------------------------
# Cleanup memu
#-----------------------
function Invoke-ITT-CleanupMenu {
    while ($true) {
        Write-Host ""
        Write-Host "============ CLEANUP ============" -ForegroundColor Cyan
        Write-Host "1) Quick cleanup (TEMP + Recycle Bin)"
        Write-Host "2) System logs & update cache cleanup"
        Write-Host "3) Remove Windows.old"
        Write-Host "0) Back to main menu"
        Write-Host "================================="
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                Invoke-ITT-RunScriptFile "simple_scripts\clear_TEMP_files.ps1" "Clear TEMP files"
                Invoke-ITT-RunScriptFile "simple_scripts\empty_recycle_bin.ps1" "Empty Recycle Bin"
            }
            "2" { Invoke-ITT-SystemCleanup }
            "3" { Invoke-ITT-RemoveWindowsOld }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}

#-----------------------
# Printing tools menu
#-----------------------

function Invoke-ITT-PrintToolsMenu {
    while ($true) {
        Write-Host ""
        Write-Host "========== PRINTING TOOLS ==========" -ForegroundColor Cyan
        Write-Host "1) Restart print spooler (simple script)"
        Write-Host "2) Reset print spooler and clear queue (built-in)"
        Write-Host "0) Back to main menu"
        Write-Host "===================================="
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Invoke-ITT-RunScriptFile "simple_scripts\restart_print_spooler.ps1" "Restart print spooler" }
            "2" { Invoke-ITT-ResetPrintSpooler }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}

#-----------------------
#Network tools menu
#-----------------------
function Invoke-ITT-NetworkToolsMenu {
    while ($true) {
        Write-Host ""
        Write-Host "========== NETWORK TOOLS ==========" -ForegroundColor Cyan
        Write-Host "1) Flush DNS"
        Write-Host "2) Reset Winsock & Network Stack"
        Write-Host "3) Port test to 8.8.8.8 (53,80,443)"
        Write-Host "4) Run full Network Reset (from main toolkit)"
        Write-Host "5) DNS Diagnostic"
        Write-Host "0) Back to main menu"
        Write-Host "==================================="
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Invoke-ITT-RunScriptFile "simple_scripts\flush_DNS.ps1" "Flush DNS cache" }
            "2" { Invoke-ITT-RunScriptFile "simple_scripts\reset_winsock_and_network_stack.ps1" "Reset Winsock and network stack" }
            "3" { Invoke-ITT-TestPorts -Host "8.8.8.8" -Ports @(53,80,443) }
            "5" { Invoke-ITT-DNSDiagnostic }
            "4" { Invoke-ITT-ResetNetwork }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}

#--------------------------
#nuclear menu
#-------------------------
function Invoke-ITT-NuclearMenu {
    while ($true) {
        Write-Host ""
        Write-Host "========== NUCLEAR TOOLS ==========" -ForegroundColor Red
        Write-Host "1) Deep Health Scan (big combo fix)"
        Write-Host "2) Full Windows Repair (advanced script)"
        Write-Host "3) Reset Windows Update Components (advanced script)"
        Write-Host "0) Back to main menu"
        Write-Host "==================================="
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                Write-Host ""
                Write-Host "Deep Health Scan is disruptive and runs major repairs." -ForegroundColor Yellow
                if (Invoke-ITT-AskYesNo "Proceed with Deep Health Scan?") {
                    Invoke-ITT-DeepHealthScan
                } else {
                    Write-Host "Deep Health Scan cancelled." -ForegroundColor Yellow
                }
            }
            "2" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\full_windows_repair.ps1" "Full Windows repair (nuclear)" }
            "3" { Invoke-ITT-RunScriptFile "advanced_it_maintenance\reset_windows_update_components.ps1" "Reset Windows Update components (nuclear)" }
            "0" { return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}


# =========================================================
# NEW TOOLS: REPAIR, MAINTENANCE, NETWORK, ADVANCED
# (no repetition with existing tools)
# =========================================================

# -----------------------
# Windows Search Index Repair
# -----------------------
function Invoke-ITT-RepairSearchIndex {
    Write-Host ""
    Write-Host "=== Windows Search Index Repair ===" -ForegroundColor Cyan
    Write-Host "This will reset and rebuild the Windows Search index." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Proceed with Search Index reset?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Stopping Windows Search service..." -ForegroundColor Gray
        Stop-Service WSearch -Force -ErrorAction SilentlyContinue

        $indexPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
        if (Test-Path $indexPath) {
            Write-Host "Clearing index data at: $indexPath" -ForegroundColor Gray
            Remove-Item "$indexPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "Starting Windows Search service..." -ForegroundColor Gray
        Start-Service WSearch -ErrorAction SilentlyContinue

        Write-Host "Search index reset requested. Rebuild will happen in the background." -ForegroundColor Green
    } catch {
        Write-Host "Search index repair failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# Windows Store / AppX Repair
# -----------------------
function Invoke-ITT-RepairAppX {
    Write-Host ""
    Write-Host "=== Windows Store / AppX Repair ===" -ForegroundColor Cyan
    Write-Host "Re-registering built-in apps for ALL users. This may take several minutes." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Proceed with AppX / Store repair?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    try {
        Get-AppxPackage -AllUsers | ForEach-Object {
            Write-Host "Re-registering: $($_.Name)" -ForegroundColor Gray
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
            } catch {}
        }
        Write-Host "AppX / Store repair completed." -ForegroundColor Green
    } catch {
        Write-Host "AppX repair failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# Windows Firewall Reset
# -----------------------
function Invoke-ITT-ResetFirewallDefaults {
    Write-Host ""
    Write-Host "=== Windows Firewall Reset ===" -ForegroundColor Cyan
    Write-Host "This will reset Windows Firewall rules to default." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Proceed with firewall reset?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    try {
        netsh advfirewall reset | Out-Null
        Write-Host "Windows Firewall reset to defaults." -ForegroundColor Green
    } catch {
        Write-Host "Firewall reset failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# Network Location Awareness (NLA) Reset
# -----------------------
function Invoke-ITT-ResetNLA {
    Write-Host ""
    Write-Host "=== Network Location Awareness (NLA) Reset ===" -ForegroundColor Cyan
    Write-Host "This will restart NLA service and refresh network profiles." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Proceed with NLA reset?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Restarting NLA service..." -ForegroundColor Gray
        Restart-Service NlaSvc -Force -ErrorAction SilentlyContinue

        Write-Host "For full effect, consider rebooting or disconnecting/reconnecting network adapters." -ForegroundColor Green
    } catch {
        Write-Host "NLA reset failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# OneDrive Reset + Health Check
# -----------------------
function Invoke-ITT-ResetOneDrive {
    Write-Host ""
    Write-Host "=== OneDrive Reset ===" -ForegroundColor Cyan
    Write-Host "This will reset the OneDrive client for the current user." -ForegroundColor Yellow

    if (-not (Invoke-ITT-AskYesNo "Proceed with OneDrive reset?")) {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
    )

    $oneDriveExe = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $oneDriveExe) {
        Write-Host "OneDrive executable not found on this system." -ForegroundColor Red
        return
    }

    try {
        Write-Host "Stopping running OneDrive instances..." -ForegroundColor Gray
        Stop-Process -Name OneDrive -ErrorAction SilentlyContinue

        Write-Host "Running OneDrive reset..." -ForegroundColor Gray
        & $oneDriveExe "/reset"

        Start-Sleep -Seconds 5
        Write-Host "Starting OneDrive..." -ForegroundColor Gray
        Start-Process $oneDriveExe

        Write-Host "OneDrive reset triggered. Sync may take a while." -ForegroundColor Green
    } catch {
        Write-Host "OneDrive reset failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# Startup Impact Analyzer (simple)
# -----------------------
function Invoke-ITT-StartupImpactReport {
    Write-Host ""
    Write-Host "=== Startup Impact Report ===" -ForegroundColor Cyan
    Write-Host "Listing common startup entries (registry + Startup folders)." -ForegroundColor Yellow
    Write-Host ""

    # Registry startup (Run for current user + local machine)
    $runPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    Write-Host "--- Registry Startup (Run) ---" -ForegroundColor Cyan
    foreach ($path in $runPaths) {
        if (Test-Path $path) {
            Write-Host "[$path]" -ForegroundColor Gray
            Get-ItemProperty $path | Select-Object * | ForEach-Object {
                $_.PSObject.Properties |
                    Where-Object { $_.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider' } |
                    ForEach-Object {
                        "{0,-30} : {1}" -f $_.Name, $_.Value | Write-Host
                    }
            }
            Write-Host ""
        }
    }

    # Startup folder
    Write-Host "--- Startup Folder (per user) ---" -ForegroundColor Cyan
    $startupUser = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $startupUser) {
        Get-ChildItem $startupUser | Select-Object Name, FullName | Format-Table
    } else {
        Write-Host "No user Startup folder items." -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Review high-impact items and disable via Task Manager or msconfig as needed." -ForegroundColor Green
}

# -----------------------
# Scheduled Tasks Repair (light)
# -----------------------
function Invoke-ITT-RepairScheduledTasks {
    Write-Host ""
    Write-Host "=== Scheduled Tasks Health Check ===" -ForegroundColor Cyan
    Write-Host "Listing tasks in error/disabled state. No automatic changes will be made." -ForegroundColor Yellow
    Write-Host ""

    try {
        $tasks = Get-ScheduledTask -ErrorAction Stop
        $problemTasks = $tasks | Where-Object { $_.State -in @('Disabled','Queued','Unknown') }

        if (-not $problemTasks) {
            Write-Host "No obvious problematic scheduled tasks found." -ForegroundColor Green
        } else {
            $problemTasks | Select-Object TaskName, TaskPath, State | Format-Table
            Write-Host ""
            Write-Host "Use Task Scheduler to inspect and fix problematic tasks." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Failed to query Scheduled Tasks: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# Full DNS Diagnostic
# -----------------------
function Invoke-ITT-DNSDiagnostic {
    param(
        [string]$ExternalTestHost = "www.microsoft.com"
    )

    Write-Host ""
    Write-Host "=== DNS Diagnostic ===" -ForegroundColor Cyan

    try {
        $ipConfigs = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
                     Where-Object { $_.NetAdapter.Status -eq "Up" }

        if (-not $ipConfigs) {
            Write-Host "No active IP configuration detected." -ForegroundColor Yellow
        } else {
            Write-Host "Active adapters and DNS servers:" -ForegroundColor Gray
            foreach ($cfg in $ipConfigs) {
                $dns = $cfg.DnsServer.ServerAddresses -join ", "
                "{0} : IPv4={1} DNS=[{2}]" -f $cfg.InterfaceAlias, ($cfg.IPv4Address.IPAddress -join ','), $dns | Write-Host
            }
        }

        Write-Host ""
        Write-Host "Testing DNS resolution for $ExternalTestHost ..." -ForegroundColor Gray
        try {
            $res = Resolve-DnsName -Name $ExternalTestHost -ErrorAction Stop
            $ips = $res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress
            Write-Host "DNS OK: $ExternalTestHost resolves to: $($ips -join ', ')" -ForegroundColor Green
        } catch {
            Write-Host "DNS resolution FAILED for $ExternalTestHost : $($_.Exception.Message)" -ForegroundColor Red
        }
    } catch {
        Write-Host "DNS diagnostic failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# Driver Health Scan
# -----------------------
function Invoke-ITT-DriverHealthScan {
    Write-Host ""
    Write-Host "=== Driver Health Scan ===" -ForegroundColor Cyan
    Write-Host "Listing devices with errors or unknown status." -ForegroundColor Yellow
    Write-Host ""

    try {
        if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
            $bad = Get-PnpDevice | Where-Object { $_.Status -notin @('OK','Unknown') }
            if (-not $bad) {
                Write-Host "No obvious driver issues detected (no non-OK PnP devices)." -ForegroundColor Green
            } else {
                $bad | Select-Object Status, Class, FriendlyName, InstanceId | Format-Table -AutoSize
                Write-Host ""
                Write-Host "Consider updating/reinstalling drivers for the devices above." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Get-PnpDevice not available on this OS/PowerShell version." -ForegroundColor Red
        }
    } catch {
        Write-Host "Driver scan failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------
# Full Log Bundle Collector (extended)
# -----------------------
function Invoke-ITT-CollectFullLogBundle {
    Write-Host ""
    Write-Host "=== Full Log Bundle Collection ===" -ForegroundColor Cyan
    Write-Host "Collecting common diagnostics (event logs, CBS, DISM, WindowsUpdate, Office) into a ZIP on Desktop." -ForegroundColor Yellow

    $baseDir = "$env:USERPROFILE\Desktop\IT_Logs_" + (Get-Date -Format "yyyyMMddHHmmss")
    New-Item $baseDir -ItemType Directory -Force | Out-Null

    try {
        # Event logs (System + Application)
        wevtutil epl System      (Join-Path $baseDir "system.evtx")
        wevtutil epl Application (Join-Path $baseDir "application.evtx")
    } catch {}

    # CBS, DISM, WindowsUpdate logs
    $paths = @(
        "C:\Windows\Logs\CBS\CBS.log",
        "C:\Windows\Logs\DISM\dism.log",
        "C:\Windows\WindowsUpdate.log"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Copy-Item $p -Destination $baseDir -ErrorAction SilentlyContinue
        }
    }

    # Simple Office logs (if exist)
    $officeLogs = "$env:LOCALAPPDATA\Microsoft\Office\16.0\Logs"
    if (Test-Path $officeLogs) {
        $dest = Join-Path $baseDir "OfficeLogs"
        Copy-Item "$officeLogs\*" -Destination $dest -Recurse -ErrorAction SilentlyContinue
    }

    $zipPath = "$baseDir.zip"
    try {
        Compress-Archive -Path $baseDir -DestinationPath $zipPath -Force -ErrorAction SilentlyContinue
        Write-Host "Log bundle created: $zipPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create ZIP; logs remain in folder: $baseDir" -ForegroundColor Yellow
    }
}

# -----------------------
# HTML Report Exporter (generic)
# -----------------------
function Invoke-ITT-ExportHtmlReport {
    param(
        [Parameter(Mandatory)]
        [string]$ReportText,
        [string]$Title = "IT Diagnostic Report"
    )

    $desktop = [Environment]::GetFolderPath("Desktop")
    $file    = Join-Path $desktop ("IT_Report_{0}.html" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

    $htmlHeader = @"
<html>
<head>
    <meta charset="utf-8" />
    <title>$Title</title>
    <style>
        body { font-family: Consolas, monospace; background:#111; color:#eee; padding:20px; white-space:pre-wrap; }
        h1   { color:#4fc3f7; }
        .ok { color:#8bc34a; }
        .warn { color:#ffc107; }
        .fail { color:#f44336; }
    </style>
</head>
<body>
<h1>$Title</h1>
<pre>
"@

    $htmlFooter = @"
</pre>
</body>
</html>
"@

    $content = $htmlHeader + ($ReportText -replace '<','&lt;' -replace '>','&gt;') + $htmlFooter
    $content | Out-File -FilePath $file -Encoding UTF8

    Write-Host "HTML report saved to: $file" -ForegroundColor Green
}


# -----------------------
# MAIN MENU
# -----------------------

function Invoke-ITToolkit {
    while ($true) {
        Write-Host ""
        Write-Host "=============== IT TOOLKIT ===============" -ForegroundColor Cyan
        Write-Host " CORE"
        Write-Host "  1) Hardware Inventory"
        Write-Host "  2) Diagnostic Scans"
        Write-Host ""
        Write-Host " REPAIR TOOLS"
        Write-Host "  3) Quick Fixes"
        Write-Host "  4) Network Tools"
        Write-Host "  5) Windows Update Tools"
        Write-Host "  6) Outlook Tools (7-in-1)"
        Write-Host "  7) Office & Browser Repair"
        Write-Host "  8) Windows Repair (DISM / SFC / WMI)"
        Write-Host ""
        Write-Host " MAINTENANCE"
        Write-Host "  9) Cleanup Tools"
        Write-Host " 10) App Installers"
        Write-Host " 11) BIOS & Profile Tools"
        Write-Host " 12) Event Log Tools"
        Write-Host ""
        Write-Host " ADVANCED"
        Write-Host " 13) Deep Health Scan"
        Write-Host " 14) Nuclear Tools"
        Write-Host ""
        Write-Host "  0) Exit"
        Write-Host "==========================================" 
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1"  { Invoke-ITT-HardwareInventory }
            "2"  { Invoke-ITT-ScanMenu }
            "3"  { Invoke-ITT-QuickFixMenu }
            "4"  { Invoke-ITT-NetworkToolsMenu }
            "5"  { Invoke-ITT-ResetWindowsUpdate }
            "6"  { Invoke-ITT-OutlookToolsMenu }
            "7"  { Invoke-ITT-RepairOffice; Invoke-ITT-RepairBrowsers }
            "8"  { Invoke-ITT-RepairWindows }
            "9"  { Invoke-ITT-CleanupMenu }
            "10" { Invoke-ITT-AppInstallMenu }
            "11" { Invoke-ITT-AdvancedMaintenanceMenu }
            "12" { Invoke-ITT-CollectLogs }
            "13" { Invoke-ITT-DeepHealthScan }
            "14" { Invoke-ITT-NuclearMenu }
            "0"  { Write-Host "Exiting IT Toolkit..." -ForegroundColor Cyan; return }
            default { Write-Host "Invalid selection." -ForegroundColor Yellow }
        }
    }
}


Export-ModuleMember -Function Invoke-ITToolkit
