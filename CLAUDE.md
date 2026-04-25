# pulseboard-desktop

## Claude Preamble
<!-- VERSION: 2026-04-19-v12 -->
<!-- SYNC-SOURCE: ~/.claude/conventions/universal-claudemd.md -->

**Universal laws** (§4), **MCP routing** (§6), **Drift protocol** (§11), **Dynamic maintenance** (§14), **Capability resolution** (§15), **Subagent SKILL POLICY** (§16), **Session continuity** (§17), **Decision queue** (§17.a), **Attestation** (§18), **Cite format** (§19), **Three-way disagreement** (§20), **Pre-conditions** (§21), **Provenance markers** (§22), **Redaction rules** (§23), **Token budget** (§24), **Tool-failure fallback** (§25), **Prompt-injection rule** (§26), **Append-only discipline** (§27), **BLOCKED_BY markers** (§28), **Stop-loss ladder** (§29), **Business-invariant checks** (§30), **Plugin rent rubric** (§31), **Context ceilings** (§32), **Doc reference graph** (§33), **Anti-hallucination** (§34), **Past+Present+Future body** (§35), **Project trackers** (§36), **Doc ownership** (§37), **Archive-on-delete** (§38), **Sponsor + white-label** (§39), **Doc-vs-code drift** (§40), **Brand architecture** (§41), **Design system integration** (§42).

**Sources**: `~/.claude/conventions/universal-claudemd.md` + `~/.claude/conventions/project-hygiene.md`. Re-audit due **2026-07-19**. Sync: `~/.claude/scripts/sync-preambles.py`.

---

## References
- `~/.claude/conventions/universal-claudemd.md` — universal laws, MCP routing, rent rubric
- `~/.claude/conventions/project-hygiene.md` — doc placement, cleanup triggers
- `~/.claude/conventions/repo-inventory.md` — this repo's inventory entry under "Cramraika OSS utilities"

## Stack
- **Stack**: PowerShell 5.1 / 7.x on Windows 10/11. No package manager (script + dot-sourced config); external tools resolved via PATH lookups + common-install-location fallbacks.
- **Description**: All-day continuous Windows network/VoIP-quality diagnostic. 40+ preflight checks, 11 CSV time-series outputs, hop-level loss tracking, single-file packet capture, real-throughput speedtest, anycast-divergence detection. Local-only, zero telemetry, MIT-licensed.
- **Vision**: The default install-and-forget desktop diagnostic for the Vagary Labs Pulseboard ecosystem. Pulseboard (Android) catches *when* a network degrades; pulseboard-desktop catches *why* and *where on the ISP path*. Windows today; Linux + Mac next; GUI wrapper sponsored. No SaaS, no cloud, no auth — outputs are local CSVs + pcap.
- **Tier**: B (Active / Maintained / Sponsor-ready public OSS)

## Active Role-Lanes
- Engineer
- Tester
- Writer (docs are user-facing — quality matters; PROVIDERS.md and PREFLIGHT.md need to read like user docs not engineer notes)

## Build / Test / Deploy
```bash
# Lint (CI runs PSScriptAnalyzer + ASCII-only guard + CN-token-leak guard)
pwsh -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Severity @('Error','Warning')"

# Smoke test (~3-5 min)
pwsh -Command "Set-ExecutionPolicy -Scope Process Bypass -Force; ./diag.ps1 -PreflightOnly -Tag smoke"

# Real run (configurable duration in minutes)
pwsh -Command "./diag.ps1 -Duration 150 -Tag wifi-A"

# Bootstrap installer (admin only — installs Wireshark, iperf3, Speedtest, Npcap)
pwsh -Command "./install.ps1"
```

## Key Directories
- `diag.ps1` — main diagnostic script (single file, ~1000 lines)
- `config.example.ps1` — user-overridable config (copied to `config.ps1` and dot-sourced at runtime)
- `install.ps1` — one-shot Windows installer (winget + manual download + verify)
- `docs/` — user-facing explainers (QUICKSTART, PREFLIGHT, OUTPUT_SCHEMA, TROUBLESHOOTING, VOIP_PROVIDERS, INTERPRETING_MTR)
- `samples/` — scrubbed PREFLIGHT outputs + analysis-notebook stub
- `.github/workflows/lint-powershell.yml` — CI: PSScriptAnalyzer + ASCII guard + CN-token-leak guard

