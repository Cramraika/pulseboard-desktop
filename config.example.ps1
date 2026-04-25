# pulseboard-desktop user config
# ------------------------------------------------------------------------
# Copy this file to `config.ps1` (same directory as diag.ps1) and edit.
# diag.ps1 dot-sources `config.ps1` automatically if present, so any variable
# you set here OVERRIDES the script's defaults.
#
# All variables are optional. Leave a section commented out to keep the
# corresponding default. See docs/VOIP_PROVIDERS.md for ready-made snippets
# for common SIP/VoIP providers.
# ------------------------------------------------------------------------


# ---- Add your VoIP SBC / SIP gateway as a tracked target ------------------
# Example: a generic SIP provider on a single IP. Each entry adds a per-tick
# ICMP + TCP probe to that endpoint. Buffer size scales automatically.
#
# $Targets += @(
#   @{ Name="my_sbc";        Ip="203.0.113.10"; Port=5060 },
#   @{ Name="my_sbc_backup"; Ip="203.0.113.11"; Port=5060 }
# )
#
# Pre-written snippets for common providers (uncomment ONE that matches
# your provider) -- see docs/VOIP_PROVIDERS.md for sourcing notes:
#
# # Tata Smartflo / TTBS  (whitelist subnet 14.97.20.0/24, RTP UDP 20000-40000)
# $Targets += @(
#   @{ Name="ttbs_smartflo_3"; Ip="14.97.20.3";  Port=5060 },
#   @{ Name="ttbs_smartflo_2"; Ip="14.97.20.2";  Port=5060 }
# )
#
# # Twilio Programmable Voice (US East)
# $Targets += @(
#   @{ Name="twilio_us_east"; Ip="54.172.60.0";  Port=5060 }
# )
#
# # 3CX Hosted (replace with your tenant's IP)
# $Targets += @(
#   @{ Name="my_3cx";         Ip="<your-tenant-ip>"; Port=5060 }
# )


# ---- SIP signalling probe -------------------------------------------------
# Enables a per-tick raw SIP OPTIONS datagram against your SBC. Many SBCs
# silently ignore anonymous OPTIONS - that's normal; the value here is in
# spotting moments when even your local network can't reach UDP 5060
# outbound (firewall change, ISP shaping).
#
# $SipTarget = @{ Host="203.0.113.10"; Port=5060 }


# ---- Add VoIP-specific port-grid probes -----------------------------------
# Useful for confirming whether the various ports your SBC uses are reachable
# at all from this Wi-Fi - distinguishes "ISP blocks UDP 5060" from "SBC is
# down" from "Wi-Fi is fine but firewall is shaping".
#
# $PortGrid += @(
#   @{ host="203.0.113.10"; port=5060;  proto="tcp"; label="my_sbc_SIP_TCP"  },
#   @{ host="203.0.113.10"; port=5061;  proto="tcp"; label="my_sbc_SIP_TLS"  },
#   @{ host="203.0.113.10"; port=443;   proto="tcp"; label="my_sbc_HTTPS"    },
#   # If your provider uses a documented RTP port range (e.g. 20000-40000),
#   # probe its endpoints to see if the firewall blocks the range:
#   @{ host="203.0.113.10"; port=20000; proto="tcp"; label="my_sbc_RTP_lo"   },
#   @{ host="203.0.113.10"; port=30000; proto="tcp"; label="my_sbc_RTP_mid"  },
#   @{ host="203.0.113.10"; port=40000; proto="tcp"; label="my_sbc_RTP_hi"   }
# )


# ---- Add provider-relevant DNS names + TLS hosts --------------------------
# If your SBC has a hostname (e.g. for SRV-record SIP discovery), adding it
# here lets dns.csv and tls_cert.csv track its resolution + cert issuer
# alongside the generic controls.
#
# $DnsNames += @("sip.my-provider.com", "rtp.my-provider.com")
# $TlsHosts += @("portal.my-provider.com")


# ---- Override anycast pairs for a different control set -------------------
# By default we compare Cloudflare and Google's resolver-anycast (1.1.1.1,
# 8.8.8.8) against their CDN-anycast (104.16.x, 142.250.x). If you operate
# in a region where those defaults don't reach a local PoP cleanly, swap
# them for IPs you've confirmed land at your nearest PoP.
#
# $AnycastPairs = @(
#   @{ a="1.1.1.1"; b="1.0.0.1"; name="cloudflare_dns_anycast" },
#   @{ a="8.8.8.8"; b="8.8.4.4"; name="google_dns_anycast" }
# )


# ---- Tuning knobs ---------------------------------------------------------
# These already have sensible defaults in diag.ps1 - only override if you
# know you need a different cadence.
#
# $script:speedEvery = 60   # speedtest every N ticks. Default 60 (=1 hr).
# $script:mtrEvery   = 2    # MTR every N ticks. Default 2 (=2 min).


# End of config.ps1
