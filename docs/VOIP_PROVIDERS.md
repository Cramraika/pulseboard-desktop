# VoIP provider profiles

Pre-written `config.ps1` snippets for common SIP / VoIP providers. Copy the relevant block into your `config.ps1`. Each entry has `$Targets` (for ICMP + TCP probes), `$SipTarget` (for the per-tick SIP OPTIONS probe), and `$PortGrid` (for periodic port-reachability probes).

If your provider isn't covered, please [file a `Provider profile request` issue](https://github.com/Cramraika/pulseboard-desktop/issues/new?template=voip-provider-request.md). The template asks for the IP ranges and ports you've been told to whitelist; once you provide those, we add a snippet here so the next person doesn't have to research it.

> **All snippets use placeholder IPs from each provider's published documentation.** IPs change. Verify against your provider's current docs before relying on them.

---

## Tata Smartflo / TTBS (India business voice)

Provider docs: TTBS publishes a media/signalling whitelist via support tickets.

```powershell
# Tata Smartflo / TTBS — confirmed media/signalling endpoints
# Whitelist subnet: 14.97.20.0/24
# RTP port range: UDP 20000-40000
# SIP signalling: UDP 5060

$Targets += @(
  @{ Name="ttbs_smartflo_3";  Ip="14.97.20.3";  Port=5060 },
  @{ Name="ttbs_smartflo_2";  Ip="14.97.20.2";  Port=5060 },
  @{ Name="ttbs_smartflo_10"; Ip="14.97.20.10"; Port=5060 },
  @{ Name="ttbs_smartflo_11"; Ip="14.97.20.11"; Port=5060 }
)

$SipTarget = @{ Host="14.97.20.3"; Port=5060 }

$PortGrid += @(
  @{ host="14.97.20.3"; port=5060;  proto="tcp"; label="ttbs_SIP_TCP"   },
  @{ host="14.97.20.3"; port=5061;  proto="tcp"; label="ttbs_SIP_TLS"   },
  # RTP range probes — confirms firewall doesn't block the high-port UDP range
  @{ host="14.97.20.3"; port=20000; proto="tcp"; label="ttbs_RTP_lo"    },
  @{ host="14.97.20.3"; port=30000; proto="tcp"; label="ttbs_RTP_mid"   },
  @{ host="14.97.20.3"; port=40000; proto="tcp"; label="ttbs_RTP_hi"    }
)
```

---

## Twilio Programmable Voice

Twilio publishes IP ranges per region. Pick the closest:
https://www.twilio.com/docs/voice/sip/ip-addresses

```powershell
# Twilio Programmable Voice — pick the region closest to your office
# US East (Ashburn): 54.172.60.0/30 (and a few others)
# US West (Oregon):  54.244.51.0/30
# EU (Dublin):       54.171.127.192/30
# AP-SE (Singapore): 54.169.127.128/30
# AP-NE (Tokyo):     54.65.63.192/30
# SA (Sao Paulo):    177.71.206.192/30
# AU (Sydney):       54.252.254.64/30

$Targets += @(
  @{ Name="twilio_us_east"; Ip="54.172.60.1"; Port=5060 }
)

$SipTarget = @{ Host="54.172.60.1"; Port=5060 }

$PortGrid += @(
  @{ host="54.172.60.1"; port=5060; proto="tcp"; label="twilio_SIP_TCP" },
  @{ host="54.172.60.1"; port=5061; proto="tcp"; label="twilio_SIP_TLS" }
)
```

---

## RingCentral

RingCentral publishes ranges per data centre:
https://support.ringcentral.com/article-v2/Network-requirements.html

```powershell
# RingCentral — primary US data centre IP range examples
# Confirm your account's specific data centre with RingCentral support before relying on these.
$Targets += @(
  @{ Name="ringcentral_dc1"; Ip="199.255.120.1"; Port=5090 }
)

# RingCentral signalling: TCP/UDP 5090 (NOT the standard 5060)
$SipTarget = @{ Host="199.255.120.1"; Port=5090 }

$PortGrid += @(
  @{ host="199.255.120.1"; port=5090; proto="tcp"; label="ringcentral_SIP" },
  @{ host="199.255.120.1"; port=5091; proto="tcp"; label="ringcentral_SIP_TLS" }
)
```

---

## 3CX (hosted)

If you're on 3CX-hosted, your tenant's specific FQDN/IP is in your 3CX console under **Dashboard → FQDN**.

```powershell
# 3CX hosted — replace with your tenant's IP/FQDN
# 3CX uses random ports for SIP (configurable in 3CX admin):
#   default SIP UDP/TCP: 5060 (sometimes 5090)
#   default RTP UDP range: 9000-10999
# Check your specific tenant's "Network Configuration" page for actual values.

$Targets += @(
  @{ Name="my_3cx";      Ip="<your-tenant-ip>"; Port=5060 }
)

$SipTarget = @{ Host="<your-tenant-ip>"; Port=5060 }

$PortGrid += @(
  @{ host="<your-tenant-ip>"; port=5060;  proto="tcp"; label="3cx_SIP_TCP" },
  @{ host="<your-tenant-ip>"; port=5061;  proto="tcp"; label="3cx_SIP_TLS" },
  @{ host="<your-tenant-ip>"; port=5090;  proto="tcp"; label="3cx_SIP_alt" },
  @{ host="<your-tenant-ip>"; port=9000;  proto="tcp"; label="3cx_RTP_lo"  },
  @{ host="<your-tenant-ip>"; port=10999; proto="tcp"; label="3cx_RTP_hi"  }
)
```

