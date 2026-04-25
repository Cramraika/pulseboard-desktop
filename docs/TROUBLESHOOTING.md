# Troubleshooting

Symptoms → causes → fixes.

## Install / setup

### `winget install` fails for any package

Most common: PowerShell isn't running as Administrator, or winget isn't on PATH.

```powershell
# Confirm winget exists:
winget --version
# If not found, install App Installer from Microsoft Store:
# https://www.microsoft.com/store/apps/9NBLGGH4NNS1
```

If winget exists but a specific package fails (`No package found matching input criteria`), the package name may have changed. Search:

```powershell
winget search wireshark
winget search ookla
```

…and update `install.ps1` accordingly, or install manually.

### `iperf3.exe` not in PATH after install

`install.ps1` adds `C:\iperf3\` to your **user PATH**. The new PATH only takes effect in **new** PowerShell windows. Open a new PowerShell and verify:

```powershell
iperf3 --version
```

If still not found, manually verify the binary location:

```powershell
dir C:\iperf3\
```

Should show both `iperf3.exe` AND `cygwin1.dll`. If only the exe is present, the DLL is missing — iperf3 will crash silently on launch. Re-extract the full ar51an zip (it contains both files).

### `iperf3` launches but immediately exits without output

Almost always missing `cygwin1.dll`. See above. The two files MUST be in the same directory.

### Npcap installer downloads but doesn't run

Either UAC blocked it or the download was incomplete. Re-download manually from https://npcap.com and run the installer with admin rights. Important checkboxes:

- ☑ **Install Npcap in WinPcap API-compatible Mode** ← required
- ☑ Support raw 802.11 traffic ← optional but useful
- ☐ Restrict Npcap driver's access to Administrators only ← LEAVE UNCHECKED (otherwise tshark fails for non-admin)

After install, verify the service:

```powershell
Get-Service npcap
# Status should be 'Running'. If 'Stopped':
Start-Service npcap
```

## Running diag.ps1

### `Cannot be loaded because running scripts is disabled on this system`

PowerShell execution policy is restricted. Bypass for the current session:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\diag.ps1 -PreflightOnly -Tag smoke
```

The `-Scope Process` only affects the current PowerShell session — it does NOT change machine-wide policy.

### `tshark` is found but `[FAIL] tshark: 3-sec capture sanity test  pcap not created`

Three causes, in order of likelihood:

1. **PowerShell isn't running as Administrator.** Live capture requires admin. Right-click PowerShell → Run as Administrator.
2. **Npcap is installed but the service isn't running.**
   ```powershell
   Get-Service npcap
   Start-Service npcap   # if Status is Stopped
   ```
3. **Npcap was installed in "admin-only" mode.** Re-run the Npcap installer and uncheck the "Restrict to admin" option.

Verify tshark sees the interface:

```powershell
& "C:\Program Files\Wireshark\tshark.exe" -D
```

Should print a numbered list including your Wi-Fi adapter. If it says "There are no interfaces" — Npcap is broken. Reinstall.

### `[FAIL] iperf3: 5-sec UDP to iperf.he.net  iperf.he.net unreachable`

`iperf.he.net` is a free public iperf3 server provided by Hurricane Electric. It's sometimes overloaded or geo-blocks specific ISPs.

- This is a **DEGRADED** signal in the script, not a hard failure. Main loop will keep trying every 10 min.
- Workaround: pick another public iperf3 server. List: https://github.com/R0GGER/public-iperf3-servers
- Long-term: run your own iperf3 server on a VPS for ~$5/mo. Edit `diag.ps1` to point at it.

### Script seems to hang for several minutes during baseline

Normal — `tracert` and `pathping` to multiple targets each take ~30-60 seconds. Baseline can total 2-7 minutes depending on hops.

If it really is stuck (no output for 10+ min), Ctrl+C. The script writes everything to disk continuously, so partial output is preserved.

### `pings.csv` has rows for some targets but not others

Almost certainly the target is in `$Targets` but unreachable AND ICMP-blocked. Check the corresponding `tcp.csv` row — if TCP works, the target just blocks ICMP (normal for VoIP SBCs).

If a target is unreachable on BOTH ICMP and TCP, double-check the IP in `config.ps1`. Many providers publish ranges (`14.97.20.0/24`); pick a specific live IP from that range.

### `pcap/capture.pcapng` is 0 bytes after a multi-hour run

tshark exited silently. Check `pcap/tshark.log` for the error.

Most common: not enough disk space. Check:

```powershell
Get-Volume -DriveLetter C
```

If less than 5 GB free, tshark may have stopped. Free up space and rerun.

### Output folder has all CSVs but they only have headers (no data rows)

Main loop never started — preflight or baseline crashed silently. Check console output above the prompt for the error. Most common cause was a syntax bug in an earlier version (string literal with non-ASCII char). v1.0+ has CI guards against this.

