# BIOS Update Framework (Vendor Detection)

Write-Output "Detecting hardware vendor..."

$vendor = (Get-CimInstance Win32_ComputerSystem).Manufacturer
Write-Output "Vendor detected: $vendor"

$DownloadUrl = $null
$Installer = "$env:TEMP\VendorUpdate.exe"

switch -Wildcard ($vendor) {

    "*Lenovo*" {
        Write-Output "Lenovo system detected. Preparing Lenovo System Update..."
        $DownloadUrl = "https://download.lenovo.com/pccbbs/thinkvantage_en/system_update_5.07.0113.exe"
    }

    "*Dell*" {
        Write-Output "Dell system detected. Preparing Dell Command Update..."
        $DownloadUrl = "https://downloads.dell.com/FOLDER07532795M/1/Dell-Command-Update-Application_XJ9R4_WIN_5.1.0_A00.EXE"
    }

    "*HP*" {
        Write-Output "HP system detected. Preparing HP Image Assistant..."
        $DownloadUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA/5.1.6.1/HPIA.exe"
    }

    "*Micro-Star*" {
        Write-Output "MSI system detected. Preparing MSI Center..."
        # MSI Center Installer (EXE inside a ZIP)
        $DownloadUrl = "https://download.msi.com/uti_exe/nb/MSI_Center_Installer.zip"
    }

    default {
        Write-Output "Unsupported vendor. BIOS update utility will not be installed."
        return
    }
}

# Safety check
if (-not $DownloadUrl) {
    Write-Output "No download URL available for this vendor."
    return
}

Write-Output "Downloading vendor update utility..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile "$Installer.zip" -UseBasicParsing

# MSI requires unzip step
if ($vendor -like "*Micro-Star*") {
    Write-Output "Extracting MSI Center installer..."
    Expand-Archive "$Installer.zip" -DestinationPath $env:TEMP -Force

    # Find the EXE inside the extracted folder
    $ExtractedExe = Get-ChildItem $env:TEMP -Recurse -Filter "*.exe" | Select-Object -First 1

    if ($ExtractedExe) {
        Write-Output "Installing MSI Center..."
        Start-Process $ExtractedExe.FullName -ArgumentList "/S" -Wait
    } else {
        Write-Output "MSI installer EXE not found!"
    }
}
else {
    # Other vendors install directly
    Write-Output "Installing vendor update utility..."
    Start-Process $Installer -ArgumentList "/S" -Wait
}

Write-Output "Cleaning up installer files..."
Remove-Item "$Installer*" -Force -ErrorAction SilentlyContinue
Remove-Item "$Installer.zip" -Force -ErrorAction SilentlyContinue

Write-Output "Vendor update utility installed successfully."
