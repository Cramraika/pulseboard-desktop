# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-04-25

Initial public release. Extracted from a private CN-internal repo where the script had matured through 5 versions over ~10 days of intensive field use across two office Wi-Fis and 60+ user devices.

### Added
- `diag.ps1` — single-file PowerShell diagnostic, ~1000 lines. Continuous multi-vertical capture with 40+ preflight checks.
- `install.ps1` — one-shot Windows installer for Wireshark, iperf3, Speedtest CLI, Npcap.
- `config.example.ps1` — user-overridable config; dot-sourced by `diag.ps1` if user copies to `config.ps1`.
- `docs/` — six explainer files: QUICKSTART, PREFLIGHT, OUTPUT_SCHEMA, TROUBLESHOOTING, VOIP_PROVIDERS, INTERPRETING_MTR.
- `samples/` — scrubbed PREFLIGHT examples (one passing, one ISP-issue) + Jupyter analysis notebook stub.
- `.github/workflows/lint-powershell.yml` — CI runs PSScriptAnalyzer + ASCII-only guard + CN-token-leak guard.
- `.github/ISSUE_TEMPLATE/voip-provider-request.md` — structured request template for adding new provider profiles.

### Capabilities
- Per-tick (1 min): pings × N targets, TCP 443, DNS × 4 resolvers × M names, Wi-Fi snapshot, anycast divergence, SIP OPTIONS (if configured), system context (ARP/conn/AV).
- Continuous (background): 1-second-resolution ping loggers per target, single-file packet capture via tshark.
- Periodic: MTR (every 2 min), iperf3 UDP burst (every 10 min), parallel HTTPS flows (every 10 min), TLS cert fetch (every 5 min), DNS hijack check (every 5 min), egress IP probe (every 5 min), port grid (every 30 min), connection saturation (every 30 min), full speedtest (every 60 min).
- Modes: `-PreflightOnly` for ~3-5 min smoke; `-Duration <minutes>` for full continuous capture.
- All output to plain CSVs + JSON + pcap. No telemetry, no cloud, no auth.

### Known limitations
- Windows-only (PowerShell 5.1 / 7.x). Linux + macOS ports are sponsor-funded roadmap items.
- Requires Administrator for live tshark capture.
- Default `iperf.he.net` server is sometimes unreachable from specific ISPs (DEGRADED preflight row, not a blocker).
- Provider profiles in `docs/VOIP_PROVIDERS.md` cover ~9 providers at v1.0; community contributions welcome via the issue template.
