<#
  pulseboard-desktop - Continuous network / VoIP path diagnostic for Windows
  v1.0  (https://github.com/Cramraika/pulseboard-desktop)

  Full-day, continuous, multi-vertical capture. No manual triggers. Meant to
  run for several hours on a Windows laptop sitting on a single Wi-Fi. For
  A/B comparison between two Wi-Fis (or two ISPs), run the same script on
  two laptops with different -Tag values.

  Usage:
    .\diag.ps1 -PreflightOnly -Tag smoke
    .\diag.ps1 -Duration 150 -Tag wifi-A
    .\diag.ps1 -Duration 570 -Tag wifi-B

  Requirements (install with .\install.ps1 or manually per docs/QUICKSTART.md;
  script degrades gracefully and reports missing tools in PREFLIGHT.txt):
    speedtest.exe (Ookla), iperf3.exe (ar51an Win build), tshark.exe (Wireshark)
  MTR uses Windows built-in `pathping`.

  User config: copy `config.example.ps1` -> `config.ps1` and edit. The script
  dot-sources config.ps1 if present (overrides $Targets, $PortGrid, $SipTarget,
  etc) and falls back to the generic anycast-control defaults below otherwise.

  Output: C:\NMDiag\<timestamp>-<tag>\  (see docs/OUTPUT_SCHEMA.md for layout)
#>
[CmdletBinding()]
param(
  [int]$Duration = 570,
  [int]$Interval = 60,
  [string]$Tag = "run",
  [string]$BaseDir = "C:\NMDiag",
  # Preflight-only mode: runs every capability ONCE (baseline + preflight steps
  # including a real MTR cycle and a real speedtest), writes PREFLIGHT.txt with
  # PASS/DEGR/FAIL per item, then exits without entering the main loop.
  # Use this as a smoke test (~3-5 min) instead of running the multi-hour loop.
  [switch]$PreflightOnly
)

$ErrorActionPreference = "SilentlyContinue"   # Silence non-terminating errors (TCP refused, DNS fails, etc - we log them deliberately)
$ProgressPreference    = "SilentlyContinue"
$WarningPreference     = "SilentlyContinue"

# ---- Config (defaults - override in config.ps1) ---------------------------
# Targets split intentionally into two "tiers" for the ISP-peering hypothesis:
#   *_dns  = resolver anycast (ISPs usually fast-lane these)
#   *_cdn / *_api = CDN/HTTPS anycast (the path real HTTPS / VoIP actually rides)
# If *_dns stays clean during a bad window while *_cdn/_api degrades, the ISP
# is fast-laning DNS and deprioritising normal HTTPS - the exact pattern that
# would cause VoIP call degradation while 1.1.1.1 pings look fine.
#
# To add YOUR VoIP SBC / SIP gateway as a tracked target, copy config.example.ps1
# to config.ps1 and uncomment / edit the relevant block. See docs/VOIP_PROVIDERS.md
# for pre-written snippets covering common providers (Twilio, RingCentral,
# 3CX, FreePBX, Asterisk, Zoom Phone, Vonage, etc).
$Targets = @(
  @{ Name="cloudflare_dns";  Ip="1.1.1.1";        Port=443 },
  @{ Name="cloudflare_cdn";  Ip="104.16.132.229"; Port=443 },   # api.cloudflare.com range
  @{ Name="google_dns";      Ip="8.8.8.8";        Port=443 },
  @{ Name="google_api";      Ip="142.250.193.100";Port=443 },   # Google Front-End anycast
  @{ Name="microsoft_teams"; Ip="13.107.42.14";   Port=443 }    # MS 365 / Teams anycast
)
$AnycastPairs = @(
  # Same-service anycast divergence (near-vs-far PoP):
  @{ a="1.1.1.1"; b="1.0.0.1"; name="cloudflare_dns_anycast" },
  @{ a="8.8.8.8"; b="8.8.4.4"; name="google_dns_anycast" },
  # Cross-tier divergence - the money shot. If DNS anycast is fast but CDN anycast
  # is slow within the *same provider*, ISP peering is differentiated.
  @{ a="1.1.1.1"; b="104.16.132.229";  name="cloudflare_dns_vs_cdn" },
  @{ a="8.8.8.8"; b="142.250.193.100"; name="google_dns_vs_api" }
)
$DnsResolvers = @(
  @{ Name="isp_default"; Ip=$null },
  @{ Name="cloudflare";  Ip="1.1.1.1" },
  @{ Name="google";      Ip="8.8.8.8" },
  @{ Name="quad9";       Ip="9.9.9.9" }
)
$DnsNames = @("www.google.com","www.cloudflare.com","www.microsoft.com","example.com")
$TlsHosts = @("www.google.com","www.cloudflare.com","www.microsoft.com")
# SIP probe - disabled by default. Set $SipTarget = @{ Host="1.2.3.4"; Port=5060 }
# in config.ps1 to enable a per-tick SIP OPTIONS probe against your SBC.
$SipTarget = $null
# Port grid - generic public services. Add VoIP-specific port probes via
# config.ps1's $PortGrid block (see config.example.ps1).
$PortGrid = @(
  @{ host="1.1.1.1";          port=53;   proto="tcp"; label="DoT_cf" },
  @{ host="8.8.8.8";          port=53;   proto="tcp"; label="DoT_google" },
  @{ host="smtp.gmail.com";   port=587;  proto="tcp"; label="SMTP_sub" },
  @{ host="smtp.gmail.com";   port=25;   proto="tcp"; label="SMTP_25" },
  @{ host="imap.gmail.com";   port=993;  proto="tcp"; label="IMAPS" },
  @{ host="irc.libera.chat";  port=6667; proto="tcp"; label="IRC" }
)

# ---- Load user config overrides if present --------------------------------
$ConfigPath = Join-Path $PSScriptRoot "config.ps1"
if (Test-Path $ConfigPath) {
  Write-Host "[*] Loading user config: $ConfigPath" -ForegroundColor Cyan
  . $ConfigPath
}

# ---- Output dir -----------------------------------------------------------
$Stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$OutDir = Join-Path $BaseDir "$Stamp-$Tag"
$subs = "pcap","mtr","ping1s","iperf","speedtest"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($s in $subs) { New-Item -ItemType Directory -Force -Path (Join-Path $OutDir $s) | Out-Null }

# ---- CSV headers ----------------------------------------------------------
"timestamp,target,ip,sent,received,loss_pct,min_ms,avg_ms,max_ms,jitter_ms" | Out-File -Encoding utf8 "$OutDir\pings.csv"
"timestamp,resolver,resolver_ip,name,success,duration_ms,answer"            | Out-File -Encoding utf8 "$OutDir\dns.csv"
"timestamp,target,ip,port,success,connect_ms"                               | Out-File -Encoding utf8 "$OutDir\tcp.csv"
"timestamp,ssid,bssid,signal_pct,rx_mbps,tx_mbps,channel,auth,radio"        | Out-File -Encoding utf8 "$OutDir\wifi.csv"
"timestamp,egress_ip,country,org,asn,cgnat"                                 | Out-File -Encoding utf8 "$OutDir\egress.csv"
"timestamp,pair,a_rtt,b_rtt,a_loss,b_loss,divergence_ms"                    | Out-File -Encoding utf8 "$OutDir\anycast.csv"
"timestamp,arp_entries,established_conns,defender_realtime"                 | Out-File -Encoding utf8 "$OutDir\system.csv"
"timestamp,run_id,flow_id,status,connect_ms,bytes"                          | Out-File -Encoding utf8 "$OutDir\parallel_flows.csv"
"timestamp,host,issuer,subject,thumbprint,not_after,tls_version"            | Out-File -Encoding utf8 "$OutDir\tls_cert.csv"
"timestamp,success,ms,status,from_tag"                                      | Out-File -Encoding utf8 "$OutDir\sip_options.csv"
"timestamp,name,resolver_a,answer_a,resolver_b,answer_b,match"              | Out-File -Encoding utf8 "$OutDir\dns_hijack.csv"
"timestamp,label,host,port,proto,success,connect_ms"                        | Out-File -Encoding utf8 "$OutDir\port_grid.csv"
"timestamp,cap,time_ms,last_error"                                          | Out-File -Encoding utf8 "$OutDir\conn_sat.csv"

# ---- Baseline snapshot ---------------------------------------------------
Write-Host "[*] Writing baseline.txt ..." -ForegroundColor Cyan
@"
=== pulseboard-desktop v1.0 ===
started: $(Get-Date -Format o)
tag: $Tag   duration_min: $Duration   interval_sec: $Interval
computer: $env:COMPUTERNAME   user: $env:USERNAME

"@ | Out-File -Encoding utf8 "$OutDir\baseline.txt"

# Sync clock so timestamps are comparable across laptops
w32tm /resync /force 2>&1 | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"

# Cheap one-shot commands (always run - ~5-10s total)
$baselineCheap = @(
  "w32tm /query /status",
  "systeminfo | Select-String 'OS Name','OS Version','System Type'",
  "Get-NetAdapter | Where Status -eq 'Up' | Format-Table -AutoSize",
  "netsh wlan show interfaces",
  "netsh wlan show drivers",
  "netsh wlan show networks mode=bssid",
  "ipconfig /all",
  "route print -4",
  "Get-NetIPConfiguration | Where {`$_.IPv4DefaultGateway}",
  "arp -a",
  "netsh int tcp show global",
  "Get-MpComputerStatus | Select RealTimeProtectionEnabled,AntivirusEnabled,NISEnabled,IsTamperProtected",
  "Get-Volume C | Select DriveLetter,SizeRemaining,Size",
  "nslookup www.cloudflare.com"
)
# Slow diagnostic commands (tracerts, path MTU, ASN lookups) - 5-7 min total.
# Skip in -PreflightOnly mode so smoke stays fast.
# Tracert targets are derived from $Targets so user-defined SBCs are traced too.
$baselineSlow = @(
  "tracert -d -h 20 1.1.1.1",
  "tracert -d -h 20 8.8.8.8"
)
# Plus one tracert per user-configured Target (capped at first 3 to keep total time bounded)
$Targets | Select-Object -First 3 | ForEach-Object {
  $baselineSlow += "tracert -d -h 20 $($_.Ip)"
}

$cmdsToRun = if ($PreflightOnly) { $baselineCheap } else { $baselineCheap + $baselineSlow }
foreach ($cmd in $cmdsToRun) {
  "`n### $cmd`n"   | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
  try { Invoke-Expression $cmd 2>&1 | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt" }
  catch { $_ | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt" }
}

# ---- Helper functions ----------------------------------------------------
function Get-WifiSnapshot {
  $kv = @{}
  (netsh wlan show interfaces) | ForEach-Object {
    if ($_ -match '^\s*([^:]+?)\s*:\s*(.+?)\s*$') { $kv[$Matches[1]] = $Matches[2] }
  }
  $kv
}
function Invoke-PingBatch {
  # Fast .NET-based ping with tight per-probe timeout. Test-Connection's 5s
  # default timeout x Count makes timing-out targets cost 100+ s per batch.
  param($Ip,$Count=10,$TimeoutMs=1000,$GapMs=100)
  $p = New-Object System.Net.NetworkInformation.Ping
  $rtts = @()
  for ($i=1; $i -le $Count; $i++) {
    try {
      $r = $p.Send($Ip, $TimeoutMs)
      if ($r.Status -eq 'Success') { $rtts += [int]$r.RoundtripTime }
    } catch {}
    if ($i -lt $Count) { Start-Sleep -Milliseconds $GapMs }
  }
  $p.Dispose()
  $received = $rtts.Count
  if ($received -eq 0) { return @{ sent=$Count;received=0;loss=100;min=0;avg=0;max=0;jitter=0 } }
  $min = ($rtts | Measure-Object -Minimum).Minimum
  $max = ($rtts | Measure-Object -Maximum).Maximum
  $avg = ($rtts | Measure-Object -Average).Average
  $jitter = 0.0
  for ($i=1; $i -lt $received; $i++) { $jitter += [Math]::Abs($rtts[$i]-$rtts[$i-1]) }
  if ($received -gt 1) { $jitter = $jitter/($received-1) }
  @{ sent=$Count;received=$received
     loss=[Math]::Round(100.0*($Count-$received)/$Count,2)
     min=$min;avg=[Math]::Round($avg,1);max=$max;jitter=[Math]::Round($jitter,1) }
}
function Invoke-TcpProbe {
  param($Ip,$Port,$TimeoutMs=3000)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $c = New-Object Net.Sockets.TcpClient
    $iar = $c.BeginConnect($Ip,$Port,$null,$null)
    $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs,$false)
    if ($ok -and $c.Connected) { $sw.Stop(); $c.Close(); return @{success=1;ms=$sw.ElapsedMilliseconds} }
    $c.Close()
  } catch { }
  @{success=0;ms=-1}
}
function Invoke-DnsProbe {
  param($ResolverIp,$Name)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $p = @{ Name=$Name; Type="A"; ErrorAction="Stop"; DnsOnly=$true }
    if ($ResolverIp) { $p["Server"] = $ResolverIp }
    $r = Resolve-DnsName @p
    $sw.Stop()
    $ans = (($r | Where-Object Type -eq 'A' | Select-Object -First 3).IPAddress) -join ';'
    return @{success=1;ms=$sw.ElapsedMilliseconds;answer=$ans}
  } catch { $sw.Stop(); return @{success=0;ms=$sw.ElapsedMilliseconds;answer="ERR"} }
}
function Get-EgressMeta {
  try {
    $ip = (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing -TimeoutSec 5).Content.Trim()
    try {
      $m = Invoke-RestMethod -Uri "https://ipapi.co/$ip/json/" -TimeoutSec 5
      $country=$m.country_name; $org=$m.org; $asn=$m.asn
    } catch { $country=""; $org=""; $asn="" }
    # CGNAT: 100.64.0.0/10
    $cgnat = $false
    if ($ip -match '^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\.') { $cgnat = $true }
    return @{ip=$ip;country=$country;org=$org;asn=$asn;cgnat=$cgnat}
  } catch { return @{ip="ERR";country="";org="";asn="";cgnat=$false} }
}
function Get-TlsCert {
  param($HostName,$Port=443,$TimeoutMs=4000)
  try {
    $c = New-Object Net.Sockets.TcpClient
    $iar = $c.BeginConnect($HostName,$Port,$null,$null)
    $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs,$false)
    if (-not $ok -or -not $c.Connected) { $c.Close(); return $null }
    $callback = { param($s,$cert,$chain,$err) $true }
    $ssl = New-Object Net.Security.SslStream($c.GetStream(),$false,$callback)
    $ssl.AuthenticateAsClient($HostName)
    $x = New-Object Security.Cryptography.X509Certificates.X509Certificate2 $ssl.RemoteCertificate
    $ver = $ssl.SslProtocol.ToString()
    $ssl.Close(); $c.Close()
    return @{ issuer=$x.Issuer; subject=$x.Subject; thumbprint=$x.Thumbprint; not_after=$x.NotAfter.ToString("o"); tls=$ver }
  } catch { return $null }
}
function Invoke-SipOptions {
  param($DstHost,$Port=5060,$TimeoutMs=2000)
  if (-not $DstHost) { return @{success=0; ms=-1; status="no_sip_target_configured"; tag="-"} }
  $localIp = "0.0.0.0"
  try {
    $localIp = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway} | Select-Object -First 1).IPv4Address.IPAddress
  } catch {}
  $branch = "z9hG4bK-" + [Guid]::NewGuid().ToString("N").Substring(0,8)
  $call   = [Guid]::NewGuid().ToString("N").Substring(0,12)
  $tag    = [Guid]::NewGuid().ToString("N").Substring(0,6)
  $msg = "OPTIONS sip:$DstHost SIP/2.0`r`n" +
         "Via: SIP/2.0/UDP ${localIp}:5060;branch=$branch`r`n" +
         "Max-Forwards: 70`r`n" +
         "From: <sip:probe@$localIp>;tag=$tag`r`n" +
         "To: <sip:$DstHost>`r`n" +
         "Call-ID: $call@$localIp`r`n" +
         "CSeq: 1 OPTIONS`r`n" +
         "User-Agent: pulseboard-desktop/1.0`r`n" +
         "Content-Length: 0`r`n`r`n"
  $bytes = [Text.Encoding]::ASCII.GetBytes($msg)
  $udp = New-Object Net.Sockets.UdpClient
  $udp.Client.ReceiveTimeout = $TimeoutMs
  try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $udp.Send($bytes,$bytes.Length,$DstHost,$Port) | Out-Null
    $ep = New-Object Net.IPEndPoint([Net.IPAddress]::Any,0)
    $resp = $udp.Receive([ref]$ep)
    $sw.Stop()
    $text = [Text.Encoding]::ASCII.GetString($resp)
    $status = "unknown"
    if ($text -match '^SIP/2\.0 (\d+) (.+)$') { $status = "$($Matches[1]) $($Matches[2])" }
    return @{success=1; ms=$sw.ElapsedMilliseconds; status=$status; tag=$tag}
  } catch {
    return @{success=0; ms=-1; status=("err: " + $_.Exception.Message); tag=$tag}
  } finally { $udp.Close() }
}
function Test-DnsHijack {
  param($Name,$A,$B)
  $ra = Invoke-DnsProbe -ResolverIp $A -Name $Name
  $rb = Invoke-DnsProbe -ResolverIp $B -Name $Name
  $match = ($ra.answer -eq $rb.answer -and $ra.success -eq 1 -and $rb.success -eq 1)
  return @{ name=$Name; a_resolver=$A; a_answer=$ra.answer; b_resolver=$B; b_answer=$rb.answer; match=$match }
}
function Test-PortReachable {
  param($DstHost,$Port,$Proto="tcp",$TimeoutMs=2500)
  if ($Proto -eq "tcp") {
    $ipList = @()
    try { $ipList = (Resolve-DnsName -Name $DstHost -Type A -DnsOnly -EA Stop | Where-Object Type -eq 'A').IPAddress }
    catch { return @{success=0; ms=-1} }
    if (-not $ipList) { return @{success=0; ms=-1} }
    $ip = $ipList | Select-Object -First 1
    return Invoke-TcpProbe -Ip $ip -Port $Port -TimeoutMs $TimeoutMs
  } else {
    return @{success=-1; ms=-1}
  }
}
function Test-ConnSaturation {
  param($DstHost="1.1.1.1",$Port=443,$Max=200,$TimeoutMs=1500)
  $clients = @()
  $lastErr = ""
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    for ($i=1; $i -le $Max; $i++) {
      try {
        $c = New-Object Net.Sockets.TcpClient
        $iar = $c.BeginConnect($DstHost,$Port,$null,$null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs,$false)
        if (-not $ok -or -not $c.Connected) {
          $lastErr = "connect_fail_at_$i"
          $c.Close()
          $sw.Stop(); return @{cap=$i-1; ms=$sw.ElapsedMilliseconds; err=$lastErr}
        }
        $clients += $c
      } catch {
        $lastErr = $_.Exception.Message
        $sw.Stop(); return @{cap=$i-1; ms=$sw.ElapsedMilliseconds; err=$lastErr}
      }
    }
    $sw.Stop(); return @{cap=$Max; ms=$sw.ElapsedMilliseconds; err=""}
  } finally {
    foreach ($c in $clients) { try { $c.Close() } catch {} }
  }
}
function Invoke-ParallelFlows {
  # Each flow pulls 1 MB (down from 10 MB) to keep total traffic quiet.
  # 1 MB x 8 flows = 8 MB per fan-out. Enough to expose per-flow ISP hashing
  # without generating noticeable background load during business hours.
  param($Url="https://speed.cloudflare.com/__down?bytes=1000000",$N=8,$RunId)
  $jobs = 1..$N | ForEach-Object {
    Start-Job -ArgumentList $Url,$_,$RunId -ScriptBlock {
      param($u,$id,$runId)
      $sw=[Diagnostics.Stopwatch]::StartNew()
      try {
        $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 30
        $sw.Stop(); return @{id=$id;ok=1;ms=$sw.ElapsedMilliseconds;bytes=$r.RawContentLength;runId=$runId}
      } catch { $sw.Stop(); return @{id=$id;ok=0;ms=$sw.ElapsedMilliseconds;bytes=0;runId=$runId} }
    }
  }
  $jobs | Wait-Job -Timeout 40 | Out-Null
  $out = $jobs | Receive-Job
  $jobs | Remove-Job -Force
  return $out
}

