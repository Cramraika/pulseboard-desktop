# PREFLIGHT.txt — row-by-row reference

Every `diag.ps1` run starts with a preflight phase that exercises every capability the main loop will use. Each line is one of:

- `[PASS]` — capability works
- `[DEGR]` — capability worked partially or with caveats; usually still OK to proceed
- `[FAIL]` — capability is broken; the corresponding output file will be empty / wrong

The bottom of the file has a summary count. **Aim for zero unexpected FAILs** before committing to a multi-hour run.

---

## Tool availability (4 rows)

```
[PASS] tool: tshark.exe  found at C:\Program Files\Wireshark\tshark.exe
[PASS] tool: iperf3.exe  found at C:\iperf3\iperf3.exe
[PASS] tool: speedtest.exe  found at ...
[PASS] tool: pathping (built-in)  found
```

| Status | Meaning | Action |
|---|---|---|
| `tshark FAIL` | Wireshark not installed or not on PATH | Re-run `install.ps1`. If that fails, check `C:\Program Files\Wireshark\` exists. |
| `iperf3 FAIL` | iperf3 not in `C:\iperf3\`, `C:\Windows\System32\`, `C:\Tools\`, or PATH | Either re-run `install.ps1`, or download manually from [ar51an](https://github.com/ar51an/iperf3-win-builds/releases/latest) and extract iperf3.exe + cygwin1.dll together to `C:\iperf3\`. |
| `speedtest FAIL` | Ookla Speedtest CLI missing | `winget install Ookla.Speedtest.CLI` |
| `pathping FAIL` | Built-in Windows tool missing | Almost impossible. If this fails the OS install is corrupt. |

## Network adapter (1 row)

```
[PASS] net: Wi-Fi adapter Up  Wi-Fi (Intel(R) Wi-Fi 6 AX201 160MHz)
```

| Status | Meaning |
|---|---|
| `PASS` | A Wi-Fi adapter is in `Up` state. tshark binds to it for capture. |
| `FAIL` | No Wi-Fi adapter or all are down. tshark won't capture anything. Reconnect Wi-Fi or use a different machine. |

Note: this checks for **Wi-Fi specifically** — if you're on Ethernet and want to test that, the adapter detection in the script needs a small edit (not yet automated).

## ICMP per target (5+ rows, one per `$Targets` entry)

```
[PASS] icmp: ping cloudflare_dns (1.1.1.1)  avg=35ms
[DEGR] icmp: ping ttbs_smartflo_3 (14.97.20.3)  2/3 replies avg=28.7ms
[FAIL] icmp: ping my_sbc (203.0.113.10)  0/3 replies (host blocks ICMP or unreachable)
```

| Status | Meaning |
|---|---|
| `PASS` (3/3) | Target answers ICMP cleanly. |
| `DEGR` (1-2/3) | Some loss in the 3-probe smoke. Could be brief Wi-Fi blip; main run will give more data. |
| `FAIL` (0/3) | Two interpretations: (a) target genuinely unreachable, (b) target blocks ICMP from arbitrary sources. **VoIP SBCs commonly block anonymous ICMP** — this is normal and not a blocker for VoIP traffic itself. Use the corresponding TCP probe row to confirm reachability. |

Common case: your VoIP SBC fails the ICMP row but passes the TCP-port-grid row. That's expected SBC hardening.

## TCP 443 per target (5+ rows)

```
[PASS] tcp: 443 to cloudflare_dns (1.1.1.1)  connect=37ms
[FAIL] tcp: 443 to my_sbc (203.0.113.10)  connect refused/timed out
```

| Status | Meaning |
|---|---|
| `PASS` | TCP 443 connect succeeded. |
| `FAIL` | TCP 443 refused or timed out. **Many VoIP SBCs don't serve TCP 443** (they only listen on UDP 5060 / TCP 5060/5061). FAIL on a SIP IP is normal. FAIL on a public anycast (cloudflare/google) is a real problem — likely firewall blocking outbound 443 from this Wi-Fi. |

## DNS resolver checks (4 rows)

```
[PASS] dns: www.cloudflare.com via isp_default  104.16.124.96;104.16.123.96 in 2ms
[PASS] dns: www.cloudflare.com via cloudflare  104.16.124.96;104.16.123.96 in 12ms
[PASS] dns: www.cloudflare.com via google  104.16.124.96;104.16.123.96 in 15ms
[PASS] dns: www.cloudflare.com via quad9  104.16.124.96;104.16.123.96 in 14ms
```

| Status | Meaning |
|---|---|
| All `PASS` | DNS works across all 4 resolvers. Ideal. |
| `isp_default FAIL` but others `PASS` | Your ISP's DNS resolver is broken / very slow. Switch your DHCP-served DNS to 1.1.1.1 or 8.8.8.8. |
| All `FAIL` | UDP 53 outbound is filtered. Some restrictive corporate networks do this. Use a different network or VPN. |

## TLS cert fetch (3 rows — SSL inspection detector)

```
[PASS] tls: cert fetch www.google.com  CN=WR2, O=Google Trust Services, C=US
[PASS] tls: cert fetch www.cloudflare.com  CN=WE1, O=Google Trust Services, C=US
[PASS] tls: cert fetch www.microsoft.com  CN=Microsoft Azure RSA TLS Issuing CA 04
```

| Status | Meaning |
|---|---|
| All `PASS` with legitimate issuers (Google Trust Services, DigiCert, Cloudflare, Sectigo, GlobalSign, Amazon, ISRG, Let's Encrypt) | No SSL inspection on this network. |
| `PASS` with `! unexpected CA` warning | A non-standard CA is signing certs. **This means SSL inspection / MITM is active on this Wi-Fi** — your corporate firewall, antivirus, or rogue CA is intercepting HTTPS. Material finding to flag. |
| `FAIL` | Handshake failed entirely. Likely network blocking outbound 443 to that host, or a broken proxy. |

## SIP OPTIONS probe (1 row)

```
[PASS] sip: probe (skipped - no $SipTarget in config.ps1)  not configured
```

vs

```
[DEGR] sip: OPTIONS to 203.0.113.10:5060/udp  no reply - many SBCs ignore anonymous OPTIONS, OR UDP 5060 is filtered outbound. Compare against TCP 443 to same host to disambiguate.
```

| Status | Meaning |
|---|---|
| `not configured` | You haven't set `$SipTarget` in `config.ps1`. SIP probe is skipped. Fine if you're not testing a specific SBC. |
| `PASS reply: 200 OK` | SBC responded. Network is fine for SIP signalling. |
| `DEGR no reply` | Either (a) SBC ignores anonymous OPTIONS (common — they often only respond to authenticated REGISTER) or (b) UDP 5060 outbound is filtered. To disambiguate: try TCP 443 to the same SBC IP. If TCP works but UDP SIP doesn't, the firewall/ISP is shaping UDP. |

## Egress IP + CGNAT (1 row)

```
[PASS] egress: public IP + CGNAT probe  203.0.113.42 (no CGNAT)
```

| Status | Meaning |
|---|---|
| `PASS` with normal IP | Standard public IP. No special concerns. |
| `DEGR CGNAT detected` | Your ISP is using Carrier-Grade NAT (`100.64.0.0/10` range). Long SIP registrations may break when CGNAT rotates your session. This is common on mobile data + some residential ISPs. |
| `FAIL ifconfig.me unreachable` | No general internet access. Wi-Fi might be captive-portal. |

## DNS hijack check (1 row)

```
[PASS] dns_hijack: compare isp vs 1.1.1.1 on www.cloudflare.com  both return 104.16.124.96;104.16.123.96
[DEGR] dns_hijack: ... isp=10.0.0.1 cf=104.16.123.96 - could be load-balancer or hijack; monitor
```

| Status | Meaning |
|---|---|
| `PASS` (match) | ISP DNS returns the same A-record as 1.1.1.1. No hijacking. |
| `DEGR` (mismatch) | Different A-records. Either (a) load-balanced DNS returning different IPs each query (normal for big sites — usually fine), (b) actual DNS hijacking by ISP, or (c) DNS-based content filter (corporate network). Monitor over time; one mismatch isn't proof of hijack. |

## Connection saturation (1 row)

```
[PASS] conn_sat: 50 parallel TCP to 1.1.1.1:443  50/50 ok in 1986ms
[FAIL] conn_sat: ... capped at 0 - something is blocking
```

| Status | Meaning |
|---|---|
| `PASS` (50/50) | Firewall allows 50+ concurrent TCP connections from this machine to one host. Good. |
| `DEGR` (10-49/50) | Conntrack throttle or firewall rate-limit. Real apps may hit it under load. |
| `FAIL` (0-9/50) | Wi-Fi just dropped TCP SYNs (transient flap) or there's an aggressive firewall blocking. Re-run the smoke; if FAIL persists, switch Wi-Fi. |

## Parallel HTTPS flows (1 row)

```
[PASS] flows: 4 parallel HTTPS to speed.cloudflare.com  4/4 completed
[DEGR] flows: ... 2/4 completed - possible per-flow hashing
```

| Status | Meaning |
|---|---|
| `PASS` (4/4) | All 4 flows completed. ISP's per-flow hashing (if any) routes them all through working paths. |
| `DEGR` (1-3/4) | Some flows failed. Often means the ISP load-balances flows across multiple peering paths and one path is broken. Real-world impact: random TCP connections fail intermittently. |
| `FAIL` (0/4) | All flows failed. HTTPS to this host is blocked. |

## Speedtest server discovery (1 row)

```
[PASS] speedtest: can find a server  list OK
```

A quick `speedtest -L` to confirm Ookla can find at least one nearby server. If FAIL, the speedtest binary is broken or has no network.

## tshark 3-sec sanity capture (1 row)

```
[PASS] tshark: 3-sec capture sanity test  captured 14348 bytes on 'Wi-Fi'
[FAIL] tshark: 3-sec capture sanity test  pcap not created - tshark permission issue?
```

| Status | Meaning |
|---|---|
| `PASS` (>500 bytes captured) | Live capture works. Main loop's continuous pcap will work. |
| `DEGR` (<500 bytes) | Capture started but no traffic. Wi-Fi is idle. Re-run with active browsing; or just trust it'll work in the main loop. |
| `FAIL` | Two main causes: (a) PowerShell isn't running as Administrator (tshark needs admin), (b) Npcap isn't installed or its service is stopped. Run `Get-Service npcap` to check. |

## iperf3 5-sec UDP burst (1 row)

```
[PASS] iperf3: 5-sec UDP to iperf.he.net  UDP burst succeeded
[DEGR] iperf3: ... iperf.he.net unreachable - pick another server
```

| Status | Meaning |
|---|---|
| `PASS` | iperf.he.net responded. Main-loop UDP simulations will work. |
| `DEGR iperf.he.net unreachable` | iperf.he.net is sometimes overloaded or geo-blocks. Not a script failure. Find an alternative free iperf server (or run your own) and edit the script. |
| `FAIL` | iperf3 binary missing. See tool-availability section. |

## Disk space (1 row)

```
[PASS] disk: free space on C:  192.3 GB free on C:
[DEGR] disk: ... 15 GB free on C: - tight for full-day pcap (6-15 GB)
[FAIL] disk: ... only 3 GB free on C: - pcap will fill the disk
```

Self-explanatory. Free up disk before a multi-hour run.

## Wi-Fi snapshot shape (1 row)

```
[PASS] wifi: Get-WifiSnapshot shape  ssid=MyWifi signal=83% rx=287Mbps
[FAIL] wifi: ... netsh wlan show interfaces returned no SSID/Signal - wifi.csv will be empty
```

Confirms the Windows `netsh wlan show interfaces` parser produces usable rows. FAIL means `wifi.csv` will be empty — the script keeps running, but you lose the Wi-Fi context dimension.

## Anycast secondary IPs (2 rows)

```
[PASS] icmp: anycast secondary (1.0.0.1)  avg=6.3ms
[PASS] icmp: anycast secondary (8.8.4.4)  avg=5ms
```

Confirms the `anycast.csv` divergence-pair targets are also reachable. FAIL here means the corresponding pair in `anycast.csv` will be one-sided.

## System cmdlets (1 row)

```
[PASS] system: arp/conn/av cmdlets  arp=7 conn=3 av=True
```

Sanity-check that `arp -a`, `Get-NetTCPConnection`, and `Get-MpComputerStatus` all return data. FAIL means `system.csv` will be empty or partial.

## MTR pathping sanity (1 row)

```
[PASS] mtr: pathping sanity to 1.1.1.1 (5-cycle)  pathping wrote 1462 bytes
```

5-cycle pathping to confirm the main-loop's full pathping (50 cycles, every 2 min) will produce useful output. FAIL means MTR is broken — either pathping is missing (impossible on Windows) or output redirection failed.

## Full speedtest (1 row)

```
[PASS] speedtest: real run (download/upload/latency)  91.1 Mbps down / 82.6 Mbps up / 5.461ms +/- 0.813ms via Tata Teleservices Ltd (New Delhi)
```

The actual capacity baseline. **This is the one preflight row that gives you a concrete real-world number to compare against the rest of the day.** Captured to `speedtest/preflight.json`. If FAIL, the speedtest binary is broken or the network has no general internet.

---

## What "good preflight" looks like overall

Your goal:

```
PREFLIGHT SUMMARY: 38+ PASS / 0-2 DEGRADED / 0-3 FAIL
```

The acceptable FAIL/DEGR rows are:
- ICMP / TCP / SIP probes against your VoIP SBC if it ignores them by policy
- iperf.he.net unreachable from your specific ISP

Anything else as a FAIL is a real blocker. Fix it before doing a 5-hour run, otherwise you'll lose hours of data to a known-broken capability.
