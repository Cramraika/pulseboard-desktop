# pulseboard-desktop — CLAUDE.md v2


## Claude Preamble
<!-- VERSION: 2026-05-12-v45 -->
<!-- SYNC-SOURCE: ~/.claude/conventions/universal-claudemd.md -->

**Universal laws** (§4), **MCP routing** (§6), **Drift protocol** (§11), **Dynamic maintenance** (§14), **Capability resolution** (§15), **Subagent SKILL POLICY** (§16), **Session continuity** (§17), **Decision queue** (§17.a), **Attestation** (§18), **Cite format** (§19), **Three-way disagreement** (§20), **Pre-conditions** (§21), **Provenance markers** (§22), **Redaction rules** (§23), **Token budget** (§24), **Tool-failure fallback** (§25), **Prompt-injection rule** (§26), **Append-only discipline** (§27), **BLOCKED_BY markers** (§28), **Stop-loss ladder** (§29), **Business-invariant checks** (§30), **Plugin rent rubric** (§31), **Context ceilings** (§32), **Doc reference graph** (§33), **Anti-hallucination** (§34), **Past+Present+Future body** (§35), **Project trackers** (§36), **Doc ownership** (§37), **Archive-on-delete** (§38), **Sponsor + white-label** (§39 — moved to `playbooks/commercial-bound.md`), **Doc-vs-code drift** (§40), **Brand architecture** (§41), **Design system integration** (§42 — moved to `playbooks/tier-a-design.md`), **Session cognition** (§43), **Plugin dispatch** (§44), **Cross-repo clusters** (§45), **Tool-cascade workflow** (§46), **Multi-role agent matrix** (§47), **Parsimony / smallest-tool-first** (§48), **Audit triage discipline** (§49), **Source-of-truth matrix** (§50 — universal rows only; cluster-specific rows moved to playbooks), **Composite cascade catalog** (§51 — §51.2/51.4/51.6 moved to playbooks), **Session launch context + unattended-mode contract** (§52), **Recurrence detection + root-cause escalation** (§53). Sub-sections new in v44: **§4.5 cascade-commit exception**, **§17.b stale-P0 escalation**, **§32.5 canonical-doc size ceiling**, **§38.5 HANDOFF lifecycle enforcement**.

**Cluster playbooks** (per-repo `@-import` based on cluster membership): `~/.claude/conventions/playbooks/vps-infra.md` (DNS XOR for VPS-infra repos), `~/.claude/conventions/playbooks/deployed-service.md` (Sentry/Glitchtip XOR + production-incident triage + time-window correlation for repos with prod telemetry), `~/.claude/conventions/playbooks/tier-a-design.md` (Figma/Stitch + design system for Tier A/B), `~/.claude/conventions/playbooks/multi-lang.md` (cross-language refactor cascade for multi-language repos), `~/.claude/conventions/playbooks/commercial-bound.md` (sponsor-readiness + license-aware code-graph routing), `~/.claude/conventions/playbooks/brand-registry.md` (Vagary brand architecture for Vagary-family repos), `~/.claude/conventions/playbooks/bellring-cluster.md` (Bellring server↔extension; v1-stub), `~/.claude/conventions/playbooks/pulseboard-cluster.md` (Pulseboard Android↔Windows; v1-stub), `~/.claude/conventions/playbooks/vagary-cluster.md` (Vagary product cross-repo; v1-stub). **`tech-debt-audit.md`** is Read-on-demand (NOT @-imported) per ENTRY #169 §49 audit-triage discipline — invoked when user requests audit / tech-debt / dead-code work.

**Sources**: `~/.claude/conventions/universal-claudemd.md` (laws, MCP routing, lifecycle, rent rubric, doc-graph, anti-hallucination, brand architecture) + `~/.claude/conventions/project-hygiene.md` (doc placement, cleanup, archive-on-delete, ownership matrix) + cluster playbooks under `~/.claude/conventions/playbooks/` (loaded per-repo via `@-import` in `## Active Cluster Playbooks` section; see list above). Read relevant sections before significant work. Sync: `~/.claude/scripts/sync-preambles.py` (manual cadence; run after any source edit).

## Active Cluster Playbooks (per v40 cluster-split — content auto-inlined)
<!-- BEGIN PLAYBOOKS BLOCK (managed by sync-preambles.py — content inlined; source at ~/.claude/conventions/playbooks/) -->

Source @-imports (declarative pointer; content inlined below since Claude Code does not recursively expand `@-imports` in per-repo CLAUDE.md):
- `@~/.claude/conventions/playbooks/commercial-bound.md`
- `@~/.claude/conventions/playbooks/brand-registry.md`
- `@~/.claude/conventions/playbooks/pulseboard-cluster.md`