# Baseline: one-shot self-diagnostic checks
"`n### One-shot self-diagnostics`n" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"

"Egress IP + ISP:" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
$e0 = Get-EgressMeta
$e0 | ConvertTo-Json | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"

"`nGateway ARP fingerprint:" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
try {
  $gwIp = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -EA SilentlyContinue | Select-Object -First 1).NextHop
  $arpLine = (arp -a | Select-String " $gwIp " | Select-Object -First 1).Line
  "gateway_ip=$gwIp  arp_line=$arpLine" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
} catch { "gateway_fingerprint_err: $_" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt" }

"`nTLS cert issuers (SSL inspection detector):" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
$TlsHosts | ForEach-Object {
  $c = Get-TlsCert -HostName $_
  if ($c) { "$_ --> issuer=$($c.issuer)  tls=$($c.tls)  thumb=$($c.thumbprint.Substring(0,12))..." }
  else    { "$_ --> (no cert)" }
} | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"

"`nSIP OPTIONS probe (only meaningful when `$SipTarget configured in config.ps1):" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
if ($SipTarget) {
  (Invoke-SipOptions -DstHost $SipTarget.Host -Port (if ($SipTarget.Port) {$SipTarget.Port} else {5060})) |
    ConvertTo-Json | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
} else {
  "(no `$SipTarget set; skipped)" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
}

"`nConnection saturation cap:" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
(Test-ConnSaturation) | ConvertTo-Json | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"

"`nDNS hijack check (isp vs 1.1.1.1):" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
foreach ($n in $DnsNames) {
  (Test-DnsHijack -Name $n -A $null -B "1.1.1.1") | ConvertTo-Json -Compress |
    Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
}

# Path MTU + ASN annotation are expensive (~3-5 min combined). Skip in
# -PreflightOnly mode so the smoke test is fast; they're diagnostic data
# only (don't gate the full run).
if (-not $PreflightOnly) {
  "`nPath MTU per target:" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
  foreach ($t in $Targets) {
    "--- $($t.Name) ($($t.Ip)) ---" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
    foreach ($size in 1472,1464,1454,1440,1400,1300,1200) {
      $r = cmd /c "ping -n 1 -f -l $size $($t.Ip)"
      "size=$size : $(($r | Select-String 'time=|Packet needs|timed out|Reply') -join ' | ')" |
        Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
    }
  }

  # ASN-annotate the path to the FIRST configured target. If user has set
  # $Targets to include their VoIP SBC, this annotates the path to that SBC.
  $annotateIp = if ($Targets -and $Targets.Count -gt 0) { $Targets[0].Ip } else { "1.1.1.1" }
  "`nhop-level ASN annotation (baseline tracert to ${annotateIp}):" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
  try {
    $tr = cmd /c "tracert -d -h 15 $annotateIp"
    foreach ($ln in $tr) {
      if ($ln -match '(\d+\.\d+\.\d+\.\d+)') {
        $hopIp = $Matches[1]
        try {
          $meta = Invoke-RestMethod -Uri "https://ipapi.co/$hopIp/json/" -TimeoutSec 4
          "$hopIp  asn=$($meta.asn)  org=$($meta.org)  country=$($meta.country_name)" |
            Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
        } catch { "$hopIp  (lookup failed)" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt" }
        Start-Sleep -Milliseconds 300  # rate-limit friendly
      }
    }
  } catch {}
}

# ---- Preflight validation -----------------------------------------------
# Triggers every capability once with PASS / DEGRADED / FAIL labels, writes to
# PREFLIGHT.txt and the console. Lets us see what actually works before the
# multi-hour main loop commits.

$PreflightFile = "$OutDir\PREFLIGHT.txt"
$RunLog        = "$OutDir\run.log"
"=== PREFLIGHT VALIDATION  (started: $(Get-Date -Format o)) ===" | Out-File -Encoding utf8 $PreflightFile

function Preflight-Step {
  param([string]$Label, [scriptblock]$Test)
  $pfLine = ""
  try {
    $result = & $Test
    if ($result.ok -eq 'PASS') {
      $pfLine = "[PASS] $Label  $($result.note)"
      Write-Host $pfLine -ForegroundColor Green
    } elseif ($result.ok -eq 'DEGRADED') {
      $pfLine = "[DEGR] $Label  $($result.note)"
      Write-Host $pfLine -ForegroundColor Yellow
    } else {
      $pfLine = "[FAIL] $Label  $($result.note)"
      Write-Host $pfLine -ForegroundColor Red
    }
  } catch {
    $pfLine = "[FAIL] $Label  exception: $($_.Exception.Message)"
    Write-Host $pfLine -ForegroundColor Red
  }
  $pfLine | Out-File -Append -Encoding utf8 $PreflightFile
}

Write-Host ""
Write-Host "=== Running preflight validation ===" -ForegroundColor Cyan
Write-Host "  (each line writes to PREFLIGHT.txt)"
Write-Host ""

# 1. Tool availability
# Find-Tool: checks PATH first, then common install locations, then adds to
# process PATH so later Get-Command lookups succeed. Returns path or $null.
function Find-Tool {
  param([string]$Name,[string[]]$ExtraPaths)
  $p = (Get-Command $Name -EA SilentlyContinue).Source
  if ($p) { return $p }
  foreach ($path in $ExtraPaths) {
    if (Test-Path $path) {
      $dir = Split-Path $path -Parent
      if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$dir;$env:Path" }
      return $path
    }
  }
  return $null
}

# Resolve tool paths up-front so later invocations can use them by name.
$script:TsharkPath   = Find-Tool "tshark.exe"   @(
  "C:\Program Files\Wireshark\tshark.exe",
  "C:\Program Files (x86)\Wireshark\tshark.exe"
)
$script:Iperf3Path   = Find-Tool "iperf3.exe"   @(
  "C:\Windows\System32\iperf3.exe",
  "C:\iperf3\iperf3.exe",
  "C:\Tools\iperf3.exe",
  "$env:USERPROFILE\Downloads\iperf3.exe"
)
$script:SpeedtestPath = Find-Tool "speedtest.exe" @(
  "$env:LocalAppData\Microsoft\WinGet\Packages\Ookla.Speedtest.CLI_Microsoft.Winget.Source_8wekyb3d8bbwe\speedtest.exe"
)

Preflight-Step "tool: tshark.exe" {
  if ($script:TsharkPath) { @{ok='PASS'; note="found at $script:TsharkPath"} }
  else    { @{ok='FAIL'; note="not found (checked PATH + C:\Program Files\Wireshark\)"} }
}
Preflight-Step "tool: iperf3.exe" {
  if ($script:Iperf3Path) { @{ok='PASS'; note="found at $script:Iperf3Path"} }
  else    { @{ok='FAIL'; note="not found (checked PATH + C:\Windows\System32\ + Downloads)"} }
}
Preflight-Step "tool: speedtest.exe" {
  if ($script:SpeedtestPath) { @{ok='PASS'; note="found at $script:SpeedtestPath"} }
  else    { @{ok='FAIL'; note="not found on PATH or winget pkg location"} }
}
Preflight-Step "tool: pathping (built-in)" {
  $p = (Get-Command pathping.exe -EA SilentlyContinue).Source
  if ($p) { @{ok='PASS'; note="found (MTR fallback)"} }
  else    { @{ok='FAIL'; note="pathping not found; MTR disabled"} }
}

# 2. Network adapter
Preflight-Step "net: Wi-Fi adapter Up" {
  $a = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -match "Wireless|Wi-Fi" } | Select-Object -First 1
  if ($a) { @{ok='PASS'; note="$($a.InterfaceAlias) ($($a.InterfaceDescription))"} }
  else    { @{ok='FAIL'; note="no Wi-Fi adapter in Up state - tshark will have nothing to bind to"} }
}

# 3. ICMP reachability
# Note: we pre-compute the result BEFORE invoking Preflight-Step because
# PowerShell 5.1's .GetNewClosure() creates a scriptblock scope that cannot
# see script-level function definitions (Invoke-PingBatch etc). So we do the
# work here and pass just the already-computed hashtable back.
foreach ($t in $Targets) {
  $r = Invoke-PingBatch -Ip $t.Ip -Count 3 -TimeoutMs 1000
  $pfResult =
    if     ($r.received -eq 3)  { @{ok='PASS';     note="avg=$($r.avg)ms"} }
    elseif ($r.received -gt 0)  { @{ok='DEGRADED'; note="$($r.received)/3 replies avg=$($r.avg)ms"} }
    else                        { @{ok='FAIL';     note="0/3 replies (host blocks ICMP or unreachable)"} }
  Preflight-Step "icmp: ping $($t.Name) ($($t.Ip))" { $pfResult }.GetNewClosure()
}

# 4. TCP 443 reachability
foreach ($t in $Targets) {
  $r = Invoke-TcpProbe -Ip $t.Ip -Port 443 -TimeoutMs 2000
  $pfResult =
    if ($r.success -eq 1) { @{ok='PASS'; note="connect=$($r.ms)ms"} }
    else                  { @{ok='FAIL'; note="connect refused/timed out"} }
  Preflight-Step "tcp: 443 to $($t.Name) ($($t.Ip))" { $pfResult }.GetNewClosure()
}

# 5. DNS resolution via each resolver - uses the FIRST $DnsNames entry as probe
$probeName = if ($DnsNames -and $DnsNames.Count -gt 0) { $DnsNames[0] } else { "www.cloudflare.com" }
foreach ($res in $DnsResolvers) {
  $r = Invoke-DnsProbe -ResolverIp $res.Ip -Name $probeName
  $pfResult =
    if ($r.success -eq 1) { @{ok='PASS'; note="$($r.answer) in $($r.ms)ms"} }
    else                  { @{ok='FAIL'; note="no answer ($($r.ms)ms)"} }
  Preflight-Step "dns: $probeName via $($res.Name)" { $pfResult }.GetNewClosure()
}

# 6. TLS cert fetch
foreach ($h in $TlsHosts) {
  $c = Get-TlsCert -HostName $h
  $pfResult =
    if ($c) {
      $knownCA = "Google|DigiCert|Let's Encrypt|Cloudflare|Sectigo|GlobalSign|Amazon|ISRG|WR2|WE1"
      $inspect = if ($c.issuer -match $knownCA) { "" } else { " ! unexpected CA - possible SSL inspection" }
      @{ok='PASS'; note="$($c.issuer)$inspect"}
    } else { @{ok='FAIL'; note="handshake failed"} }
  Preflight-Step "tls: cert fetch $h" { $pfResult }.GetNewClosure()
}

# 7. SIP OPTIONS - only meaningful if config.ps1 set $SipTarget
if ($SipTarget) {
  $sipDst = $SipTarget.Host
  $sipPort = if ($SipTarget.Port) { $SipTarget.Port } else { 5060 }
  Preflight-Step "sip: OPTIONS to ${sipDst}:${sipPort}/udp" {
    $r = Invoke-SipOptions -DstHost $sipDst -Port $sipPort
    if ($r.success -eq 1) { @{ok='PASS'; note="reply: $($r.status) in $($r.ms)ms"} }
    else                  { @{ok='DEGRADED'; note="no reply - many SBCs ignore anonymous OPTIONS, OR UDP $sipPort is filtered outbound. Compare against TCP 443 to same host to disambiguate."} }
  }.GetNewClosure()
} else {
  Preflight-Step "sip: probe (skipped - no `$SipTarget in config.ps1)" { @{ok='PASS'; note="not configured"} }
}

# 8. Egress IP + CGNAT
Preflight-Step "egress: public IP + CGNAT probe" {
  $e = Get-EgressMeta
  if ($e.ip -eq "ERR") { @{ok='FAIL'; note="ifconfig.me unreachable"} }
  elseif ($e.cgnat)    { @{ok='DEGRADED'; note="CGNAT detected ($($e.ip)) - session rotation risk"} }
  else                 { @{ok='PASS'; note="$($e.ip) (no CGNAT)"} }
}

# 9. DNS hijack check (uses the first $DnsNames probe target)
Preflight-Step "dns_hijack: compare isp vs 1.1.1.1 on $probeName" {
  $h = Test-DnsHijack -Name $probeName -A $null -B "1.1.1.1"
  if ($h.match)   { @{ok='PASS';     note="both return $($h.a_answer)"} }
  else            { @{ok='DEGRADED'; note="isp=$($h.a_answer) cf=$($h.b_answer) - could be load-balancer or hijack; monitor"} }
}

# 10. Connection saturation (quick 50-conn check instead of 200)
Preflight-Step "conn_sat: 50 parallel TCP to 1.1.1.1:443" {
  $s = Test-ConnSaturation -DstHost "1.1.1.1" -Port 443 -Max 50 -TimeoutMs 1500
  if ($s.cap -eq 50)    { @{ok='PASS';     note="50/50 ok in $($s.ms)ms"} }
  elseif ($s.cap -gt 10){ @{ok='DEGRADED'; note="only $($s.cap)/50 ok - firewall/conntrack throttle"} }
  else                  { @{ok='FAIL';     note="capped at $($s.cap) - something is blocking"} }
}

# 11. Parallel flows
Preflight-Step "flows: 4 parallel HTTPS to speed.cloudflare.com" {
  $f = Invoke-ParallelFlows -N 4 -RunId "preflight"
  $ok = ($f | Where-Object { $_.ok -eq 1 }).Count
  if ($ok -eq 4)       { @{ok='PASS';     note="4/4 completed"} }
  elseif ($ok -gt 0)   { @{ok='DEGRADED'; note="$ok/4 completed - possible per-flow hashing"} }
  else                 { @{ok='FAIL';     note="all flows failed - blocked?"} }
}

# 12. Speedtest tool sanity (pre-computed; uses resolved path)
$pfResult =
  if (-not $script:SpeedtestPath) { @{ok='FAIL'; note="exe missing"} }
  else {
    $out = & $script:SpeedtestPath --accept-license --accept-gdpr -L 2>&1 | Select-Object -First 1
    if ($out -match 'ID|Server') { @{ok='PASS'; note="list OK"} }
    else                         { @{ok='DEGRADED'; note="unusual output: $out"} }
  }
Preflight-Step "speedtest: can find a server" { $pfResult }.GetNewClosure()

# 13. tshark 3-second sanity capture
$pfResult =
  if (-not $script:TsharkPath) { @{ok='FAIL'; note="exe missing"} }
  else {
    $iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -match "Wireless|Wi-Fi" } | Select-Object -First 1).InterfaceAlias
    if (-not $iface) { @{ok='FAIL'; note="no Wi-Fi iface Up"} }
    else {
      $testPcap = "$OutDir\pcap\preflight-test.pcapng"
      & $script:TsharkPath -i $iface -a "duration:3" -w $testPcap 2>&1 | Out-File -Append -Encoding utf8 $RunLog
      Start-Sleep -Seconds 4
      if (Test-Path $testPcap) {
        $sz = (Get-Item $testPcap).Length
        if ($sz -gt 500) { @{ok='PASS'; note="captured $sz bytes on '$iface'"} }
        else             { @{ok='DEGRADED'; note="pcap written but tiny ($sz bytes)"} }
      } else { @{ok='FAIL'; note="pcap not created - tshark permission issue?"} }
    }
  }