---

## Asterisk / FreePBX (self-hosted)

If you're running your own Asterisk or FreePBX, you know the IP. Default ports below.

```powershell
# Asterisk / FreePBX self-hosted — defaults
$Targets += @(
  @{ Name="my_asterisk"; Ip="<your-pbx-ip>"; Port=5060 }
)

$SipTarget = @{ Host="<your-pbx-ip>"; Port=5060 }

$PortGrid += @(
  @{ host="<your-pbx-ip>"; port=5060;  proto="tcp"; label="asterisk_SIP_TCP" },
  @{ host="<your-pbx-ip>"; port=5061;  proto="tcp"; label="asterisk_SIP_TLS" },
  @{ host="<your-pbx-ip>"; port=8089;  proto="tcp"; label="asterisk_WebRTC"  },
  # Default Asterisk RTP range:
  @{ host="<your-pbx-ip>"; port=10000; proto="tcp"; label="asterisk_RTP_lo"  },
  @{ host="<your-pbx-ip>"; port=20000; proto="tcp"; label="asterisk_RTP_hi"  }
)
```

---

## Zoom Phone

Zoom publishes ranges via their docs portal:
https://support.zoom.us/hc/en-us/articles/201362683

```powershell
# Zoom Phone uses regional points; pick the IP for your nearest data centre
# from Zoom's published list. Replace the placeholder below.
$Targets += @(
  @{ Name="zoom_phone"; Ip="<zoom-regional-ip>"; Port=5060 }
)

$SipTarget = @{ Host="<zoom-regional-ip>"; Port=5060 }
```

---

## Vonage Business

Per Vonage support docs.

```powershell
$Targets += @(
  @{ Name="vonage"; Ip="<vonage-regional-ip>"; Port=5060 }
)

$SipTarget = @{ Host="<vonage-regional-ip>"; Port=5060 }
```

---

## Microsoft Teams direct routing

Teams uses a published range for SBA/SBC media:
https://learn.microsoft.com/microsoftteams/direct-routing-plan

```powershell
# Teams direct routing — your SBC's IP, NOT Microsoft's
$Targets += @(
  @{ Name="teams_sbc"; Ip="<your-sbc-ip>"; Port=5061 }   # Teams direct routing requires TLS, port 5061
)

$SipTarget = @{ Host="<your-sbc-ip>"; Port=5061 }

$PortGrid += @(
  @{ host="<your-sbc-ip>"; port=5061;  proto="tcp"; label="teams_SIP_TLS" },
  # Teams media UDP range (configurable on the SBC; defaults vary):
  @{ host="<your-sbc-ip>"; port=49152; proto="tcp"; label="teams_RTP_lo"  },
  @{ host="<your-sbc-ip>"; port=53247; proto="tcp"; label="teams_RTP_hi"  }
)
```

---

## Generic SIP trunking provider (when no specific snippet exists)

```powershell
# Generic SIP provider — replace IPs and ports per your provider's docs
$Targets += @(
  @{ Name="my_sip_primary";   Ip="<primary-sbc-ip>";   Port=5060 },
  @{ Name="my_sip_secondary"; Ip="<secondary-sbc-ip>"; Port=5060 }
)

$SipTarget = @{ Host="<primary-sbc-ip>"; Port=5060 }

$PortGrid += @(
  @{ host="<primary-sbc-ip>"; port=5060; proto="tcp"; label="sip_TCP"     },
  @{ host="<primary-sbc-ip>"; port=5061; proto="tcp"; label="sip_TLS"     },
  # Replace 10000/20000 with your provider's documented RTP range
  @{ host="<primary-sbc-ip>"; port=10000; proto="tcp"; label="rtp_lo"     },
  @{ host="<primary-sbc-ip>"; port=20000; proto="tcp"; label="rtp_hi"     }
)
```

---

## How to verify a snippet works

After editing `config.ps1`, run a smoke test:

```powershell
.\diag.ps1 -PreflightOnly -Tag smoke
```

Open `PREFLIGHT.txt` and look for rows mentioning your new target names. Expectations:

- ICMP `PASS` — many SBCs answer ICMP. Some don't (and DEGR/FAIL is fine).
- TCP `PASS` on at least port 5060 OR 5061 OR 443 — at least one of these should connect; if all fail, your network can't reach the SBC at all.
- SIP OPTIONS probably DEGR — most SBCs ignore anonymous OPTIONS. Not a blocker.
- Port-grid: depends on which ports your provider has configured. RTP-range probes often FAIL on TCP because the range is UDP-only — that's expected.

If something is genuinely broken (all probes FAIL on a target you're sure should work), check:

1. Is your VPN / firewall blocking outbound to that IP?
2. Did you typo the IP?
3. Has the provider rotated their IPs since the snippet was written? Check provider docs.
