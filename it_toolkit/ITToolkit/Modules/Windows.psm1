# Windows repair and diagnostics module

<#!
.SYNOPSIS
Collects hardware inventory details.
.DESCRIPTION
Outputs system, BIOS, CPU, RAM, disk, and network adapter information.
#>
function Invoke-ITT-HardwareInventory {
    Write-Host ""
    Write-Host "=== Hardware Inventory ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $os = Get-CimInstance Win32_OperatingSystem
        $bios = Get-CimInstance Win32_BIOS
    } catch {
        Write-Host "Failed to query hardware info: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "HardwareInventory error: $($_.Exception.Message)"
        return
    }

    $cpuName = $null
    try {
        $cpuName = (Get-CimInstance Win32_Processor).Name
    } catch {
        Write-Verbose "HardwareInventory: CPU query failed $($_.Exception.Message)"
        $cpuName = "Unavailable"
    }

    $info = [ordered]@{
        "Computer Name"          = $env:COMPUTERNAME
        "Manufacturer"           = $cs.Manufacturer
        "Model"                  = $cs.Model
        "Serial Number"          = $bios.SerialNumber
        "BIOS Version"           = $bios.SMBIOSBIOSVersion
        "BIOS Date Raw"          = $bios.ReleaseDate
        "CPU"                    = $cpuName
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
    try { Get-PhysicalDisk | Select-Object FriendlyName, Size, MediaType, HealthStatus | Format-Table } catch { Write-Verbose "HardwareInventory: Get-PhysicalDisk failed $_" }

    Write-Host ""
    Write-Host "Network Adapters:" -ForegroundColor Cyan
    try { Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table } catch { Write-Verbose "HardwareInventory: Get-NetAdapter failed $_" }

    Write-Host ""
    Write-Host "=== Inventory Complete ===" -ForegroundColor Cyan
}

<#!
.SYNOPSIS
Runs Windows corruption repair (DISM/SFC/WMI).
.DESCRIPTION
Executes DISM /RestoreHealth, SFC /scannow, and repairs the WMI repository.
#>
function Invoke-ITT-RepairWindows {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Output "=== Windows Corruption Repair ==="

    if (-not $PSCmdlet.ShouldProcess("Windows image and system files", "DISM /RestoreHealth and SFC /scannow")) {
        Write-Output "Windows corruption repair skipped."
        return
    }

    Write-Output "Running DISM /RestoreHealth..."
    try {
        DISM /Online /Cleanup-Image /RestoreHealth
    } catch {
        Write-Output "DISM /RestoreHealth failed: $($_.Exception.Message)"
        Write-Verbose "RepairWindows: DISM failed $_"
    }

    Write-Output "Running SFC /scannow..."
    try {
        sfc /scannow
    } catch {
        Write-Output "SFC /scannow failed: $($_.Exception.Message)"
        Write-Verbose "RepairWindows: SFC failed $_"
    }

    Write-Output "Repairing WMI repository..."
    try {
        net stop winmgmt /y
        winmgmt /salvagerepository
        winmgmt /resetrepository
        net start winmgmt
    } catch {
        Write-Output "WMI repair error: $($_.Exception.Message)"
        Write-Verbose "RepairWindows: WMI repair failed $_"
    }

    Write-Output "=== Corruption Repair Complete (reboot recommended) ==="
}

<#! 
.SYNOPSIS
Resets Windows Update components.
.DESCRIPTION
Stops WU-related services, renames cache folders with timestamp, restarts services, and triggers a scan.
#>
function Invoke-ITT-ResetWindowsUpdate {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Output "=== Windows Update Reset ==="

    $services = @("wuauserv","bits","cryptsvc","msiserver")

    if (-not $PSCmdlet.ShouldProcess("Windows Update components", "Stop services and reset cache folders")) {
        Write-Output "Windows Update reset skipped."
        return
    }

    Write-Output "Stopping services..."
    foreach ($svc in $services) {
        try { Stop-Service $svc -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "ResetWindowsUpdate: stop $svc failed $_" }
    }

    Write-Output "Renaming SoftwareDistribution and catroot2..."
    try {
        if (Test-Path "C:\Windows\SoftwareDistribution") {
            Rename-Item "C:\Windows\SoftwareDistribution" ("SoftwareDistribution.old_" + (Get-Date -Format "yyyyMMddHHmmss")) -ErrorAction Stop
        }
        if (Test-Path "C:\Windows\System32\catroot2") {
            Rename-Item "C:\Windows\System32\catroot2" ("catroot2.old_" + (Get-Date -Format "yyyyMMddHHmmss")) -ErrorAction Stop
        }
    } catch {
        Write-Output "Failed to rename update cache folders: $($_.Exception.Message)"
        Write-Verbose "ResetWindowsUpdate rename failed: $($_.Exception.Message)"
    }

    Write-Output "Starting services..."
    foreach ($svc in $services) {
        try { Start-Service $svc -ErrorAction SilentlyContinue } catch { Write-Verbose "ResetWindowsUpdate: start $svc failed $_" }
    }

    Write-Output "Triggering Windows Update scan..."
    try { Start-Process "UsoClient" -ArgumentList "StartScan" -ErrorAction SilentlyContinue } catch { Write-Verbose "ResetWindowsUpdate: StartScan failed $_" }

    Write-Output "=== Windows Update Reset Complete ==="
}