Preflight-Step "tshark: 3-sec capture sanity test" { $pfResult }.GetNewClosure()

# 14. iperf3 5-second sanity test
$pfResult =
  if (-not $script:Iperf3Path) { @{ok='FAIL'; note="exe missing"} }
  else {
    $tmpOut = "$OutDir\iperf\preflight-test.json"
    & $script:Iperf3Path -c iperf.he.net -u -b 80K -t 5 -J > $tmpOut 2>&1
    if (Test-Path $tmpOut) {
      $content = Get-Content $tmpOut -Raw
      if ($content -match '"end"')              { @{ok='PASS';     note="UDP burst succeeded"} }
      elseif ($content -match 'unable|refused') { @{ok='DEGRADED'; note="iperf.he.net unreachable - pick another server"} }
      else                                       { @{ok='DEGRADED'; note="partial output"} }
    } else { @{ok='FAIL'; note="no output"} }
  }
Preflight-Step "iperf3: 5-sec UDP to iperf.he.net" { $pfResult }.GetNewClosure()

# 15a. Disk space - pcap can grow 6-15 GB over a workday; fail if < 20 GB free
$pfResult = try {
    $v = Get-Volume -DriveLetter C -EA Stop
    $gb = [Math]::Round($v.SizeRemaining / 1GB, 1)
    if     ($gb -lt 5)  { @{ok='FAIL';     note="only $gb GB free on C: - pcap will fill the disk"} }
    elseif ($gb -lt 20) { @{ok='DEGRADED'; note="$gb GB free on C: - tight for full-day pcap (6-15 GB)"} }
    else                { @{ok='PASS';     note="$gb GB free on C:"} }
  } catch { @{ok='DEGRADED'; note="could not read volume info"} }
