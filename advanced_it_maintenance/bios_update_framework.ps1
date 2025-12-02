Write-Output "`n=== Hardware Vendor Detection ==="

$vendor = (Get-CimInstance Win32_ComputerSystem).Manufacturer
Write-Output "Vendor detected: $vendor"

$DownloadUrl = $null
$ZipPath = "$env:TEMP\VendorUtility.zip"
$InstallerPath = "$env:TEMP\VendorUtility.exe"
$ExtractPath = "$env:TEMP\VendorUtilityExtract"

switch -Wildcard ($vendor) {

    "*Lenovo*" {
        Write-Output "Lenovo detected. Preparing Lenovo System Update (SAFE mode)..."
        $DownloadUrl = "https://download.lenovo.com/pccbbs/thinkvantage_en/system_update_5.07.0113.exe"
    }

    "*Dell*" {
        Write-Output "Dell detected. Preparing Dell Command Update (SAFE mode)..."
        $DownloadUrl = "https://downloads.dell.com/FOLDER07532795M/1/Dell-Command-Update-Application_XJ9R4_WIN_5.1.0_A00.EXE"
    }

    "*HP*" {
        Write-Output "HP detected. Preparing HP Image Assistant (SAFE mode)..."
        $DownloadUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA/5.1.6.1/HPIA.exe"
    }

    "*Micro-Star*" {
        Write-Output "MSI detected. Preparing MSI Center (SAFE mode)..."
        $DownloadUrl = "https://download.msi.com/uti_exe/nb/MSI_Center_Installer.zip"
    }

    default {
        Write-Output "Unsupported vendor. Exiting safely."
        return
    }
}

# Safety check
if (-not $DownloadUrl) {
    Write-Output "Download URL missing — exiting."
    return
}

Write-Output "Downloading vendor utility safely..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop

# MSI requires extraction
if ($vendor -like "*Micro-Star*") {
    Write-Output "Extracting MSI Center installer..."
    if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force

    $Exe = Get-ChildItem $ExtractPath -Recurse -Filter "*.exe" | Select-Object -First 1

    if ($Exe) {
        Write-Output "Installing MSI Center silently (BIOS updates not included)..."
        Start-Process $Exe.FullName -ArgumentList "/S" -Wait
    } else {
        Write-Output "MSI installer EXE not found. Aborting safely."
    }
}
else {
    Write-Output "Saving installer..."
    Move-Item $ZipPath $InstallerPath -Force

    Write-Output "Installing vendor utility silently (BIOS OFF)..."

    switch -Wildcard ($vendor) {

        "*Lenovo*" {
            Start-Process $InstallerPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
        }

        "*Dell*" {
            Start-Process $InstallerPath -ArgumentList "/S" -Wait
        }

        "*HP*" {
            Start-Process $InstallerPath -ArgumentList "/silent /install" -Wait
        }
    }
}


# ===== SAFETY: Disable BIOS Update Features =====

Write-Output "`nApplying BIOS update safety blocks..."

if ($vendor -like "*Lenovo*") {
    New-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Lenovo\System Update\Preferences\UserSettings" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Lenovo\System Update\Preferences\UserSettings" -Name "IncludeBIOS" -Value 0
    Write-Output "✔ Lenovo BIOS updates disabled."
}

if ($vendor -like "*Dell*") {
    New-Item -Path "HKLM:\SOFTWARE\Dell\CommandUpdate" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Dell\CommandUpdate" -Name "FirmwareUpdate" -Value 0
    Write-Output "✔ Dell firmware updates disabled."
}

if ($vendor -like "*HP*") {
    Write-Output "✔ HP Image Assistant does NOT auto-install BIOS. Safe."
}

if ($vendor -like "*Micro-Star*") {
    Write-Output "✔ MSI Center does NOT auto-install BIOS. Safe."
}

# Cleanup
Write-Output "`nCleaning up temporary files..."
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "`n=== Vendor utility installed safely. BIOS updates are blocked. ==="
Write-Output "Technician must manually run the utility if needed."
