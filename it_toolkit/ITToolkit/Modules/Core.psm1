# Core helpers module for ITToolkit

<#!
.SYNOPSIS
Asks the user for a yes/no confirmation.
.DESCRIPTION
Prompts until a valid y/n is provided; returns $true for yes, $false for no.
.PARAMETER Message
Message to display.
.OUTPUTS
System.Boolean
#>
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

<#!
.SYNOPSIS
Saves or displays a report.
.DESCRIPTION
Prompts whether to show, save, or both for the given report text.
.PARAMETER ReportText
The report content.
.PARAMETER DefaultFileName
Base file name used when saving.
#>
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
            try {
                $ReportText | Out-File -FilePath $filePath -Encoding UTF8 -ErrorAction Stop
                Write-Host "Report saved to: $filePath" -ForegroundColor Green
            } catch {
                Write-Host "Failed to save report: $($_.Exception.Message)" -ForegroundColor Red
                Write-Verbose "Invoke-ITT-SaveReport failed to save to $filePath : $($_.Exception.Message)"
            }
        }
        "3" {
            Write-Host ""
            Write-Host $ReportText
            try {
                $ReportText | Out-File -FilePath $filePath -Encoding UTF8 -ErrorAction Stop
                Write-Host ""
                Write-Host "Report saved to: $filePath" -ForegroundColor Green
            } catch {
                Write-Host "Failed to save report: $($_.Exception.Message)" -ForegroundColor Red
                Write-Verbose "Invoke-ITT-SaveReport failed to save to $filePath : $($_.Exception.Message)"
            }
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

<#!
.SYNOPSIS
Clears the contents of a folder.
.DESCRIPTION
Removes all child items under the specified path. Returns silently if the path is missing.
.PARAMETER Path
Folder to clear.
.PARAMETER Quiet
Suppress Write-Host output when set.
#>
function Invoke-ITT-ClearFolder {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Quiet
    )

    if (-not (Test-Path $Path)) {
        Write-Verbose "Invoke-ITT-ClearFolder: path not found $Path"
        return
    }

    if (-not $Quiet) {
        Write-Host "Clearing: $Path" -ForegroundColor Gray
    }

    try {
        Remove-Item (Join-Path $Path '*') -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Verbose "Invoke-ITT-ClearFolder: failed to clear $Path : $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Downloads and reinstalls WebView2 runtime.
.DESCRIPTION
Fetches WebView2 installer, runs it silently, and cleans up the installer file.
.PARAMETER DownloadPath
Destination for the installer.
.PARAMETER Quiet
Suppress user-facing messages when set.
.OUTPUTS
System.Boolean
#>
function Invoke-ITT-ReinstallWebView2 {
    param(
        [string]$DownloadPath = (Join-Path $env:TEMP "EdgeWebView2.exe"),
        [switch]$Quiet
    )

    try {
        Write-Verbose "Downloading WebView2 to $DownloadPath"
        Invoke-WebRequest "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $DownloadPath -UseBasicParsing
        Write-Verbose "Starting WebView2 installer"
        Start-Process $DownloadPath -ArgumentList "/silent /install" -Wait -ErrorAction Stop
        if (Test-Path $DownloadPath) {
            Remove-Item $DownloadPath -Force -ErrorAction SilentlyContinue
            Write-Verbose "Removed installer $DownloadPath"
        }
        if (-not $Quiet) {
            Write-Host "WebView2 reinstall completed." -ForegroundColor Green
        }
        return $true
    } catch {
        if (-not $Quiet) {
            Write-Host "WebView2 installation failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Verbose "Invoke-ITT-ReinstallWebView2 failed: $($_.Exception.Message)"
        return $false
    }
}

<#!
.SYNOPSIS
Runs a toolkit script file.
.DESCRIPTION
Executes a script under $Global:ITT_ScriptsRoot with progress reporting and error handling.
.PARAMETER RelativePath
Relative script path (under $Global:ITT_ScriptsRoot).
.PARAMETER Description
Friendly description for progress/logging.
#>
function Invoke-ITT-RunScriptFile {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,     # e.g. "simple_scripts\flush_DNS.ps1"
        [string]$Description = ""
    )

    $fullPath = Join-Path $Global:ITT_ScriptsRoot $RelativePath

    if (-not (Test-Path $fullPath)) {
        Write-Host "Script not found: $fullPath" -ForegroundColor Red
        Write-Verbose "Invoke-ITT-RunScriptFile: missing script $fullPath"
        return
    }

    if ($Description) {
        Write-Host ""
        Write-Host "=== $Description ===" -ForegroundColor Cyan
    }

    try {
        Write-Verbose "Invoke-ITT-RunScriptFile: running $fullPath"
        Write-Progress -Activity "IT Toolkit" -Status $Description -PercentComplete 0
        & $fullPath
        Write-Progress -Activity "IT Toolkit" -Completed -Status "$Description - done"
        Write-Host ""
        Write-Host "$Description completed." -ForegroundColor Green
    } catch {
        Write-Progress -Activity "IT Toolkit" -Completed
        Write-Host "Error running $Description : $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Invoke-ITT-RunScriptFile error: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Writes a timestamped message.
.DESCRIPTION
Outputs a timestamped line for quick logging.
.PARAMETER Message
Message to write.
#>
function Invoke-ITT-Report {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Cyan
}

<#!
.SYNOPSIS
Exports an HTML report to the Desktop.
.DESCRIPTION
Builds a simple HTML report file containing the provided text.
.PARAMETER ReportText
Content to embed.
.PARAMETER Title
Title to display.
#>
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
    try {
        $content | Out-File -FilePath $file -Encoding UTF8 -ErrorAction Stop
        Write-Host "HTML report saved to: $file" -ForegroundColor Green
    } catch {
        Write-Host "Failed to save HTML report: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Invoke-ITT-ExportHtmlReport failed: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Invoke-ITT-AskYesNo,Invoke-ITT-SaveReport,Invoke-ITT-ClearFolder,Invoke-ITT-ReinstallWebView2,Invoke-ITT-RunScriptFile,Invoke-ITT-Report,Invoke-ITT-ExportHtmlReport
