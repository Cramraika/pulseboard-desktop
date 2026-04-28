# pulseboard-desktop — CLAUDE.md v2

**Date:** 2026-04-28 (S11B authoring)
**Supersedes:** v1 (commit-sha pending S11C verification)
**Tier:** B (Active / Maintained / Sponsor-ready public OSS) — **off-fleet by design** (local-only Windows tool)

## Identity & Role

`pulseboard-desktop` is the **all-day continuous Windows network/VoIP-quality diagnostic** companion to the Pulseboard Android app. PowerShell-based: 40+ preflight checks, 11 CSV time-series outputs, hop-level loss tracking, single-file packet capture, real-throughput speedtest, anycast-divergence detection. Local-only, zero telemetry, MIT.

**Sibling pairing:** Pulseboard (Android) catches *when* a network degrades; pulseboard-desktop catches *why* and *where on the ISP path*.

Vagary Labs brand: **Pulseboard** (OSS Utilities; off-fleet sibling).

## Coverage Today (post-PCN-S6/S7/S11A)

Per matrix taxonomy (off-fleet by design — minimal cells):

```
Mail | DNS | RP | Orch | Obs | Backup | Sup | Sec | Tun | Err | Wflw | Spec
 NA  | NA  | NA | NA   | NA  | NA     | T   | U   | NA  | NA  | NA   | NA
```

- USED: Sec (CN-token-leak guard in CI; ASCII-only guard; no telemetry; no cloud; no auth surface to defend; pcap/CSV outputs are user-local).
- TRIGGER-TO-WIRE: Sup (Cosign post-PR-#50 — applies to release artefacts).
- NA across all VPS dimensions — local-only Windows tool; no VPS hosting.

## What's Wired

- **Distribution:** `git clone` from public repo. No installer registry, no Homebrew, no Play Store (yet).
- **CI:** PSScriptAnalyzer + ASCII-only guard + CN-token-leak guard (no `codingninjas`/`@codingninjas`/`Coding Ninjas`/`NetworkMonitorCN`/CN egress IP / CN RFC1918 gateway IPs ever land in repo).
- **Sponsor:** FUNDING.yml + README CTA.

## Stack

- **Stack:** PowerShell 5.1 / 7.x on Windows 10/11. No package manager (script + dot-sourced config); external tools resolved via PATH lookups + common-install-location fallbacks.
- **External tools:** Wireshark, iperf3, Speedtest CLI, Npcap (installed by `install.ps1`).
- **Critical domain rule:** Pure ASCII in `*.ps1` (PowerShell 5.1 default Windows-1252 codepage mangles em-dashes / smart quotes — CI rejects non-ASCII bytes).
- **Critical domain rule:** `config.ps1` is gitignored — only `config.example.ps1` is tracked.

## Roadmap (post-S11A)

### Cluster 3 — Cosign per-repo CI fanout
- T (post host_page PR #50 merge); applies to GitHub Release `.zip` bundles (signed pre-distribution).

### Existing roadmap (carried forward)
- **v1.1 — Linux port** (`diag.sh`)
- **v1.2 — macOS port** (Homebrew formula)
- **v1.3 — Tauri/Electron GUI wrapper** (sponsor-funded)
- **v1.4 — Jupyter analysis notebook** ships in `samples/`, generates 2-page PDF report from any result folder.
- **Ongoing:** more provider profiles in `docs/VOIP_PROVIDERS.md`.

## ADR Compliance

- **ADR-038 personal-scope:** ✓ — Cramraika org public; MIT; off-fleet by design.
- **ADR-033 Renovate canonical:** N/A (PowerShell + manual external tools; no package manager surface).
- **ADR-041 Trivy gate:** N/A (no container image; local Windows tool).
- **SOC2 risk-register cross-ref:** N/A (no customer data; user-local pcap outputs are user's responsibility).

## Cross-references

- `platform-docs/05-architecture/part-B-service-appendices/products/pulseboard-desktop.md` (or specialized tier; pending S11B authoring)
- Sibling repo: `~/AndroidStudioProjects/pulseboard/CLAUDE.md` (Android companion)
- Origin: extracted 2026-04-25 from `~/AndroidStudioProjects/NetworkMonitorCN/docs/diagnostics/2026-04-24-windows-diag/diag.ps1` (private CN-internal repo); NMCN now stubs to this public repo.
- `~/.claude/conventions/universal-claudemd.md` §41 brand architecture (Pulseboard)
- `~/.claude/conventions/repo-inventory.md`

## Migration from v1

**Major v1 → v2 changes:**
1. Per-project-service-matrix row added — off-fleet by design; only Sec USED + Sup T.
2. Cluster 3 Cosign per-repo CI fanout queued post-PR-#50 (release artefacts).
3. CN-token-leak guard reaffirmed as CI-enforced critical domain rule.
4. Sibling pairing with Android Pulseboard cited.
5. Pulseboard brand architecture §41 cited.
