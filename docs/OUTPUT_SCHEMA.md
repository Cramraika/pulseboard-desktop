# Output schema — every CSV column reference

Every `diag.ps1` run writes to `C:\NMDiag\<timestamp>-<tag>\`. This doc explains every file and every column.

## Folder layout

```
<timestamp>-<tag>/
├── baseline.txt          one-shot system + tracert + path-MTU dump
├── PREFLIGHT.txt         PASS/DEGR/FAIL per capability (40+ checks). See PREFLIGHT.md.
├── pings.csv             per-minute 20-ping batch × N targets
├── tcp.csv               per-minute TCP 443 connect timing
├── dns.csv               per-minute DNS lookup × N resolvers × M names
├── tls_cert.csv          every 5 min: TLS cert issuer/thumbprint
├── wifi.csv              per-minute SSID/RSSI/link rate
├── anycast.csv           DNS-anycast vs CDN-anycast RTT divergence per minute
├── egress.csv            every 5 min: public IP + ASN + CGNAT flag
├── system.csv            per-minute ARP table size, established conn count, AV state
├── sip_options.csv       per-minute SIP OPTIONS (only if $SipTarget configured)
├── dns_hijack.csv        every 5 min: ISP-vs-1.1.1.1 A-record diff
├── port_grid.csv         every 30 min: TCP grid across known ports
├── conn_sat.csv          every 30 min: max-concurrent-TCP saturation
├── parallel_flows.csv    every 10 min: 8 parallel HTTPS - flow hashing detector
├── ping1s/<target>.csv   1-second-resolution ping log per target
├── mtr/<HHMMSS>-<target>.txt   every 2 min: pathping per target
├── iperf/<HHMMSS>.json   every 10 min: 60-second UDP burst (~80 kbps)
├── speedtest/<HHMMSS>.json  every 60 min: full speedtest (down/up/lat/jit)
└── pcap/capture.pcapng   continuous packet capture (single file)
```

---

## `pings.csv`

Per-tick ping batch (20 probes per target). One row per target per tick.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 with offset | UTC moment of the tick |
| `target` | string | Target name from `$Targets` |
| `ip` | IPv4 | Target IP |
| `sent` | int | Probes sent (always 20 for default) |
| `received` | int | Probes that returned a Reply |
| `loss_pct` | float 0-100 | `(sent - received) / sent * 100` |
| `min_ms` / `avg_ms` / `max_ms` | int / float / int | RTT stats over received probes |
| `jitter_ms` | float | Mean of consecutive RTT diffs (RFC 3550 inter-packet jitter approximation) |

Key pivot: `target × loss_pct` over time, smoothed by 5- or 15-min window, faceted per Wi-Fi.

## `ping1s/<target>.csv`

1-second-resolution ping log. One file per target. Useful for microburst detection.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC moment of the probe |
| `rtt_ms` | int | RTT in ms; `-1` if probe failed |
| `status` | enum | `ok` / `loss` / `err` |

## `tcp.csv`

Per-tick TCP-connect probe to each target on its `$Targets[].Port`. Catches ICMP-only loss (where the host blocks ICMP but TCP works fine).

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the tick |
| `target` | string | Target name |
| `ip` | IPv4 | Target IP |
| `port` | int | Probed port (default 443) |
| `success` | 0 / 1 | Did the TCP three-way handshake complete? |
| `connect_ms` | int | Time to handshake; `-1` if failed |

## `dns.csv`

Per-tick DNS lookup. Cross-product of `$DnsResolvers` × `$DnsNames`. Rows = R × N per tick.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the tick |
| `resolver` | string | Resolver name from `$DnsResolvers` (`isp_default` / `cloudflare` / `google` / `quad9`) |
| `resolver_ip` | IPv4 / empty | Resolver IP; empty for system default |
| `name` | string | Hostname queried |
| `success` | 0 / 1 | Did the lookup return at least one A record? |
| `duration_ms` | int | Wall time of the lookup |
| `answer` | string | Up to 3 A records, semicolon-separated |

## `wifi.csv`

Per-tick `netsh wlan show interfaces` snapshot.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the tick |
| `ssid` | string | Connected SSID (may be `<unknown ssid>` if location permission isn't granted) |
| `bssid` | MAC | AP MAC address (may be `02:00:00:00:00:00` sentinel if no AP info) |
| `signal_pct` | int 0-100 | RSSI converted to percentage by Windows |
| `rx_mbps` / `tx_mbps` | int | Negotiated link rates |
| `channel` | int | Wi-Fi channel number |
| `auth` | string | Auth method (`WPA2-Personal`, `WPA3-Enterprise`, etc) |
| `radio` | string | `802.11ax` / `802.11ac` / etc |

## `anycast.csv`

Per-tick comparison of two IPs claimed to be in the same anycast service. Measures how differently the local ISP routes them. **The DNS-vs-CDN cross-tier rows are the most analytically useful** — they reveal whether your ISP fast-lanes resolver traffic while routing real HTTPS through congested paths.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the tick |
| `pair` | string | Pair name from `$AnycastPairs` |
| `a_rtt` / `b_rtt` | float | Average RTT to A and B |
| `a_loss` / `b_loss` | float | Loss% to A and B |
| `divergence_ms` | float | `abs(a_rtt - b_rtt)` |

Default pairs:
- `cloudflare_dns_anycast`: 1.1.1.1 vs 1.0.0.1 (same provider, same service)
- `google_dns_anycast`: 8.8.8.8 vs 8.8.4.4
- `cloudflare_dns_vs_cdn`: 1.1.1.1 (DNS PoP) vs 104.16.132.229 (CDN PoP)
- `google_dns_vs_api`: 8.8.8.8 (DNS PoP) vs 142.250.193.100 (Front-End PoP)

A consistent 30+ ms divergence on the cross-tier pairs means the ISP is routing the two services through materially different paths.

## `egress.csv`

Every 5 minutes: queries `ifconfig.me` for the current public IP, and `ipapi.co` for ASN/org/country. Also flags CGNAT.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the probe |
| `egress_ip` | IPv4 / `ERR` | Public IP as seen externally |
| `country` | string | Country name |
| `org` | string | ISP / hosting org |
| `asn` | string | AS number |
| `cgnat` | True / False | Is the IP in `100.64.0.0/10`? |

Watch for `egress_ip` changing during a single run — that means your ISP rotated your NAT session, which can break long-lived SIP registrations.

## `system.csv`

Per-tick OS/security context.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the tick |
| `arp_entries` | int | Number of entries in `arp -a` (Aruba broadcast-storm detector — sudden growth = trouble) |
| `established_conns` | int | Count of `Get-NetTCPConnection -State Established` |
| `defender_realtime` | True / False | Is Windows Defender real-time protection on? Inline AV adds latency to every TCP/UDP packet. |

## `tls_cert.csv`

Every 5 minutes: TLS cert fetch from each `$TlsHosts` entry. **Detects active SSL inspection** by surfacing the cert issuer.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the probe |
| `host` | string | Hostname |
| `issuer` | string | Cert issuer subject |
| `subject` | string | Cert subject |
| `thumbprint` | hex | SHA-1 thumbprint |
| `not_after` | ISO 8601 | Cert expiry |
| `tls_version` | string | Negotiated TLS protocol (Tls13, Tls12) |

**Red flag**: issuer is anything other than `Google Trust Services`, `DigiCert`, `Cloudflare`, `Sectigo`, `GlobalSign`, `Amazon`, `ISRG`, `Let's Encrypt`. That means your network is intercepting + re-issuing certs (corporate firewall, AV with HTTPS inspection, or a malicious proxy).

