# Upstream references (checked 2026-10-24)

- [AMD Ryzen ROCm install](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/native_linux/install-ryzen.html) — OEM kernel, no-DKMS installation, `amd-ttm` guidance.
- [AMD Strix Halo optimization](https://rocm.docs.amd.com/en/docs-7.2.0/how-to/system-optimization/strixhalo.html) — kernel support caveats; always check latest version.
- [Ollama Linux AMD GPU](https://github.com/ollama/ollama/blob/main/docs/gpu.mdx) and [Ollama Docker](https://github.com/ollama/ollama/blob/main/docs/docker.mdx) — gfx1151/ROCm and device passthrough.
- [LiteLLM October 21, 2026 incident](https://docs.litellm.ai/blog/security-incident-oct-21-2026) — v1.107.0 compromise, guidance to pin pre-incident release.
- [LiteLLM deployment](https://docs.litellm.ai/docs/proxy/docker_quick_start) — gateway, keys, PostgreSQL.
- [Open WebUI environment](https://docs.openwebui.com/reference/env-configuration/) and [hardening](https://docs.openwebui.com/getting-started/advanced-topics/hardening/) — external OpenAI-compatible API, first-run admin, signup.
- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) — official apt repository.
- [Caddy HTTPS](https://caddyserver.com/docs/automatic-https) — public ACME / internal issuer.

Source URLs are documentation snapshots/entry points, **not an endorsement of unpinned upstream downloads**. Agent should verify current release and image digest before updating the stack.