Preflight-Step "disk: free space on C:" { $pfResult }.GetNewClosure()

# 15b. Wi-Fi snapshot shape - must return SSID, BSSID, Signal, Receive rate etc
# to populate wifi.csv. Silent breakage here would give us empty Wi-Fi data
# for the whole day.
$wSnap = Get-WifiSnapshot
$hasSsid   = -not [string]::IsNullOrWhiteSpace($wSnap['SSID'])
$hasSignal = -not [string]::IsNullOrWhiteSpace($wSnap['Signal'])
$hasRx     = -not [string]::IsNullOrWhiteSpace($wSnap['Receive rate (Mbps)'])
$pfResult =
  if     ($hasSsid -and $hasSignal -and $hasRx) { @{ok='PASS'; note="ssid=$($wSnap['SSID']) signal=$($wSnap['Signal']) rx=$($wSnap['Receive rate (Mbps)'])Mbps"} }
  elseif ($hasSsid -and $hasSignal)             { @{ok='DEGRADED'; note="partial snapshot (rx rate missing)"} }
  else                                          { @{ok='FAIL'; note="netsh wlan show interfaces returned no SSID/Signal - wifi.csv will be empty"} }
Preflight-Step "wifi: Get-WifiSnapshot shape" { $pfResult }.GetNewClosure()