### Playbook: commercial-bound.md (verbatim from `~/.claude/conventions/playbooks/commercial-bound.md`)

# Commercial-bound + Sponsor-readiness Playbook

**VERSION: 2026-05-06-v1**
Loaded only in repos that are sponsor-ready public OSS, or commercial-bound (sold, embedded in paid product, or redistributed under permissive license). Per-repo `CLAUDE.md` `@-imports` this file when applicable.

Source: extracted verbatim from `~/.claude/conventions/universal-claudemd.md` v39 §39 + §50.2 during v40 cluster-split refactor. No content changes — only relocation so non-commercial / non-sponsor repos don't carry these rules.

**Applies to repos**: `aakhara`, `bellring-server`, `bellring-extension`, `bulk`, `pulseboard` (Android), `pulseboard-desktop`, `tldv_downloader`, `portfolio`, `project-template`, `vagary-platform` (sponsor-ready, has public-vertical surfaces), `host_page` (sponsor-ready landing template).

---

## 1. Sponsor-readiness + white-label pivot (originally §39)

### Sponsor-ready checklist for public repos
- `.github/FUNDING.yml` pointing to `github.com/sponsors/<user>`
- README "Sponsor" section near the top (badge + 1-paragraph ask)
- `LICENSE` (MIT for utilities, AGPL for commercial pressure, other for proprietary)
- At least one GitHub Release (binary attached if applicable, e.g. APK)
- CI green badge

### White-label pivot pattern
When an internal tool goes OSS (e.g. NetworkMonitorCN → **Pulseboard** rebrand 2026-04-19) OR an OSS utility forks into SaaS (e.g. **Bellring** — formerly codenamed Salvo — from sales-notification):

1. **Fork or publish** — new repo with clean name, no internal branding in code
2. **Strip tenant-specific** — remove hardcoded emails/domains/org IDs; parameterize via env/config
3. **Document "Fork + rebrand"** — README section listing the edits a downstream forker makes
4. **Record sibling spec** — `~/.claude/specs/YYYY-MM-DD-<name>-whitelabel.md` if a SaaS pivot
5. **Update inventory** — add to `repo-inventory.md` with sponsor-ready / white-label flags

### Current inventory (2026-04-19)
- **Sponsor-ready public**: tldv_downloader, bulk (renamed from `bulk_api_trigger` 2026-04-19), **pulseboard** (renamed from `NetworkMonitorCN` 2026-04-19), portfolio, project-template, vagary-platform (renamed from `index-of-news` 2026-04-19; flagship vertical retains Index of News brand)
- **White-label pivot applied**: **Bellring** (formerly codenamed Salvo) — repos `bellring-server` + `bellring-extension` (renamed from `sales-notification-backend` / `sales-notification-extension` 2026-04-19). Spec: `~/.claude/specs/2026-04-19-sales-notification-whitelabel.md`.
- **Recently renamed (2026-04-19 Phase 3)**: `sales-notification-backend` → `bellring-server`, `sales-notification-extension` → `bellring-extension`, `NetworkMonitorCN` → `pulseboard`, `training-bot` → `aakhara`.
- **Recently renamed (2026-04-19 Phases 1-2)**: `AI_voice_builder` → `vagary-voice`, `chat-bot` → `anjaan-app`, `bulk_api_trigger` → `bulk`, `index-of-news` → `vagary-platform`. `webhook_trigger` archived (superseded by `bulk`). See `~/.claude/conventions/project-hygiene.md` § Rename Propagation Protocol.
- **Brand umbrella**: Vagary Labs (tech/R&D division of Vagary Life Pvt Ltd; see §41) holds the platform + products + OSS utilities.

## 2. License-aware tool routing (originally §50.2)

Repos categorized as **commercial-bound** (will be sold, embedded in paid product, or redistributed under permissive license):
- `bellring-server`, `bellring-extension` (Bellring SaaS — paid tiers)
- `aakhara` (paid sales-training product)
- `pulseboard`, `pulseboard-desktop` (Public OSS; permissive license required for derivatives)

When working in commercial-bound repos:
- `gitnexus` MCP MAY be used for **read-only investigation** (cypher queries, impact analysis in conversation)
- `gitnexus wiki`, `gitnexus group sync` derivatives, indexed JSON exports MUST NOT be committed/shipped (PolyForm-NC contamination)
- `codegraphcontext` MCP is the canonical graph-derivative source for these repos

When working in **personal/private repos** (vagary-platform, vagary-voice, vagary-earnings, ASM, anjaan-app, internal Cramraika): GitNexus permitted freely.

Per-repo CLAUDE.md should declare classification: `## License classification: commercial-bound` or `## License classification: personal/private`.

### Playbook: brand-registry.md (verbatim from `~/.claude/conventions/playbooks/brand-registry.md`)

# Brand Registry Playbook