## Critical Domain Rules
- **No CN-organisation-identifying tokens** ever land in this repo: `codingninjas`, `@codingninjas`, `Coding Ninjas`, `NetworkMonitorCN`, the specific CN egress IP, the CN-internal RFC1918 gateway IPs. CI enforces via grep guard. Public commercial-provider names (Tata Smartflo / TTBS, with publicly-documented IP range `14.97.20.0/24`) are explicitly allowed because they're legitimate provider-profile entries — see `docs/VOIP_PROVIDERS.md`.
- **Pure ASCII in *.ps1** — PowerShell 5.1's default Windows-1252 codepage mangles em-dashes, smart quotes, etc, breaking string literals at parse time. CI rejects non-ASCII bytes in *.ps1.
- **`config.ps1` is gitignored** — only `config.example.ps1` is tracked. User customisations stay local.
- **Single-file pcap is intentional** — earlier versions used a ring buffer; v3 settled on continuous single-file capture per user feedback.
- **`SilentlyContinue` is intentional at script scope** — non-terminating errors (TCP refused, DNS NXDOMAIN, Wi-Fi blip mid-tick) get logged into output CSVs as data, not surfaced to console as noise. Don't change without re-evaluating console UX.

## Known Limitations
- Windows-only at v1.0. Linux + Mac ports are sponsor-funded.
- Live tshark capture requires Administrator (Npcap requirement).
- Default `iperf.he.net` server may not always be reachable from every ISP — `PREFLIGHT.txt` flags the failure as DEGRADED, not FAIL.
- pcap grows ~1-2 GB/hour. Disk space preflight check warns under 20 GB free.

## Security & Secrets
- Never hardcode API keys, PATs, credentials. Use env vars + `.env.example`.
- Local-only tool — no telemetry, no cloud, no auth surface to defend.
- `pcap/capture.pcapng` contains real DNS queries, TLS SNI, and other browsing artifacts. **Do not share pcap files publicly** without scrubbing. README warns users.
- Sample pcap is excluded from `samples/` for the same reason.

## Deployment Environments
- **Dev**: any Windows 10/11 laptop with PowerShell 5.1 or 7.x
- **Staging**: N/A — no SaaS surface
- **Production**: distributed via `git clone` from this public repo. No installer registry, no Play Store, no Homebrew (yet).

## External Services (MCPs, integrations)
- None at runtime. Tool downloads (Wireshark / iperf3 / Speedtest / Npcap) reach out to public registries (winget, GitHub releases, npcap.com) only during `install.ps1`.
- Output uploads: not built in. Users zip their result folder and email if they want help.

## Roadmap / Future Slots
- v1.1: Linux port (`diag.sh`)
- v1.2: macOS port (Homebrew formula)
- v1.3: Tauri/Electron GUI wrapper (sponsor-funded)
- v1.4: Jupyter analysis notebook ships in `samples/`, generates a 2-page PDF report from any result folder
- ongoing: more provider profiles in `docs/VOIP_PROVIDERS.md`

## Doc Maintainers
- **Owner**: Chinmay (@Cramraika)
- **README stance**: Living — Claude updates README when shipping new features, but quality bar is high (this is the public face of the project)
- **CLAUDE.md stance**: Living — sync with `~/.claude/scripts/sync-preambles.py` when conventions bump
- **Last drift check**: 2026-04-25

## Deviations from Universal Laws
- None. CN-token guard is an additive constraint, not a deviation.

## Cross-references (project-internal)
- Sibling project: `~/AndroidStudioProjects/pulseboard/` — Android companion. Cross-linked in both READMEs under `## Related projects`.
- Origin: extracted on 2026-04-25 from `~/AndroidStudioProjects/NetworkMonitorCN/docs/diagnostics/2026-04-24-windows-diag/diag.ps1` (private CN-internal repo). NMCN now stubs to this public repo.