<#! 
.SYNOPSIS
Runs combined deep health repairs.
.DESCRIPTION
Calls Windows repair, Windows Update reset, and network reset.
#>
function Invoke-ITT-DeepHealthScan {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Output "=== Deep Health Scan (Combo) ==="
    if (-not $PSCmdlet.ShouldProcess("Deep Health Scan", "RepairWindows + ResetWindowsUpdate + ResetNetwork")) {
        Write-Output "Deep Health Scan skipped."
        return
    }
    Invoke-ITT-RepairWindows
    Invoke-ITT-ResetWindowsUpdate
    Invoke-ITT-ResetNetwork
    Write-Output "=== Deep Health Scan Done (reboot strongly recommended) ==="
}

<#! 
.SYNOPSIS
Collects System and Application event logs.
.DESCRIPTION
Exports System and Application logs to an evtx pair on the user Desktop.
#>
function Invoke-ITT-CollectLogs {
    Write-Output "Collecting System and Application logs..."

    $outDir = "$env:USERPROFILE\Desktop\EventLogs_" + (Get-Date -Format "yyyyMMddHHmmss")
    New-Item $outDir -ItemType Directory -Force | Out-Null

    try { wevtutil epl System "$outDir\system.evtx" } catch { Write-Output "Failed to export System log: $($_.Exception.Message)"; Write-Verbose "CollectLogs System export failed $_" }
    try { wevtutil epl Application "$outDir\application.evtx" } catch { Write-Output "Failed to export Application log: $($_.Exception.Message)"; Write-Verbose "CollectLogs Application export failed $_" }

    Write-Output "Logs saved to: $outDir"
}

<#!
.SYNOPSIS
Repairs Windows Search index.
.DESCRIPTION
Stops the search service, clears index data, and restarts the service after confirmation.
#>
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
            try { Remove-Item "$indexPath\*" -Recurse -Force -ErrorAction Stop } catch { Write-Verbose "RepairSearchIndex: failed to clear $indexPath : $($_.Exception.Message)" }
        } else {
            Write-Verbose "RepairSearchIndex: index path missing $indexPath"
        }

        Write-Host "Starting Windows Search service..." -ForegroundColor Gray
        Start-Service WSearch -ErrorAction SilentlyContinue

        Write-Host "Search index reset requested. Rebuild will happen in the background." -ForegroundColor Green
    } catch {
        Write-Host "Search index repair failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "RepairSearchIndex failed: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Repairs Windows Store / AppX packages.
.DESCRIPTION
Re-registers built-in apps for all users after confirmation.
#>
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
            } catch {
                Write-Verbose "RepairAppX: failed to register $($_.InstallLocation) : $($_.Exception.Message)"
            }
        }
        Write-Host "AppX / Store repair completed." -ForegroundColor Green
    } catch {
        Write-Host "AppX repair failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "RepairAppX failed: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Checks scheduled tasks for problem states.
.DESCRIPTION
Lists tasks in Disabled/Queued/Unknown states without changing them.
#>
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
        Write-Verbose "RepairScheduledTasks failed: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Runs a driver health scan.
.DESCRIPTION
Lists PnP devices with non-OK status.
#>
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
        Write-Verbose "DriverHealthScan failed: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Collects extended log bundle.
.DESCRIPTION
Copies common diagnostics (event logs, CBS, DISM, WindowsUpdate, Office) and zips them if possible.
#>
function Invoke-ITT-CollectFullLogBundle {
    Write-Host ""
    Write-Host "=== Full Log Bundle Collection ===" -ForegroundColor Cyan
    Write-Host "Collecting common diagnostics (event logs, CBS, DISM, WindowsUpdate, Office) into a ZIP on Desktop." -ForegroundColor Yellow

    $baseDir = "$env:USERPROFILE\Desktop\IT_Logs_" + (Get-Date -Format "yyyyMMddHHmmss")
    New-Item $baseDir -ItemType Directory -Force | Out-Null

    try {
        wevtutil epl System      (Join-Path $baseDir "system.evtx")
        wevtutil epl Application (Join-Path $baseDir "application.evtx")
    } catch {
        Write-Verbose "CollectFullLogBundle: exporting event logs failed $_"
    }

    $paths = @(
        "C:\Windows\Logs\CBS\CBS.log",
        "C:\Windows\Logs\DISM\dism.log",
        "C:\Windows\WindowsUpdate.log"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            try { Copy-Item $p -Destination $baseDir -ErrorAction Stop } catch { Write-Verbose "CollectFullLogBundle: copy $p failed $_" }
        } else {
            Write-Verbose "CollectFullLogBundle: path missing $p"
        }
    }

    $officeLogs = "$env:LOCALAPPDATA\Microsoft\Office\16.0\Logs"
    if (Test-Path $officeLogs) {
        $dest = Join-Path $baseDir "OfficeLogs"
        try { Copy-Item "$officeLogs\*" -Destination $dest -Recurse -ErrorAction Stop } catch { Write-Verbose "CollectFullLogBundle: copy Office logs failed $_" }
    }

    $zipPath = "$baseDir.zip"
    try {
        Compress-Archive -Path $baseDir -DestinationPath $zipPath -Force -ErrorAction Stop
        Write-Host "Log bundle created: $zipPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create ZIP; logs remain in folder: $baseDir" -ForegroundColor Yellow
        Write-Verbose "CollectFullLogBundle: zip failed $_"
    }
}