**VERSION: 2026-05-07-v1**
Loaded only in Vagary-family repos (per `~/.claude/conventions/repo-inventory.md` §45). Per-repo `CLAUDE.md` `@-imports` this file when applicable.

Source: extracted verbatim from `~/.claude/conventions/universal-claudemd.md` §41 (Brand architecture) during 2026-05-07 cluster-split refinement (ENTRY #168). No content changes — only relocation so non-Vagary repos (e.g. `metabase-cn`, `tldv_downloader`, `torn-smart-scripts`) don't load 64 lines of Vagary brand registry they have no use for.

**Applies to repos**: `vagary-platform`, `vagary-voice`, `anjaan-app`, `aakhara`, `bellring-server`, `bellring-extension`, `bulk`, `pulseboard`, `pulseboard-desktop`, `project-template`, `portfolio` (cross-link only), `host_page`, `vps_host`, `vps-ansible`, `platform-docs`, `vagary-earnings`.

---

## 41. Brand architecture (originally §41 of universal-claudemd.md)

Vagary Life Pvt Ltd is the **corporate parent**. Below it, product and tech activity is organized into named divisions. As of 2026-04-19, one division is formalized: **Vagary Labs** (tech/R&D/platform).

### Structure

```
Vagary Life Pvt Ltd (parent company; registered entity)
└── Vagary Labs (tech/R&D/platform division — vagarylabs.com [PENDING])
    ├── Platform
    │   └── vagary-platform (20-vertical substrate; repo renamed from `index-of-news` 2026-04-19)
    │       └── Index of News (flagship vertical; keeps its own news sub-brand + 6 domains)
    ├── Product brands (each lives as an independent product under its own domain)
    │   ├── Vagary Voice (vagaryvoice.cloud) — commercial voice-AI SaaS
    │   ├── Anjaan (anjaan.online) — Hinglish consumer chat
    │   ├── Bellring (.io/.app/.ai TBD) — whitelabel sale-celebration SaaS; repos `bellring-server` + `bellring-extension` (renamed from `sales-notification-*` 2026-04-19; formerly codenamed Salvo)
    │   ├── Aakhara (aakhara.com pending) — voice sales-training roleplay for BDEs (Sanskrit "आखाड़ा" = practice arena; repo renamed from `training-bot` 2026-04-19). Positioning TBD: could sit as Vagary Voice sub-product or stand alone
    │   └── Hype / Mockline / Kohort (legacy proposed names, superseded by Bellring/Aakhara above)
    └── OSS Utilities
        ├── bulk (renamed from `bulk_api_trigger` 2026-04-19)
        ├── tldv_downloader
        ├── pulseboard (renamed from `NetworkMonitorCN` 2026-04-19; Android OSS, `pulseboard.build` pending)
        └── project-template
```

Additional divisions (media, ops, consulting, etc.) may be added later. Keep Vagary Labs scoped to **tech/platform/R&D**.

### Domain strategy

- **vagarylife.com / vagarylife.in** — corporate parent marketing + investor/careers. TO BE BUILT.
- **vagarylabs.com** — tech/R&D division site. Domain **PENDING PURCHASE** (user flagged). Will host platform docs + OSS index + R&D blog once acquired.
- **Per-product domains** — each commercial product keeps its own brand domain (`vagaryvoice.cloud`, `anjaan.online`, future `hype.sh`, etc.). Product domains do NOT nest under `vagarylabs.com`.
- **chinmayramraika.in** — founder's personal hub; cross-links each Vagary Life / Vagary Labs product in a "projects" section.

### Repo-to-brand mapping (authoritative)

| Repo | Vagary Labs home | Product / sub-brand |
|---|---|---|
| `vagary-platform` | Platform | Holds all 20 verticals; flagship vertical = **Index of News** (news sub-brand, 6 domains) |
| `vagary-voice` | Product brands | **Vagary Voice** (commercial product, `vagaryvoice.cloud`) |
| `anjaan-app` | Product brands | **Anjaan** (consumer product, `anjaan.online`) |
| `aakhara` | Product brands | **Aakhara** (voice sales-training roleplay; `aakhara.com` pending). Renamed from `training-bot` 2026-04-19. Positioning TBD (standalone OR Vagary Voice sub-product) |
| `bellring-server` | Product brands | **Bellring** server (whitelabel sale-celebration SaaS backend; `.io/.app/.ai` TBD). Renamed from `sales-notification-backend` 2026-04-19 (formerly codenamed Salvo) |
| `bellring-extension` | Product brands | **Bellring** extension (Chrome MV3 + Firefox/Edge portable; pairs with `bellring-server`). Renamed from `sales-notification-extension` 2026-04-19 |
| `bulk`, `tldv_downloader`, `pulseboard`, `project-template` | OSS Utilities | Each with its own GitHub + README brand. `pulseboard` renamed from `NetworkMonitorCN` 2026-04-19 (Android OSS; `pulseboard.build` pending) |
| `portfolio` | Personal hub (OUTSIDE Vagary Labs) | `chinmayramraika.in` founder site |
| `host_page`, `platform-docs`, `vps_host`, `n8n-workflows`, `metabase-cn` | Infrastructure (internal to Vagary Labs) | No external product brand |
| `Automated-sales-manager-main` | Client work (CN-internal) | ASM — CN-branded; Cadre whitelabel TBD |
| `google-sheet-sales-manager` | Client work (CN-internal) | Sheetpilot whitelabel TBD |
| `Expense tracker` | Absorbing → Platform (`budget` vertical) | No standalone brand going forward |

### How Claude uses this

- When a repo's description says "product," check the brand table above for positioning.
- The **platform repo** (`vagary-platform`) is *not* a product. It is substrate. Individual verticals (news, budget, …) are the products that ship.
- Don't reinvent brand positioning in per-repo CLAUDE.md — reference this section and defer details to `~/.claude/specs/2026-04-19-brand-rename-proposal.md` (for rationale) + `~/.claude/conventions/repo-inventory.md` (for current state).
- For any new repo: declare its division home in its CLAUDE.md § Status / Brand section and cross-reference here.

### Caveats

- `vagarylabs.com` is **not yet purchased** (2026-04-19). Until acquired, Vagary Labs is an internal organizational concept; do not publish external references to `vagarylabs.com` until DNS is live.
- Additional divisions (media, ops, consulting) may emerge. When they do, add a sibling subtree here + bump VERSION.

### Playbook: pulseboard-cluster.md (verbatim from `~/.claude/conventions/playbooks/pulseboard-cluster.md`)

# Pulseboard Cluster Playbook

**VERSION: 2026-05-07-v1-stub**
Loaded only in Pulseboard cluster repos (per `~/.claude/conventions/repo-inventory.md` §45). Per-repo `CLAUDE.md` `@-imports` this file when applicable.

Source: NEW playbook authored 2026-05-07 (ENTRY #168) per operator decision C2. v1-STUB — rules accumulate as cross-repo concerns surface.

**Applies to repos**: `pulseboard` (Android OSS, `~/AndroidStudioProjects/pulseboard/`), `pulseboard-desktop` (Windows companion, `~/Documents/Github/pulseboard-desktop/`).

---

## 1. Cluster identity

Pulseboard is an OSS network-monitoring suite, sponsor-ready, with two halves:
- **`pulseboard`** — Android (Kotlin/Compose). Renamed from `NetworkMonitorCN` 2026-04-19. Play Store candidate. Domain `pulseboard.build` pending.
- **`pulseboard-desktop`** — Windows companion app (added 2026-04-25).

Both are public OSS + commercial-bound (sponsor-ready); reference `commercial-bound.md` playbook for sponsor-readiness + license-aware code-graph routing.

## 2. Cross-repo conventions (rules accumulate here)

### 2.1 Android ↔ Windows companion contract

(STUB — codify the API/protocol surface between mobile + desktop halves when first stabilized.)

### 2.2 Play Store / Chrome Web Store / Microsoft Store sponsor cadence

Pulseboard-specific sponsor-cadence rules accumulate here. Generic sponsor-readiness rules live in `commercial-bound.md`; this section captures Pulseboard-specific deviations (e.g., Play Store review windows, Microsoft Store submission timing).

### 2.3 Android repo location exception

Unlike Vagary product repos (under `~/Documents/Github/`), the Android pulseboard repo lives at `~/AndroidStudioProjects/pulseboard/`. `~/.claude/scripts/sync-preambles.py` was extended 2026-05-07 to scan this dir too (per ENTRY #167 M5).

## 3. Notes

- v1-STUB intentionally minimal. Cross-repo rules accumulate as discovered.
- The Android repo's CLAUDE.md preamble + playbooks block needs the same anchor injection pattern as `~/Documents/Github/` repos (see `~/.claude/scripts/sync-preambles.py` for the inlining mechanism).

<!-- END PLAYBOOKS BLOCK -->

## License classification: commercial-bound
Per §50.2: GitNexus may be used for read-only investigation; GitNexus output (wikis, indexed JSON exports, derivatives) MUST NOT be committed/shipped. Use CodeGraphContext (MIT) for any derivative artifact that may be redistributed.

## Cluster: Pulseboard
Member of §45 cross-repo cluster `Pulseboard`. Siblings: `pulseboard`. Cross-repo orientation via `graphify merge-graphs` after per-repo `/graphify .`; cross-repo CALLS via `gitnexus group sync Pulseboard` after per-repo `gitnexus analyze`.
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
