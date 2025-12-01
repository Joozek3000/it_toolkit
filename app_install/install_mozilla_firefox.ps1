# Install Mozilla Firefox silently on Windows

$installer = "firefox.exe"
$url = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"

Write-Output "Downloading Firefox..."
Invoke-WebRequest -Uri $url -OutFile $installer

Write-Output "Installing Firefox..."
Start-Process $installer -ArgumentList "/S" -Wait

Remove-Item $installer -Force
Write-Output "Firefox installed successfully."
