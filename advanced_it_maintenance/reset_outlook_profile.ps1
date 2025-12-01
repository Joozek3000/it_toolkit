# Reset Outlook Profile Script 

Write-Output "Resetting Outlook profile..."

$cmd = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
if (-not (Test-Path $cmd)) {
    $cmd = "C:\Program Files (x86)\Microsoft Office\root\Office16\OUTLOOK.EXE"
}

if (Test-Path $cmd) {
    Start-Process $cmd -ArgumentList "/resetnavpane"
    Write-Output "Outlook profile/resetnavpane executed."
} else {
    Write-Output "Outlook not found."
}
