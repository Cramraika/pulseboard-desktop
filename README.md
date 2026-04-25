# pulseboard-desktop

> **All-day Windows network + VoIP-quality diagnostic. 40+ pre-flight checks, hop-level loss tracking, packet capture, and a real-throughput baseline — without the SaaS dashboard.**

[![GitHub Sponsors](https://img.shields.io/github/sponsors/Cramraika?logo=github&label=Sponsor)](https://github.com/sponsors/Cramraika)
[![Stars](https://img.shields.io/github/stars/Cramraika/pulseboard-desktop?style=social)](https://github.com/Cramraika/pulseboard-desktop/stargazers)
[![License](https://img.shields.io/github/license/Cramraika/pulseboard-desktop)](./LICENSE)
[![Issues](https://img.shields.io/github/issues/Cramraika/pulseboard-desktop)](https://github.com/Cramraika/pulseboard-desktop/issues)

When VoIP calls degrade, "the Wi-Fi feels slow", or your ISP claims everything is fine — you need ground-truth evidence, not anecdote. **pulseboard-desktop** runs continuously on a Windows laptop for hours, capturing per-second pings, DNS resolution times, TLS cert issuers, hop-by-hop loss, real throughput, packet captures, and 10+ other vertical signals. It writes everything to plain CSVs so you can pivot in a spreadsheet, file an evidence-backed ISP ticket, or compare two Wi-Fis side by side.

Windows 10 / 11. PowerShell 5.1 or 7.x. Linux + Mac ports on the roadmap.

## Who is this for?

- **VoIP / SIP administrators** triaging "why are calls dropping every afternoon?" on Smartflo / Twilio / RingCentral / Zoom Phone / 3CX / FreePBX / etc.
- **IT teams** who need to prove an ISP fault before escalating — capture hop-level loss across the ISP's network, hand the ticket the data
- **Network engineers** comparing two Wi-Fis or two ISPs in the same building (run on two laptops, then diff the CSVs)
- **Power users** who suspect their ISP is fast-laning DNS while throttling real HTTPS — there's a built-in test for exactly that

## 💖 Sponsor this project

If pulseboard-desktop saves you a finger-pointing meeting with your ISP, [sponsor on GitHub](https://github.com/sponsors/Cramraika) — your support funds:

- **Linux + Mac ports** (`diag.sh` + Homebrew tap)
- **GUI wrapper** — one-click runner + interactive output viewer
- **Jupyter analysis notebook** that turns a 5 GB result folder into a 2-page PDF report
- **More VoIP-provider profiles** in `docs/VOIP_PROVIDERS.md` (each is a weekend of research + testing)

Or [reach out](https://chinmayramraika.in) about enterprise support, custom integrations, or consulting on a network you're trying to fix.

## ✨ What it captures

Every minute, simultaneously, for as long as you let it run:

- **Pings to 5+ targets** (configurable) at 20 probes each — measures loss, RTT, jitter
- **1-second-resolution ping logger** to each target (microburst detection)
- **TCP 443 reachability** + connect time per target
- **DNS resolution** across 4 resolvers × 4 names — catches resolver-specific failures
- **TLS cert issuer** for known sites — detects active SSL inspection / MITM
- **Wi-Fi context**: SSID, BSSID, RSSI, link rate, channel
- **Anycast divergence** — same provider, DNS PoP vs CDN PoP RTTs (catches ISP fast-laning DNS while throttling real HTTPS)
- **System context**: ARP table size, established connections, AV state
- **SIP OPTIONS** to your SBC if configured (raw UDP 5060 datagram every minute)

Every 2 minutes: **MTR (pathping)** to each target — hop-level loss

Every 10 minutes: **iperf3 UDP burst** + **8 parallel HTTPS flows** (catches per-flow ISP hashing)

Every 30 minutes: **port-grid TCP probe**, **connection-saturation test**

Every 60 minutes: **full speedtest** (real Mbps + ping under load)

Continuous: **packet capture** (single-file pcap; opens in Wireshark)

40+ **PREFLIGHT** checks at startup confirm every probe and tool is working before committing to a multi-hour run — failures are surfaced in human-readable PASS/DEGR/FAIL labels.

## 🚀 Quick Start

### Prerequisites

- Windows 10 / 11
- Admin PowerShell (required for live packet capture)
- ≥ 20 GB free on `C:` (packet capture grows ~1-2 GB/hour)

### Install

Run from an **elevated** (Administrator) PowerShell:

```powershell
git clone https://github.com/Cramraika/pulseboard-desktop.git C:\pulseboard-desktop
cd C:\pulseboard-desktop
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

`install.ps1` automates: Ookla Speedtest CLI (winget), Wireshark + tshark (winget), iperf3 (downloads from [ar51an Win build](https://github.com/ar51an/iperf3-win-builds/releases/latest)), Npcap (downloads + opens GUI installer; check the WinPcap-compatible mode box).

### Configure (optional)

For default monitoring of generic public anycast endpoints, no config needed. To track YOUR VoIP SBC / SIP gateway:

```powershell
Copy-Item config.example.ps1 config.ps1
notepad config.ps1
```

Uncomment the snippet matching your provider (Twilio / RingCentral / 3CX / FreePBX / Smartflo / etc — full list in [`docs/VOIP_PROVIDERS.md`](./docs/VOIP_PROVIDERS.md)) or define your own `$Targets`.

### Smoke test (~3-5 min)

```powershell
.\diag.ps1 -PreflightOnly -Tag smoke
```

Open `C:\NMDiag\<timestamp>-smoke\PREFLIGHT.txt`. Aim for `N PASS / 0 FAIL`.

### Real run (2.5 hr or full day)

```powershell
.\diag.ps1 -Duration 150  -Tag morning      # 2.5 hr
.\diag.ps1 -Duration 570  -Tag full-workday # 9.5 hr
```

Two-laptop A/B (one per Wi-Fi) — same command on each, just change `-Tag`. Then diff the resulting `pings.csv`, `anycast.csv`, `speedtest/*.json`, etc.

When done, zip the output folder and analyse — every CSV has a timestamp column and is spreadsheet-pivotable.

## 📂 Output folder layout

```
C:\NMDiag\<timestamp>-<tag>\
├── baseline.txt                — one-shot system + tracert + path-MTU dump
├── PREFLIGHT.txt               — PASS/DEGR/FAIL per capability (40+ checks)
├── pings.csv                   — per-minute 20-ping batch × N targets
├── tcp.csv                     — per-minute TCP 443 connect timing
├── dns.csv                     — per-minute DNS lookup × 4 resolvers × names
├── tls_cert.csv                — every 5 min TLS cert issuer/thumbprint
├── wifi.csv                    — per-minute SSID/RSSI/link rate
├── anycast.csv                 — DNS-vs-CDN anycast divergence (the money pivot)
├── egress.csv                  — every 5 min: public IP + ASN + CGNAT flag
├── system.csv                  — per-minute ARP, conn count, AV state
├── sip_options.csv             — per-minute SIP OPTIONS (if configured)
├── dns_hijack.csv              — every 5 min: ISP-vs-1.1.1.1 A-record diff
├── port_grid.csv               — every 30 min: TCP grid across known ports
├── conn_sat.csv                — every 30 min: max-concurrent-TCP saturation
├── parallel_flows.csv          — every 10 min: 8 parallel HTTPS — flow hashing
├── ping1s/<target>.csv         — 1-second-resolution ping log
├── mtr/<HHMMSS>-<target>.txt   — every 2 min: pathping per target
├── iperf/<HHMMSS>.json         — every 10 min: 60s UDP burst
├── speedtest/<HHMMSS>.json     — every 60 min: full speedtest
└── pcap/capture.pcapng         — continuous packet capture
```

Full schema reference: [`docs/OUTPUT_SCHEMA.md`](./docs/OUTPUT_SCHEMA.md)

## 📚 Docs

- [`docs/QUICKSTART.md`](./docs/QUICKSTART.md) — install → first smoke → real run
- [`docs/PREFLIGHT.md`](./docs/PREFLIGHT.md) — every PREFLIGHT row explained, what each FAIL means
- [`docs/OUTPUT_SCHEMA.md`](./docs/OUTPUT_SCHEMA.md) — every CSV column reference
- [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md) — Npcap / tshark / iperf3 / admin / common failures
- [`docs/VOIP_PROVIDERS.md`](./docs/VOIP_PROVIDERS.md) — pre-written `config.ps1` snippets for common SIP providers
- [`docs/INTERPRETING_MTR.md`](./docs/INTERPRETING_MTR.md) — how to read pathping output, the ICMP-rate-limit caveat

## Related projects

- **[Pulseboard](https://github.com/Cramraika/pulseboard)** — the Android companion. Continuously samples internet quality from employees' phones and uploads 15-min aggregates to a Google Sheet. Pulseboard captures *when* and *who* sees degradation; pulseboard-desktop captures *why* and *where on the ISP path*.
- **[bulk](https://github.com/Cramraika/bulk)** — production-ready CSV-to-webhook bulk trigger with resume + rate-limiting. Other Vagary Labs OSS.
- **[tldv_downloader](https://github.com/Cramraika/tldv_downloader)** — bulk-export tldv.io meeting recordings. Other Vagary Labs OSS.

## Contributing

PRs welcome. The two highest-value contributions are (a) provider profiles in `docs/VOIP_PROVIDERS.md` for a SIP provider that isn't covered yet, and (b) bug reports with the full output folder zipped (after redacting sensitive IPs).

For provider profile requests, please use the dedicated issue template — there's enough structure that we can land most provider snippets within a day if your data is clean.

PowerShell linting: `Invoke-ScriptAnalyzer -Path . -Recurse -Severity @('Error','Warning')` runs on every PR. Keep it green.

## License

MIT. See [LICENSE](./LICENSE).

## Author

Built by [Chinmay Ramraika](https://chinmayramraika.in) under the Vagary Labs OSS umbrella.
