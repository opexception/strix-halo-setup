# Exposure and supply-chain policy

**Critical: October 21, 2026 LiteLLM compromise.** Version **1.107.0** and mutable release tags (`latest`, `main-latest`, `main-stable`) were affected during an attacker-controlled publication window. Official remediation recommends **1.106.2** or a verified earlier version pending further updates. This repo initially selects `v1.106.2`; validate that the registry image exists, inspect provenance, and **pin its verified image digest** before any internet exposure. Do not run `docker compose pull` on unreviewed tags. Source: [LiteLLM incident advisory](https://docs.litellm.ai/blog/security-incident-oct-21-2026).

1. Only Caddy ports `80/443` may be published in stage 4. No separate LiteLLM port is required: the API is proxied via `https://API_DOMAIN/v1`.
2. Caddy TLS public mode needs real DNS pointing to the workstation and valid ACME challenge access. Internal mode uses `tls internal` and requires **explicit CA root trust** on clients. Don't disable TLS validation.
3. LiteLLM API keys required. **Never hand the master key to clients or Open WebUI.** Use a distinct, limited virtual key; later add identity/SSO, per-client budgets and quotas.
4. Open WebUI admin account is provisioned on a fresh DB using `.env` credentials; signup is disabled. Back up the DB and rotate bootstrap credentials after setup. Test fresh-first-boot behavior on each pinned image.
5. `.env` contains secrets (including irrevocable LiteLLM salt) and must stay mode `0600` and outside Git. Compose environment secrets may be visible to Docker administrators; move to secret store / file-based secrets for production.
6. Ollama has no native auth. No direct exposure to internet, even for stage 1. Restrict LAN/VPN reachability in network firewall/router. Docker's port publishing may bypass host UFW rules.
7. No automatic model downloads, third-party bootstrap pipes, blanket host firewall resets, `privileged: true`, or uncontrolled image upgrades.
8. Audit access logs, backups, key rotation, and public-hardening (rate limits, updates, allowlists, SSO) before internet-facing production use.

The October 21 incident is unusually recent relative to this starter. Re-check upstream security advisories before using even the pinned release, particularly if the device is externally reachable.