### `[DEGR] sip: OPTIONS to <my SBC>:5060/udp  no reply`

Two causes:

1. **Your SBC ignores anonymous OPTIONS.** Most production SBCs do — they only respond to authenticated REGISTER. This is normal SBC hardening, not a network problem. Ignore.
2. **UDP 5060 is filtered outbound by your firewall / ISP.** To disambiguate: try TCP 443 to the same SBC IP. If TCP works but UDP SIP doesn't, it's outbound shaping. Check with the network admin.

To distinguish (1) from (2), capture pcap during the SIP probe and look for the outbound UDP packet. If the packet leaves your machine but no reply ever arrives, it's either (1) or upstream-blocked. If the packet doesn't even leave your machine, your local firewall is blocking outbound 5060.

## Output analysis

### "Why is `cloudflare_dns` (1.1.1.1) so much slower than `cloudflare_cdn` (104.16.x)?"

This is the most common surprise — same provider, same anycast network, but 1.1.1.1 routes to a far PoP while 104.16.x routes locally. Your ISP is treating DNS-resolver anycast separately from CDN anycast.

This is a **finding**, not a bug. It's exactly what `anycast.csv` is designed to expose. The implication: any "RTT to 1.1.1.1" benchmark you've seen is overstating real HTTPS latency.

### "Why is my `pings.csv` clean but `mtr/*.txt` shows huge loss on hop 2-3?"

ICMP rate-limiting artifact. Read [`INTERPRETING_MTR.md`](./INTERPRETING_MTR.md). Short version: pathping computes "Source-to-Here" loss based on ICMP TTL-exceeded responses from intermediate routers. Many ISP-internal routers rate-limit those responses or just drop them. The traffic is getting through fine; pathping just can't see the intermediate hops.

### "What does `egress.csv` showing my IP change mid-run mean?"

Your ISP rotated your NAT session. This is common on:
- CGNAT'd connections (`egress_ip` is in `100.64.0.0/10`)
- Mobile data tethering
- Some residential ISPs that re-issue DHCP leases mid-day

For VoIP: this breaks long-lived SIP REGISTER sessions, causing calls to drop or new calls to fail until the client re-registers. If you see this happening during bad-call windows, you've found a real cause.

### "TLS issuer is `Symantec Web Security Service` / `Fortinet` / `<my company name> Root CA` / `Cisco Umbrella`"

Active SSL inspection. Your network is intercepting HTTPS, decrypting it, re-signing with an internal CA, and forwarding it. Implications:

- Adds latency to every TLS handshake (often 5-20 ms)
- May add jitter under load (the inspection device buffers)
- VoIP signalling that's TLS-tunneled (SIPS, SIP-over-WSS) may behave differently
- Privacy: a third party is reading your HTTPS

Not a bug in this script. It's a configuration choice on your network. Flag to your network admin if you didn't know about it.

## CI / Linting

### PSScriptAnalyzer reports findings on PR

Read the action output. Most findings are:

- `PSAvoidUsingCmdletAliases` — replace `gcm` with `Get-Command`, `?` with `Where-Object`, etc.
- `PSAvoidUsingWriteHost` — for the diagnostic script we use Write-Host intentionally for the heartbeat. PSScriptAnalyzer warns; we let it warn.
- `PSUseSingularNouns` — function naming convention nitpick.

Errors block the PR. Warnings don't (unless we tighten CI later).

### CN-token guard fails on a PR

The CI grep'd for one of: `codingninjas`, `@codingninjas`, `Coding Ninjas`, `NetworkMonitorCN`, or specific CN-internal IPs. These tokens identify the originating organisation specifically and MUST NOT appear in the public repo. Find the offending file/line in the action output, remove the token, and push again. (Note: `smartflo` and the public TTBS IP range `14.97.20.0/24` are explicitly **allowed** — they're a legitimate public-provider profile, see `docs/VOIP_PROVIDERS.md`.)

### ASCII-only guard fails on a PR

A `.ps1` file contains a non-ASCII byte (em-dash, smart quote, ellipsis, etc). PowerShell 5.1's default Windows-1252 codepage mis-decodes these and breaks string literals at parse time. Find the file/line in action output, replace with plain ASCII (`--`, `"`, `...`).

## Still stuck?

Open a GitHub issue with:

1. The full `PREFLIGHT.txt` from a smoke run
2. The console output from the failed command
3. Output of `pwsh -Command "$PSVersionTable"` (PowerShell version + OS version)
4. The smallest reproduction (e.g. "ran `.\diag.ps1 -PreflightOnly -Tag smoke` on Windows 11 build 22621, fresh install of all dependencies, get FAIL on tshark")

Don't include `pcap/` files in the issue — they contain real browsing data.
