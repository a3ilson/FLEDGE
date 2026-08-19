# Create timestamped output directory
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputDir = "$PSScriptRoot\FLEDGE_Nest - $timestamp.txt"
$DependenciesDir = join-path $PSScriptRoot "Dependencies"
New-Item -ItemType Directory -Path $outputDir | Out-Null

Write-Host "Welcome to FLEDGE, the Forensic Live Evidence Data Gathering Engine (FLEDGE)" -ForegroundColor darkcyan
Write-Host "Version: 1.0.0-WIN-NET-LIVE" -ForegroundColor darkcyan
Write-Host "Compiled 2026 by PARAS N." -ForegroundColor DarkCyan
Write-Host "====================================================================="-ForegroundColor White
Write-Host "Collecting live evidence...DO NOT DISTURB" -ForegroundColor DarkYellow
Write-Host "Access is denied messages may appear. Please be patient." -ForegroundColor DarkGray
Write-Host "Saving.... $outputDir"

# 1. System Info
Get-ComputerInfo | Out-File "$outputDir\system_info_$timestamp.txt"

# 2. Running Processes
tasklist > "$outputDir\open-processes_$timestamp.txt"
& "$DependenciesDir\pslist.exe" > "$outputDir\running-processes_$timestamp.txt"
& "$DependenciesDir\psservice.exe" > "$outputDir\running-services_$timestamp.txt"

# 3. Open Files
& "$DependenciesDir\psfile.exe" > "$outputDir\open-files_$timestamp.txt"

# 4. Who is logged on?
& "$DependenciesDir\psloggedon.exe" > "$outputDir\whoison_$timestamp.txt"

# 5. Network Configuration
Get-NetIPConfiguration | Format-List * | Out-File "$outputDir\net_ip_config_$timestamp.txt"

# 6. Extract Default Gateway (Router IP)
$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
Sort-Object RouteMetric |
Select-Object -First 1).NextHop

"Default Gateway (Router): $gateway" | Out-File "$outputDir\router_info_$timestamp.txt"

# 7. ARP Table (IP ↔ MAC)
Get-NetNeighbor | Out-File "$outputDir\arp_table_$timestamp.txt"

# 8. Active Connections
Get-NetTCPConnection | Out-File "$outputDir\net_tcp_connections_$timestamp.txt"

# 9. Listening Ports
Get-NetTCPConnection -State Listen | Out-File "$outputDir\listening_ports_$timestamp.txt"

# 10. Route Table
Get-NetRoute | Out-File "$outputDir\route_table_$timestamp.txt"

# 11. Ping Router
Test-Connection -ComputerName $gateway -Count 3 |
Out-File "$outputDir\router_ping_$timestamp.txt"

# 12. Network Sweep (adjust subnet if needed)
$subnet = ($gateway -replace "\.\d+$",".")
1..254 | ForEach-Object {
$ip = "$subnet$_"
if (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
"$ip is alive" | Out-File "$outputDir\network_sweep_$timestamp.txt" -Append
}
}

# 13. Resolve MACs after sweep
Get-NetNeighbor | Out-File "$outputDir\arp_after_sweep_$timestamp.txt"

# 14. Wi-Fi Networks (if applicable)
netsh wlan show networks mode=bssid | Out-File "$outputDir\wifi_networks_$timestamp.txt"

# 15. Saved Wi-Fi Profiles
netsh wlan show profiles | Out-File "$outputDir\wifi_profiles_$timestamp.txt"


# =========================
# Hash ALL generated output files 
# =========================
try {
    $hashCsv = "$outputDir\file_hashes_SHA256_$timestamp.csv"
    $files = Get-ChildItem -Path $outputDir -File -Recurse

    $rows = foreach ($f in $files) {
        $h = Get-FileHash -Path $f.FullName -Algorithm SHA256
        [pscustomobject]@{
            FileName = $f.Name
            FullPath = $f.FullName
            Length   = $f.Length
            SHA256   = $h.Hash
        }
    }

    $rows | Export-Csv -Path $hashCsv -NoTypeInformation -Encoding UTF8
}
catch {
    throw
}


Write-Host "Collection complete." -ForegroundColor DarkYellow
Write-Host "Data successfully aggregated in $outputDir"
