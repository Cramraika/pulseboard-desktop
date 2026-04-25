---
name: VoIP provider profile request
about: Ask for a pre-written `config.ps1` snippet for your VoIP / SIP provider so others can run pulseboard-desktop against it without manual research.
title: "Provider profile: <provider name>"
labels: provider-profile
assignees: ''
---

## Provider details

- **Name**: (e.g. Twilio Programmable Voice, RingCentral, 8x8, Dialpad, Zoiper, Asterisk-via-3CX, FreePBX, Smartflo / TTBS, Vonage Business, Microsoft Teams direct routing, etc.)
- **Public-facing media/signalling IP range** (if known): (e.g. `14.97.20.0/24`, `54.172.60.0/23`, single IP, etc.)
- **SIP signalling port + transport**: (default UDP 5060, TLS 5061, etc.)
- **RTP port range**: (default 10000-20000, 16384-32767, etc.)
- **Where you found this info**: (provider docs URL or support-ticket excerpt — helpful so we can keep the snippet up-to-date)

## What you've tried

- [ ] I've already added a `$Targets` block to my local `config.ps1` and it works
- [ ] I haven't been able to figure out the right IPs/ports myself
- [ ] My provider's docs were unhelpful

## Outcome

Once accepted, this provider's snippet will be added to `docs/VOIP_PROVIDERS.md` so anyone running pulseboard-desktop against this provider can copy-paste it into their `config.ps1`.