<#!
.SYNOPSIS
Runs an IT diagnostic scan.
.DESCRIPTION
Performs multi-step health checks with optional repairs depending on mode.
.PARAMETER Mode
Scan mode: Safe, Standard, Aggressive.
#>
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

    try {
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
    } catch {
        $warnings += "Disk space check failed: $($_.Exception.Message)"
    }

    try {
        $stepIndex++
        $label      = "Checking physical disk health"
        $stepResult = "OK"

        $disks = Get-PhysicalDisk -ErrorAction Stop
        foreach ($d in $disks) {
            if ($d.HealthStatus -ne "Healthy") {
                $issues += "Disk '$($d.FriendlyName)' health is '$($d.HealthStatus)'."
                $score  -= 15
                $stepResult = "FAIL"
            }
        }
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
    } catch {
        $warnings += "Could not read physical disk health (Get-PhysicalDisk failed)."
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking physical disk health" -Result "WARN"
    }

    try {
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
    } catch {
        $warnings += "Event log check failed: $($_.Exception.Message)"
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking event logs" -Result "WARN"
    }

    try {
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
    } catch {
        $warnings += "WMI service check failed: $($_.Exception.Message)"
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking WMI service" -Result "WARN"
    }

    try {
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
    } catch {
        $warnings += "Windows Update service check failed: $($_.Exception.Message)"
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking Windows Update service" -Result "WARN"
    }

    try {
        $stepIndex++
        $label      = "Checking network & internet connectivity"
        $stepResult = "OK"

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

        try {
            Resolve-DnsName -Name "www.microsoft.com" -ErrorAction Stop | Out-Null
            $info += "DNS resolution OK for www.microsoft.com."
        } catch {
            $warnings += "DNS resolution failed for www.microsoft.com."
            $score    -= 5
            $stepResult = "WARN"
        }

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
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
    } catch {
        $warnings += "Network check failed: $($_.Exception.Message)"
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking network & internet connectivity" -Result "WARN"
    }

    try {
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
    } catch {
        $warnings += "Browser cache check failed: $($_.Exception.Message)"
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking browser cache size" -Result "WARN"
    }

    try {
        $stepIndex++
        $label      = "Checking Outlook OST size"
        $stepResult = "INFO"

        $ostDir = "$env:USERPROFILE\AppData\Local\Microsoft\Outlook"
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
    } catch {
        $warnings += "OST size check failed: $($_.Exception.Message)"
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking Outlook OST size" -Result "WARN"
    }

    try {
        $stepIndex++
        $label      = "Checking BIOS age"
        $stepResult = "OK"

        $bios    = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $rawDate = $bios.ReleaseDate

        if (-not $rawDate) {
            throw "No BIOS release date reported."
        }

        if ($rawDate -is [string] -and $rawDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
            $biosDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($rawDate)
        } elseif ($rawDate -is [datetime]) {
            $biosDate = $rawDate
        } else {
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
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
    } catch {
        $warnings += "Could not determine BIOS age: $($_.Exception.Message)"
        Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Checking BIOS age" -Result "WARN"
    }

    if ($Mode -in @("Standard","Aggressive")) {
        $info += "Standard or Aggressive mode: running light repairs (DNS flush, WebView2 check)."

        if ($wuService.Status -ne "Running") {
            try {
                Start-Service wuauserv -ErrorAction SilentlyContinue
                $info += "Windows Update service restarted."
            } catch {
                $warnings += "Failed to restart Windows Update service in scan."
            }
        }

        try {
            $stepIndex++
            $label      = "Flushing DNS cache"
            $stepResult = "OK"
            ipconfig /flushdns | Out-Null
            $info += "DNS cache flushed."
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
        } catch {
            $warnings += "Failed to flush DNS during scan."
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Flushing DNS cache" -Result "WARN"
        }

        try {
            $stepIndex++
            $label      = "Verifying WebView2 runtime"
            $stepResult = "OK"
            if (Invoke-ITT-ReinstallWebView2 -Quiet) {
                $info += "WebView2 verified or reinstalled."
            } else {
                $warnings += "WebView2 reinstall failed during scan."
                $stepResult = "WARN"
            }
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
        } catch {
            $warnings += "WebView2 check failed: $($_.Exception.Message)"
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "Verifying WebView2 runtime" -Result "WARN"
        }
    }

    if ($Mode -eq "Aggressive") {
        $info += "Aggressive mode: running DISM /ScanHealth and SFC /verifyonly (diagnostic only)."

        try {
            $stepIndex++
            $label      = "DISM /ScanHealth"
            $stepResult = "OK"
            Write-Host ""
            Write-Host "Running DISM /ScanHealth... this can take several minutes, please wait." -ForegroundColor Cyan
            DISM /Online /Cleanup-Image /ScanHealth | Out-Null
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
        } catch {
            $issues += "DISM /ScanHealth reported a problem or failed."
            $score  -= 10
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "DISM /ScanHealth" -Result "FAIL"
        }

        try {
            $stepIndex++
            $label      = "SFC /verifyonly"
            $stepResult = "OK"
            Write-Host "Running SFC /verifyonly (no changes will be made)..." -ForegroundColor Cyan
            sfc /verifyonly | Out-Null
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel $label -Result $stepResult
        } catch {
            $issues += "SFC /verifyonly reported a problem or failed."
            $score  -= 10
            Show-ITTStep -ModeLabel $Mode -StepIndex $stepIndex -StepTotal $stepTotal -StepLabel "SFC /verifyonly" -Result "FAIL"
        }
    }

    if ($score -lt 0) { $score = 0 }

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

    if ($warnings -like "*DNS resolution failed*") {
        $reco += "DNS issues detected. Check DNS servers or run Network Tools -> DNS Diagnostic."
    }

    if ($warnings -like "*Browser cache is large*") {
        $reco += "Clear browser cache via 'Browser Repair' under Office & Browser Repair."
    }

    if ($warnings -like "*Outlook OST total size is large*") {
        $reco += "Large Outlook OST. Consider 'Repair Office' or mailbox/archive split."
    }

    if ($warnings -like "*BIOS is old*") {
        $reco += "BIOS may need update; check vendor site during maintenance window."
    }

    if ($issues -like "*DISM /ScanHealth*") {
        $reco += "Corruption detected. Run 'Windows Corruption Repair' from toolkit."
    }

    if ($reco.Count -eq 0) {
        $reco += "No major issues found. No immediate remediation required."
    }

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

    Write-Progress -Activity "IT Diagnostic Scan ($Mode)" -Completed -Status "Done"
}

Export-ModuleMember -Function Invoke-ITT-HardwareInventory,Invoke-ITT-RepairWindows,Invoke-ITT-ResetWindowsUpdate,Invoke-ITT-DeepHealthScan,Invoke-ITT-CollectLogs,Invoke-ITT-RepairSearchIndex,Invoke-ITT-RepairAppX,Invoke-ITT-RepairScheduledTasks,Invoke-ITT-DriverHealthScan,Invoke-ITT-CollectFullLogBundle,Invoke-ITT-DiagnosticScan
