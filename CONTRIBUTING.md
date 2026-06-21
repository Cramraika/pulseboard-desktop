# Contributing to pulseboard-desktop

Thanks for your interest! pulseboard-desktop is free, MIT-licensed OSS and contributions are welcome.

## How to contribute

1. **Open an issue first** for anything non-trivial (new probe, VoIP-provider profile, behavior
   change) so we can agree on the approach before you invest time.
2. **Fork, branch, PR.** Keep one logical change per PR.
3. **PowerShell lint must be green.** CI runs
   `Invoke-ScriptAnalyzer -Path . -Recurse -Severity @('Error','Warning')` on every PR — run it
   locally before pushing.
4. **ASCII-only `*.ps1`.** A CI gate rejects non-ASCII characters in PowerShell scripts.
5. **No telemetry, no network calls home.** This tool is local-only by design; PRs that add
   outbound reporting will be declined.

## Good first contributions

- New VoIP-provider profiles in `docs/VOIP_PROVIDERS.md` (use the provider-profile issue template).
- Additional probe targets or DNS resolvers.
- Documentation fixes.

## License

By contributing, you agree your contributions are licensed under the project's
[MIT License](./LICENSE).

## Support

If this tool helps you, see the [Support / Sponsor](./README.md#-sponsor-this-project) section —
sponsorships fund the roadmap (Linux/Mac ports, GUI wrapper, analysis notebook).
