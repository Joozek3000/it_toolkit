# PowerShell script to download and install Slack

$installer = "slack.exe"
$url = "https://downloads.slack-edge.com/releases/windows/production/SlackSetup.exe"

Write-Output "Downloading Slack..."
Invoke-WebRequest -Uri $url -OutFile $installer

Write-Output "Installing Slack..."
Start-Process $installer -ArgumentList "--silent" -Wait

Remove-Item $installer -Force
Write-Output "Slack installed successfully."