## `sip_options.csv`

Per-tick raw SIP OPTIONS to your SBC. Only meaningful if `$SipTarget` is set in `config.ps1`.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the tick |
| `success` | 0 / 1 | Did we receive any SIP response? |
| `ms` | int | RTT to first byte of response; `-1` if no reply |
| `status` | string | Parsed SIP response line (e.g. `200 OK`) or error class |
| `from_tag` | string | Random tag generated for that probe (correlates with pcap if needed) |

Most SBCs ignore anonymous OPTIONS, so seeing all `success=0` is not necessarily bad — it just confirms the SBC's policy.

## `dns_hijack.csv`

Every 5 minutes: A-record comparison between system-default resolver and 1.1.1.1.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the probe |
| `name` | string | Queried hostname |
| `resolver_a` | string | "isp_default" |
| `answer_a` | string | A records from system DNS |
| `resolver_b` | string | "1.1.1.1" |
| `answer_b` | string | A records from Cloudflare |
| `match` | True / False | Are the answers identical? |

Mismatches happen normally with load-balanced DNS (A records rotate). Persistent mismatches across many minutes are the signal for actual DNS hijacking.

## `port_grid.csv`

Every 30 minutes: TCP-connect to each `$PortGrid` entry. Detects port-specific firewall blocks.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the probe |
| `label` | string | Human-readable label from `$PortGrid` |
| `host` | string | Hostname / IP |
| `port` | int | TCP port |
| `proto` | string | `tcp` (UDP not currently supported here) |
| `success` | 0 / 1 | Connect succeeded? |
| `connect_ms` | int | Connect time; `-1` if failed |