# 15c. Anycast pair secondary IPs - anycast.csv needs both a and b reachable.
# We already ping the 'a' side via $Targets, but 'b' sides (1.0.0.1, 8.8.4.4)
# aren't in $Targets, so validate them here.
$anycastSecondaries = @("1.0.0.1", "8.8.4.4")
foreach ($ip in $anycastSecondaries) {
  $r = Invoke-PingBatch -Ip $ip -Count 3 -TimeoutMs 1000
  $pfResult =
    if     ($r.received -eq 3)  { @{ok='PASS'; note="avg=$($r.avg)ms"} }
    elseif ($r.received -gt 0)  { @{ok='DEGRADED'; note="$($r.received)/3 replies"} }
    else                        { @{ok='FAIL'; note="0/3 replies - anycast.csv divergence test for this pair will be broken"} }
  Preflight-Step "icmp: anycast secondary ($ip)" { $pfResult }.GetNewClosure()
}

# 15d. System cmdlets used by system.csv - exercise them and confirm non-zero
# output. Note: $avState is a BOOL from Get-MpComputerStatus; the earlier
# `-ne "?"` check mis-coerced bool->string and falsely labelled PASS as
# DEGRADED. Cast to string explicitly.
$arpCount  = try { (arp -a | Measure-Object -Line).Lines } catch { -1 }
$connCount = try { (Get-NetTCPConnection -State Established -EA SilentlyContinue | Measure-Object).Count } catch { -1 }
$avRaw     = try { (Get-MpComputerStatus).RealTimeProtectionEnabled } catch { $null }
$avStr     = if ($null -eq $avRaw) { "?" } else { "$avRaw" }  # "True" / "False" / "?"
$pfResult =
  if     ($arpCount -gt 0 -and $connCount -ge 0 -and $avStr -ne "?") { @{ok='PASS'; note="arp=$arpCount conn=$connCount av=$avStr"} }
  elseif ($arpCount -gt 0)                                           { @{ok='DEGRADED'; note="arp=$arpCount conn=$connCount av=$avStr (partial)"} }
  else                                                               { @{ok='FAIL'; note="arp/conn/av cmdlets not returning data - system.csv broken"} }
