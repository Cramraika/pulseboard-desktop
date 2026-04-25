# Quickstart — install to first PREFLIGHT in ~10 minutes

## 0. Prerequisites

- Windows 10 or 11
- Admin access to the laptop (Npcap + tshark live capture both require it)
- ≥ 20 GB free on `C:` (full-day pcap = 6-15 GB)
- A network connection (the install script downloads Wireshark, iperf3, and Npcap)

## 1. Clone

Open an **elevated** (Run as administrator) PowerShell. All commands assume you're admin.

```powershell
git clone https://github.com/Cramraika/pulseboard-desktop.git C:\pulseboard-desktop
cd C:\pulseboard-desktop
```

## 2. Install dependencies

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

This handles, in order:

1. `winget install Ookla.Speedtest.CLI` — Speedtest CLI (no GUI, just the binary)
2. `winget install WiresharkFoundation.Wireshark` — Wireshark, which provides `tshark.exe` for packet capture
3. `winget install Microsoft.Sysinternals.PsTools` — useful TCP/UDP probes
4. Downloads + extracts iperf3 (ar51an Win64 build) to `C:\iperf3\` and adds it to your user PATH
5. Downloads + launches Npcap installer (you'll need to click through ~3 dialogs; **check the WinPcap-compatibility box**)
6. Verifies each tool with `--version` / equivalent

If anything fails, see [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md). Most failures are recoverable in <5 min.

## 3. (Optional) Configure

For default monitoring of generic public anycast endpoints (Cloudflare, Google, Microsoft Teams), no config is needed. To track YOUR VoIP SBC / SIP gateway / specific provider:

```powershell
Copy-Item config.example.ps1 config.ps1
notepad config.ps1
```

Either uncomment a pre-written provider snippet (see [`VOIP_PROVIDERS.md`](./VOIP_PROVIDERS.md)) or define your own `$Targets`, `$SipTarget`, `$PortGrid` blocks. Save and close.

## 4. Smoke test (3-5 min)

```powershell
.\diag.ps1 -PreflightOnly -Tag smoke
```

When it finishes, open the latest output folder:

```powershell
explorer (Get-ChildItem C:\NMDiag -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

Read `PREFLIGHT.txt`. The bottom line tells you:

```
PREFLIGHT SUMMARY: N PASS / M DEGRADED / K FAIL
```

You want **zero unexpected FAILs**. See [`PREFLIGHT.md`](./PREFLIGHT.md) for which DEGRADED / FAIL rows are normal vs blockers.

## 5. Real run

```powershell
# 2.5 hours
.\diag.ps1 -Duration 150 -Tag morning

# Full workday
.\diag.ps1 -Duration 570 -Tag full-workday

# Two-laptop A/B (run on each laptop, on different Wi-Fis)
.\diag.ps1 -Duration 150 -Tag wifi-A   # laptop A
.\diag.ps1 -Duration 150 -Tag wifi-B   # laptop B
```

Don't minimise the PowerShell window — leave it visible so you can watch the per-tick heartbeat. The script writes everything to disk continuously, so a power loss only loses the in-flight tick.

## 6. Analyse the output

When the run ends:

1. The script prints `[*] Done. Output: C:\NMDiag\<timestamp>-<tag>`
2. Zip that folder
3. Either:
   - Open the CSVs in Excel / Google Sheets and pivot
   - Open `pcap/capture.pcapng` in Wireshark
   - Read [`OUTPUT_SCHEMA.md`](./OUTPUT_SCHEMA.md) for column-by-column meaning of each CSV

If you found a real issue (ISP loss, bad hop, jitter spike during business hours), the `pings.csv` + `mtr/*.txt` + `speedtest/*.json` are the artifacts to attach to your ISP support ticket.

## What's next

- See [`PREFLIGHT.md`](./PREFLIGHT.md) for understanding each preflight row
- See [`OUTPUT_SCHEMA.md`](./OUTPUT_SCHEMA.md) for the CSV reference
- See [`INTERPRETING_MTR.md`](./INTERPRETING_MTR.md) before you panic over high pathping loss numbers (often it's an ICMP rate-limiting artifact, not real loss)