## `conn_sat.csv`

Every 30 minutes: how many simultaneous TCP connections does the firewall allow you to open to one host before failing?

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC of the probe |
| `cap` | int | Max concurrent connections opened (up to 200) |
| `time_ms` | int | Total time |
| `last_error` | string | Why it failed at `cap+1` |

Low caps (< 100) suggest aggressive firewall conntrack limits.

## `parallel_flows.csv`

Every 10 minutes: 8 simultaneous HTTPS GETs to `speed.cloudflare.com`. Detects per-flow ISP load-balancing where some flows go through a broken peering path while others go through a clean one.

| column | type | meaning |
|---|---|---|
| `timestamp` | ISO 8601 | UTC |
| `run_id` | string | HHMMSS of the run, joins all 8 flows of one fan-out |
| `flow_id` | int 1-8 | Which flow within the fan-out |
| `status` | 0 / 1 | Did the flow complete? |
| `connect_ms` | int | Total flow time |
| `bytes` | int | Bytes received (each flow is 1 MB by default) |

If you see `status=1` for some flows and `status=0` for others within the same `run_id`, it's per-flow hashing — the ISP routes different TCP 5-tuples through different peering, and one path is bad.

## `mtr/<HHMMSS>-<target>.txt`

Every 2 minutes per target: 50-cycle pathping output. **Read [`INTERPRETING_MTR.md`](./INTERPRETING_MTR.md) before drawing conclusions** — high `Lost/Sent` percentages on intermediate hops are often ICMP rate-limiting artifacts, not real packet loss.

## `iperf/<HHMMSS>.json`

Every 10 minutes: 60-second UDP burst at 80 kbps to iperf.he.net. JSON format from `iperf3 -J`. Provides UDP loss + jitter metrics over a sustained burst (closer to real RTP traffic than ICMP).

## `speedtest/<HHMMSS>.json`

Every 60 minutes: full Ookla speedtest. JSON format from `speedtest -f json`. The most concrete real-world capacity baseline. Server selection auto-picks closest.

Useful fields:
- `download.bandwidth` × 8 / 1e6 = Mbps down
- `upload.bandwidth` × 8 / 1e6 = Mbps up
- `ping.latency` = idle latency in ms
- `ping.jitter` = jitter in ms
- `server.name` + `server.location` = which Ookla server was used (matters — different servers give different numbers)

## `pcap/capture.pcapng`

Continuous single-file packet capture from the Wi-Fi adapter. Opens in Wireshark. Will grow ~1-2 GB/hour. **Contains real DNS queries, TLS SNI, and other browsing artifacts** — don't share publicly without scrubbing.

To convert to a smaller summary: `tshark -r capture.pcapng -q -z io,stat,30,"COUNT(ip) ip"`
