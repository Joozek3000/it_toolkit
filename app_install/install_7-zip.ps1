# Install 7-Zip

$installer = "7zip.exe"
$url = "https://www.7-zip.org/a/7z2301-x64.exe"

Write-Output "Downloading 7-Zip..."
Invoke-WebRequest -Uri $url -OutFile $installer

Write-Output "Installing 7-Zip..."
Start-Process $installer -ArgumentList "/S" -Wait

Remove-Item $installer -Force
Write-Output "7-Zip installed successfully."
