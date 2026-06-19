# pulseboard-desktop — stack & architecture

## Stack
- **Stack:** PowerShell 5.1 / 7.x on Windows 10/11. No package manager (script + dot-sourced config); external tools resolved via PATH lookups + common-install-location fallbacks.
- **External tools:** Wireshark, iperf3, Speedtest CLI, Npcap (installed by `install.ps1`).
- **Critical domain rule:** Pure ASCII in `*.ps1` (PowerShell 5.1 default Windows-1252 codepage mangles em-dashes / smart quotes — CI rejects non-ASCII bytes).
- **Critical domain rule:** `config.ps1` is gitignored — only `config.example.ps1` is tracked.

## Architecture
`pulseboard-desktop` is the **all-day continuous Windows network/VoIP-quality diagnostic** companion to the Pulseboard Android app. PowerShell-based: 40+ preflight checks, 11 CSV time-series outputs, hop-level loss tracking, single-file packet capture, real-throughput speedtest, anycast-divergence detection. Local-only, zero telemetry, MIT.

**Sibling pairing:** Pulseboard (Android) catches *when* a network degrades; pulseboard-desktop catches *why* and *where on the ISP path*.

Vagary Labs brand: **Pulseboard** (OSS Utilities; off-fleet sibling).


Per matrix taxonomy (off-fleet by design — minimal cells):

```
Mail | DNS | RP | Orch | Obs | Backup | Sup | Sec | Tun | Err | Wflw | Spec
 NA  | NA  | NA | NA   | NA  | NA     | T   | U   | NA  | NA  | NA   | NA
```

- USED: Sec (CN-token-leak guard in CI; ASCII-only guard; no telemetry; no cloud; no auth surface to defend; pcap/CSV outputs are user-local).
- TRIGGER-TO-WIRE: Sup (Cosign post-PR-#50 — applies to release artefacts).
- NA across all VPS dimensions — local-only Windows tool; no VPS hosting.


- **Distribution:** `git clone` from public repo. No installer registry, no Homebrew, no Play Store (yet).
- **CI:** PSScriptAnalyzer + ASCII-only guard + CN-token-leak guard (no `codingninjas`/`@codingninjas`/`Coding Ninjas`/`NetworkMonitorCN`/CN egress IP / CN RFC1918 gateway IPs ever land in repo).
- **Sponsor:** FUNDING.yml + README CTA.