Preflight-Step "system: arp/conn/av cmdlets" { $pfResult }.GetNewClosure()

# 15. MTR sanity via pathping - exercise what the main loop will run, with
# trimmed parameters (5 cycles/hop instead of 50, max 10 hops) so it's ~15s.
$mtrTestOut = "$OutDir\mtr\preflight-sanity.txt"
cmd /c "pathping -n -q 5 -p 50 -h 10 1.1.1.1" > $mtrTestOut 2>&1
$pfResult =
  if (Test-Path $mtrTestOut) {
    $sz = (Get-Item $mtrTestOut).Length
    if ($sz -gt 200) { @{ok='PASS'; note="pathping wrote $sz bytes"} }
    else             { @{ok='DEGRADED'; note="pathping ran but output tiny ($sz bytes)"} }
  } else { @{ok='FAIL'; note="pathping produced no file"} }
Preflight-Step "mtr: pathping sanity to 1.1.1.1 (5-cycle)" { $pfResult }.GetNewClosure()

# 16. Full speedtest - real down/up/latency numbers. Takes ~30-40s but we want
# the actual capacity baseline written to the preflight output.
$pfResult =
  if (-not $script:SpeedtestPath) { @{ok='FAIL'; note="exe missing"} }
  else {
    $stOut = "$OutDir\speedtest\preflight.json"
    & $script:SpeedtestPath --accept-license --accept-gdpr -f json > $stOut 2>&1
    if (Test-Path $stOut) {
      try {
        $st = Get-Content $stOut -Raw | ConvertFrom-Json
        $dl = [Math]::Round($st.download.bandwidth * 8 / 1e6, 1)
        $ul = [Math]::Round($st.upload.bandwidth   * 8 / 1e6, 1)
        $lat = $st.ping.latency
        $jit = $st.ping.jitter
        $srv = "$($st.server.name) ($($st.server.location))"
        @{ok='PASS'; note="${dl} Mbps down / ${ul} Mbps up / ${lat}ms +/- ${jit}ms via $srv"}
      } catch { @{ok='DEGRADED'; note="speedtest ran but JSON unparseable"} }
    } else { @{ok='FAIL'; note="speedtest produced no output"} }
  }
Preflight-Step "speedtest: real run (download/upload/latency)" { $pfResult }.GetNewClosure()

