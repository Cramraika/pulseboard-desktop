# Interpreting MTR (pathping) output

`pulseboard-desktop` runs `pathping` (Windows built-in) every 2 minutes against each `$Targets` entry, writing output to `mtr/<HHMMSS>-<target>.txt`. This doc explains how to read those files **without drawing wrong conclusions about packet loss**.

## What pathping is

`pathping` is Microsoft's Windows-native traceroute + per-hop ping tool. For each hop along the path to a target, it sends ~50 ICMP probes (configurable; we use 50) and reports two columns:

- **Source-to-Here** loss: `(probes sent to this hop's TTL) - (replies received) / sent`
- **This Node/Link** loss: derived loss attributable to the link from previous hop to this one

A typical output snippet:

```
Tracing route to 14.97.20.3 over a maximum of 20 hops

  0  192.168.1.108
  1  192.168.1.1
  2  203.0.113.249
  3  10.124.251.110
  4     *        *        *

Computing statistics for 7 seconds...
            Source to Here   This Node/Link
Hop  RTT    Lost/Sent = Pct  Lost/Sent = Pct  Address
  0                                           192.168.1.108
                              14/  50 = 28%   |
  1   10ms    14/  50 = 28%    0/  50 =  0%  192.168.1.1
                               0/  50 =  0%   |
  2   10ms    14/  50 = 28%    0/  50 =  0%  203.0.113.249
                              36/  50 = 72%   |
  3  ---      50/  50 =100%    0/  50 =  0%  10.124.251.110

Trace complete.
```

## The naive (wrong) reading

> "72% loss on hop 2 → 3, and hop 3 is 100% unreachable! The link from `203.0.113.249` to `10.124.251.110` is broken!"

This is almost always WRONG. Here's why.

## ICMP rate-limiting is the real story

When pathping wants to measure loss to hop `N`, it sends a probe with TTL=`N+1`. The router at hop `N` is expected to reply with an `ICMP TTL-exceeded` message. pathping counts those replies.

But:

- **Most carrier-grade ISP routers rate-limit `ICMP TTL-exceeded` replies** to ~1 per second per source. With 50 probes in a few seconds, you'll see ~5-10 replies and ~40 "lost" — which pathping reports as 80% loss. **But the original probes weren't lost — only the diagnostic replies were rate-limited.**
- **Many ISP-internal routers don't reply to ICMP TTL-exceeded at all** for security/privacy reasons. They just drop the diagnostic packets. The original probe packets pass through fine; pathping just can't see them.
- **Private-IP intermediate hops (10.x, 172.16.x, 192.168.x) on ISP networks are usually black-holed** for diagnostic purposes. You'll see `* * *` or 100% loss.

In the example above, the 100% "Source to Here" loss at hop 3 (`10.124.251.110`, a private 10.x address) is almost certainly the ISP's internal carrier router refusing to respond to TTL-exceeded probes. The traffic passes through fine — you can confirm this by checking that your `pings.csv` to `14.97.20.3` (the destination) still shows ~0% loss.

## How to actually use pathping output

### Step 1: ignore intermediate hops with private IPs

Hops with addresses in:
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`
- `100.64.0.0/10` (CGNAT)

…are usually carrier-internal routers that don't respond to diagnostic probes. Ignore their loss columns entirely.

### Step 2: look at the FINAL hop (your destination)

The most reliable signal in pathping output is the loss at the final hop (the destination). If your destination is at TTL=N and pathping sees 0/50 loss to it, traffic is reaching the destination cleanly regardless of what intermediate hops report.

Cross-reference with `pings.csv` for the same target — pings.csv uses 20 normal ICMP echo probes that **don't** rely on TTL-exceeded responses, so its loss numbers are authoritative.

### Step 3: cross-validate with TCP

If you suspect ICMP loss is real (not a measurement artifact), check `tcp.csv` for the same target. If TCP 443 / TCP 5060 connects succeed at 100%, ICMP loss is almost certainly a measurement artifact, not a real network problem.

### Step 4: when intermediate-hop loss IS meaningful

Two cases where pathping's intermediate-hop loss is genuinely informative:

**a) Public-IP intermediate hops with high RTT inflation.**

If hop 5 has RTT=120ms and hop 6 has RTT=350ms, but the destination at hop 8 has RTT=350ms — somewhere between hop 5 and hop 6 there's a real congestion point or a long submarine cable hop. Even if loss numbers are noisy, the RTT inflation is real (the actual measured RTT is honest).

**b) Consistent, repeated loss on the SAME hop across multiple pathping runs at different times.**

A single run showing 60% loss on hop 7 is noise. Twelve consecutive runs at 2-min intervals all showing 60% loss on hop 7? Probably real. (Or, hop 7's router has a permanent ICMP rate-limit policy. Hard to tell without other evidence.)

## Cross-tool diagnosis pattern

The diagnostic value of `mtr/*.txt` is **lower** than:

- `pings.csv` — authoritative loss to the destination (uses normal ICMP echo, not TTL-exceeded)
- `iperf/*.json` — authoritative UDP loss + jitter over a sustained burst
- `parallel_flows.csv` — concrete TCP success/fail per flow
- `pcap/capture.pcapng` — every packet, authoritative

Use pathping output for:

1. **Identifying the AS path** — read off the public IPs at each hop and look up the AS owner via `whois <hop-ip>` to see which networks your traffic crosses
2. **Flagging consistent big-RTT-jumps** between hops — a real congestion point will show up as a hop where RTT increases substantially
3. **Confirming the route is reasonably symmetric** — major route changes between two adjacent runs suggest BGP flapping

Don't use pathping output for:

1. Quoting "X% packet loss on the ISP's network" to an ISP support ticket — they'll point at the ICMP rate-limiting and dismiss it
2. Comparing two runs' loss numbers at intermediate hops directly (the noise floor is too high)

## When to escalate

When you have **all three** of:

1. `pings.csv` showing destination loss > 5% over multiple consecutive 1-min windows
2. `tcp.csv` showing TCP 443 connect failures or > 100ms connect time at the same time
3. `pathping/*.txt` from several runs all consistently showing high loss + RTT-inflation at the same intermediate public-IP hop

…you have evidence good enough to file with your ISP. Attach all three CSVs + 3 representative pathping files. Cite the timestamps.

If you only have intermediate-hop loss in pathping but NO loss in pings.csv, you don't have a real problem — you have measurement noise. Don't escalate; the ISP will brush it off and rightly so.

## Why we use pathping, not WinMTR

Earlier versions of this script tried WinMTR. Two problems:

1. WinMTR's `--report` flag doesn't reliably redirect output (it spawns GUI tabs)
2. The current WinMTR fork is unmaintained

`pathping` is built into every Windows install, runs reliably, and produces stdout we can capture. The trade-off: pathping is slower (a 50-cycle run takes ~50 seconds vs WinMTR's parallel ~10 seconds). For per-2-minute capture, that's fine.
