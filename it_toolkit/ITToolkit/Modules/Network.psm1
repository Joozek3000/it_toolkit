# Network tools module

<#!
.SYNOPSIS
Performs a disruptive network reset.
.DESCRIPTION
Flushes DNS, releases/renews IP, resets Winsock and IP stack, restarts key services, and cycles adapters.
#>
function Invoke-ITT-ResetNetwork {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Write-Output "=== Network Reset (Disruptive) ==="

    if (-not (Invoke-ITT-AskYesNo "Proceed with full network reset? This is disruptive.")) {
        Write-Output "Network reset cancelled."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Network stack", "Reset DNS/Winsock/IP and cycle adapters")) {
        Write-Output "Network reset skipped."
        return
    }

    try { ipconfig /flushdns | Out-Null } catch { Write-Verbose "ResetNetwork: flushdns failed $_" }
    try { ipconfig /release | Out-Null } catch { Write-Verbose "ResetNetwork: release failed $_" }
    try { ipconfig /renew | Out-Null } catch { Write-Verbose "ResetNetwork: renew failed $_" }
    try { netsh winsock reset | Out-Null } catch { Write-Verbose "ResetNetwork: winsock reset failed $_" }
    try { netsh int ip reset | Out-Null } catch { Write-Verbose "ResetNetwork: ip reset failed $_" }

    $services = @("Dhcp","Dnscache","NlaSvc","Netman","LanmanServer","LanmanWorkstation")
    foreach ($svc in $services) {
        try { Restart-Service $svc -ErrorAction SilentlyContinue } catch { Write-Verbose "ResetNetwork: restart $svc failed $_" }
    }

    try {
        Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
            Write-Output "Cycling adapter: $($_.Name)"
            try { Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue } catch { Write-Verbose "ResetNetwork: disable $($_.Name) failed $_" }
            Start-Sleep -Seconds 3
            try { Enable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue } catch { Write-Verbose "ResetNetwork: enable $($_.Name) failed $_" }
        }
    } catch {
        Write-Verbose "ResetNetwork: adapter cycle failed $_"
    }

    Write-Output "=== Network Reset Complete ==="
}

<#!
.SYNOPSIS
Tests TCP connectivity to a host/port list.
.DESCRIPTION
Attempts TCP connections with a 2-second timeout per port and reports reachability.
.PARAMETER TargetHost
Host to test.
.PARAMETER Ports
Ports to test.
#>
function Invoke-ITT-TestPorts {
    param(
        [string]$TargetHost = "8.8.8.8",
        [int[]]$Ports = @(53,80,443)
    )

    Write-Host ""
    Write-Host "=== Port test to $TargetHost ===" -ForegroundColor Cyan

    foreach ($port in $Ports) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $iar = $client.BeginConnect($TargetHost, $port, $null, $null)
            $success = $iar.AsyncWaitHandle.WaitOne(2000, $false)

            if ($success -and $client.Connected) {
                Write-Host "Port ${port}: OPEN/REACHABLE" -ForegroundColor Green
            } else {
                Write-Host "Port ${port}: BLOCKED/TIMEOUT" -ForegroundColor Yellow
            }

            $client.Close()
        } catch {
            Write-Host "Port ${port}: ERROR ($($_.Exception.Message))" -ForegroundColor Red
            Write-Verbose "Invoke-ITT-TestPorts error on port $port : $($_.Exception.Message)"
        }
    }
}

<#!
.SYNOPSIS
Runs a DNS diagnostic.
.DESCRIPTION
Lists active adapters/DNS servers and tests resolution to a specified external host.
.PARAMETER ExternalTestHost
Host to resolve for testing.
#>
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
            Write-Verbose "Invoke-ITT-DNSDiagnostic resolution failed: $($_.Exception.Message)"
        }
    } catch {
        Write-Host "DNS diagnostic failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Invoke-ITT-DNSDiagnostic error: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Resets Windows Firewall to defaults.
.DESCRIPTION
Prompts for confirmation, runs netsh advfirewall reset.
#>
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
        Write-Verbose "Invoke-ITT-ResetFirewallDefaults failed: $($_.Exception.Message)"
    }
}

<#!
.SYNOPSIS
Resets Network Location Awareness.
.DESCRIPTION
Prompts, then restarts the NlaSvc service.
#>
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
        Write-Verbose "Invoke-ITT-ResetNLA failed: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Invoke-ITT-ResetNetwork,Invoke-ITT-TestPorts,Invoke-ITT-DNSDiagnostic,Invoke-ITT-ResetFirewallDefaults,Invoke-ITT-ResetNLA