"=== PREFLIGHT COMPLETE  (finished: $(Get-Date -Format o)) ===" | Out-File -Append -Encoding utf8 $PreflightFile

# Compute summary counts so the user gets a single-glance verdict
$pfContent = Get-Content $PreflightFile
$countPass = ($pfContent | Select-String '^\[PASS\]').Count
$countDegr = ($pfContent | Select-String '^\[DEGR\]').Count
$countFail = ($pfContent | Select-String '^\[FAIL\]').Count
$summary = "`nPREFLIGHT SUMMARY: $countPass PASS / $countDegr DEGRADED / $countFail FAIL"
$summary | Out-File -Append -Encoding utf8 $PreflightFile

Write-Host ""
Write-Host "=== Preflight summary written to PREFLIGHT.txt ===" -ForegroundColor Cyan
Write-Host ("    {0} PASS  /  {1} DEGRADED  /  {2} FAIL" -f $countPass,$countDegr,$countFail) -ForegroundColor Cyan
Write-Host ""

if ($PreflightOnly) {
  Write-Host "[*] -PreflightOnly set. Skipping main loop & background captures." -ForegroundColor Green
  Write-Host "[*] Output folder: $OutDir" -ForegroundColor Green
  Write-Host "[*] Read PREFLIGHT.txt and decide whether to run the full-day capture." -ForegroundColor Green
  "`n### Run ended after preflight (PreflightOnly mode).`nfinished: $(Get-Date -Format o)" |
    Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"
  return  # exit cleanly; no background jobs started
}

# ---- Start continuous background captures --------------------------------

# 1. Single-file tshark packet capture - ALL DAY, no rotation
$tshark = $script:TsharkPath
$tsharkProc = $null
if ($tshark) {
  $iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -match "Wireless|Wi-Fi" } | Select-Object -First 1).InterfaceAlias
  if ($iface) {
    $pcapFile = "$OutDir\pcap\capture.pcapng"
    $tsharkProc = Start-Process -NoNewWindow -PassThru -FilePath $tshark `
      -ArgumentList "-i",$iface,"-w",$pcapFile,"-q" `
      -RedirectStandardError "$OutDir\pcap\tshark.log"
    Write-Host "[*] tshark SINGLE-FILE capture started on '$iface'" -ForegroundColor Cyan
    Write-Host "    -> $pcapFile (watch disk space; ~1-2 GB/hour)" -ForegroundColor Cyan
  } else {
    Write-Host "[!] No Wi-Fi adapter Up - skipping pcap" -ForegroundColor Yellow
  }
} else {
  Write-Host "[!] tshark not found - skipping pcap" -ForegroundColor Yellow
}

# 2. Continuous 1-second-resolution ping loggers (CSV, one job per target)
foreach ($t in $Targets) {
  Start-Job -Name "ping1s_$($t.Name)" -ArgumentList $t.Name,$t.Ip,"$OutDir\ping1s\$($t.Name).csv",$Duration -ScriptBlock {
    param($n,$ip,$out,$dur)
    "timestamp,rtt_ms,status" | Out-File -Encoding utf8 $out
    $end = (Get-Date).AddMinutes($dur)
    $ping = New-Object System.Net.NetworkInformation.Ping
    while ((Get-Date) -lt $end) {
      $ts = (Get-Date).ToString("o")
      try {
        $r = $ping.Send($ip, 1000)  # 1-second tight timeout
        if ($r.Status -eq 'Success') { "$ts,$([int]$r.RoundtripTime),ok" | Out-File -Append -Encoding utf8 $out }
        else                         { "$ts,-1,loss"                     | Out-File -Append -Encoding utf8 $out }
      } catch {
        "$ts,-1,err" | Out-File -Append -Encoding utf8 $out
      }
      Start-Sleep -Seconds 1
    }
    $ping.Dispose()
  } | Out-Null
}
Write-Host "[*] 1-sec ping loggers started ($($Targets.Count) targets)" -ForegroundColor Cyan

# ---- Main tick loop ------------------------------------------------------
$endAt        = (Get-Date).AddMinutes($Duration)
$tickNum      = 0
$mtrEvery     = 2    # every N ticks
$iperfEvery   = 10
$speedEvery   = 60   # every 60 ticks = 60 min. For a 2.5h run gives 3 speedtests (~0, ~60, ~120 min). Speedtest briefly saturates the line; keep it hourly so we don't pollute bad-call measurement windows but still have capacity data points.
$flowEvery    = 10
$egressEvery  = 5
$tlsEvery     = 5
$hijackEvery  = 5
$portEvery    = 30
$satEvery     = 30

Write-Host ""
Write-Host "[*] Main loop: $Duration min, $Interval s ticks. Output: $OutDir" -ForegroundColor Green
Write-Host ""

while ((Get-Date) -lt $endAt) {
  $tickNum++
  $ts = (Get-Date).ToString("o")
  $tickStart = Get-Date

  # Pings (20 per target)
  foreach ($t in $Targets) {
    $r = Invoke-PingBatch -Ip $t.Ip -Count 20
    "$ts,$($t.Name),$($t.Ip),$($r.sent),$($r.received),$($r.loss),$($r.min),$($r.avg),$($r.max),$($r.jitter)" |
      Out-File -Append -Encoding utf8 "$OutDir\pings.csv"
  }

  # TCP probes
  foreach ($t in $Targets) {
    $r = Invoke-TcpProbe -Ip $t.Ip -Port $t.Port
    "$ts,$($t.Name),$($t.Ip),$($t.Port),$($r.success),$($r.ms)" |
      Out-File -Append -Encoding utf8 "$OutDir\tcp.csv"
  }

  # DNS
  foreach ($res in $DnsResolvers) {
    foreach ($n in $DnsNames) {
      $r = Invoke-DnsProbe -ResolverIp $res.Ip -Name $n
      "$ts,$($res.Name),$($res.Ip),$n,$($r.success),$($r.ms),$($r.answer)" |
        Out-File -Append -Encoding utf8 "$OutDir\dns.csv"
    }
  }

  # Wi-Fi
  $w = Get-WifiSnapshot
  "$ts,$($w['SSID']),$($w['BSSID']),$($w['Signal'] -replace '%',''),$($w['Receive rate (Mbps)']),$($w['Transmit rate (Mbps)']),$($w['Channel']),$($w['Authentication']),$($w['Radio type'])" |
    Out-File -Append -Encoding utf8 "$OutDir\wifi.csv"

  # Anycast divergence
  foreach ($p in $AnycastPairs) {
    $ra = Invoke-PingBatch -Ip $p.a -Count 5
    $rb = Invoke-PingBatch -Ip $p.b -Count 5
    $div = [Math]::Round([Math]::Abs($ra.avg - $rb.avg),1)
    "$ts,$($p.name),$($ra.avg),$($rb.avg),$($ra.loss),$($rb.loss),$div" |
      Out-File -Append -Encoding utf8 "$OutDir\anycast.csv"
  }

  # SIP OPTIONS - every tick (very cheap). Skipped silently if no $SipTarget.
  if ($SipTarget) {
    $sipPort = if ($SipTarget.Port) { $SipTarget.Port } else { 5060 }
    $sip = Invoke-SipOptions -DstHost $SipTarget.Host -Port $sipPort
  } else {
    $sip = @{success=0; ms=-1; status="not_configured"; tag="-"}
  }
  "$ts,$($sip.success),$($sip.ms),$($sip.status -replace ',',';'),$($sip.tag)" |
    Out-File -Append -Encoding utf8 "$OutDir\sip_options.csv"

  # System context
  $arp  = (arp -a | Measure-Object -Line).Lines
  $conn = (Get-NetTCPConnection -State Established -EA SilentlyContinue | Measure-Object).Count
  $rtp  = try { (Get-MpComputerStatus).RealTimeProtectionEnabled } catch { "?" }
  "$ts,$arp,$conn,$rtp" | Out-File -Append -Encoding utf8 "$OutDir\system.csv"

  # Egress / CGNAT (every 5 min)
  if (($tickNum % $egressEvery) -eq 1) {
    $e = Get-EgressMeta
    "$ts,$($e.ip),$($e.country),$($e.org -replace ',',';'),$($e.asn),$($e.cgnat)" |
      Out-File -Append -Encoding utf8 "$OutDir\egress.csv"
  }

  # TLS cert fingerprint (every 5 min)
  if (($tickNum % $tlsEvery) -eq 1) {
    foreach ($h in $TlsHosts) {
      $c = Get-TlsCert -HostName $h
      if ($c) {
        "$ts,$h,$($c.issuer -replace ',',';'),$($c.subject -replace ',',';'),$($c.thumbprint),$($c.not_after),$($c.tls)" |
          Out-File -Append -Encoding utf8 "$OutDir\tls_cert.csv"
      } else {
        "$ts,$h,ERR,ERR,ERR,ERR,ERR" | Out-File -Append -Encoding utf8 "$OutDir\tls_cert.csv"
      }
    }
  }

  # DNS hijack (every 5 min)
  if (($tickNum % $hijackEvery) -eq 2) {
    foreach ($n in $DnsNames) {
      $h = Test-DnsHijack -Name $n -A $null -B "1.1.1.1"
      "$ts,$n,isp_default,$($h.a_answer),1.1.1.1,$($h.b_answer),$($h.match)" |
        Out-File -Append -Encoding utf8 "$OutDir\dns_hijack.csv"
    }
  }

  # Port grid (every 30 min)
  if (($tickNum % $portEvery) -eq 3) {
    foreach ($p in $PortGrid) {
      $r = Test-PortReachable -DstHost $p.host -Port $p.port -Proto $p.proto
      "$ts,$($p.label),$($p.host),$($p.port),$($p.proto),$($r.success),$($r.ms)" |
        Out-File -Append -Encoding utf8 "$OutDir\port_grid.csv"
    }
  }

  # Connection saturation (every 30 min, offset from port grid)
  if (($tickNum % $satEvery) -eq 10) {
    $s = Test-ConnSaturation
    "$ts,$($s.cap),$($s.ms),$($s.err -replace ',',';')" |
      Out-File -Append -Encoding utf8 "$OutDir\conn_sat.csv"
  }

  # MTR (every 2 min, parallel per target) - pathping only. WinMTR spawns GUI
  # tabs and doesn't redirect output reliably, even with --report.
  if (($tickNum % $mtrEvery) -eq 1) {
    $m = Get-Date -Format "HHmmss"
    foreach ($t in $Targets) {
      Start-Job -ArgumentList $t.Ip, "$OutDir\mtr\$m-$($t.Name).txt" -ScriptBlock {
        param($ip,$out)
        cmd /c "pathping -n -q 50 -p 50 -h 20 $ip" > $out 2>&1
      } | Out-Null
    }
  }

  # iperf3 UDP burst (every 10 min)
  if (($tickNum % $iperfEvery) -eq 1) {
    $m = Get-Date -Format "HHmmss"
    $iperf = $script:Iperf3Path
    if ($iperf) {
      Start-Job -ArgumentList $iperf,"$OutDir\iperf\$m.json" -ScriptBlock {
        param($exe,$out)
        & $exe -c iperf.he.net -u -b 80K -t 60 -J > $out 2>&1
      } | Out-Null
    }
  }

  # Parallel 8-flow fan-out (every 10 min)
  if (($tickNum % $flowEvery) -eq 2) {
    $m = Get-Date -Format "HHmmss"
    $flows = Invoke-ParallelFlows -RunId $m
    foreach ($f in $flows) {
      "$ts,$m,$($f.id),$($f.ok),$($f.ms),$($f.bytes)" |
        Out-File -Append -Encoding utf8 "$OutDir\parallel_flows.csv"
    }
  }

  # Speedtest (every 30 min)
  if (($tickNum % $speedEvery) -eq 1) {
    $m = Get-Date -Format "HHmmss"
    $st = $script:SpeedtestPath
    if ($st) {
      Start-Job -ArgumentList $st,"$OutDir\speedtest\$m.json" -ScriptBlock {
        param($exe,$out)
        & $exe --accept-license --accept-gdpr -f json > $out 2>&1
      } | Out-Null
    }
  }

  # Heartbeat - one clean line per tick, no per-probe noise
  $sipShort = if ($sip.success -eq 1) { "ok" } else { "no-reply" }
  # Find loss across the 6 target pings from this tick (fast read of last lines)
  $recent = Get-Content "$OutDir\pings.csv" -Tail 6 -EA SilentlyContinue
  $lossyTargets = @()
  foreach ($line in $recent) {
    $cols = $line -split ','
    if ($cols.Count -ge 6 -and [double]($cols[5]) -gt 0) { $lossyTargets += $cols[1] }
  }
  $lossFlag = if ($lossyTargets.Count -eq 0) { "" } else { "  LOSS: $($lossyTargets -join ',')" }
  Write-Host ("[{0}] tick={1:d4}  ssid={2}  rssi={3}  rx={4}Mbps  sip={5}{6}" -f `
    (Get-Date -Format "HH:mm:ss"),$tickNum,$w['SSID'],$w['Signal'],$w['Receive rate (Mbps)'],$sipShort,$lossFlag)

  # Reap finished jobs to prevent accumulation
  Get-Job -State Completed | Remove-Job -Force -EA SilentlyContinue
  Get-Job -State Failed    | Remove-Job -Force -EA SilentlyContinue

  # Pace ticks
  $elapsed = ((Get-Date) - $tickStart).TotalSeconds
  $sleepFor = $Interval - $elapsed
  if ($sleepFor -gt 0) { Start-Sleep -Seconds $sleepFor }
}

# ---- Cleanup -------------------------------------------------------------
Write-Host ""
Write-Host "[*] Stopping background jobs & tshark ..." -ForegroundColor Cyan
Get-Job | Stop-Job -EA SilentlyContinue
Get-Job | Wait-Job -Timeout 60 | Out-Null
Get-Job | Remove-Job -Force -EA SilentlyContinue

if ($tsharkProc) {
  try { Stop-Process -Id $tsharkProc.Id -Force -EA SilentlyContinue } catch {}
}
Get-Process -Name tshark -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue

"`n### Run complete`nfinished: $(Get-Date -Format o)" | Out-File -Append -Encoding utf8 "$OutDir\baseline.txt"

Write-Host "[*] Done. Output: $OutDir" -ForegroundColor Green
Write-Host "[*] Zip the folder and send it over." -ForegroundColor Green
