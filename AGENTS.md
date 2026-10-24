# Agent instructions

## Mission
Create a reproducible, maintainable Ubuntu 24.04 deployment for Ryzen AI Max+ 395 (gfx1151, 128 GB shared RAM). Preserve all four stage selections; never replace earlier stages while implementing a later one.

## Working agreement
1. Read `README.md`, `docs/roadmap.md`, `docs/architecture.md`, `docs/security.md`, and the relevant `prompts/` file before changing code.
2. Do **one stage/acceptance gate at a time**. Preserve shared Compose components, and use stage overlays only for published ports.
3. Prioritize empirical validation on target hardware. Never invent tokens/s, device memory, kernel compatibility, or Docker image tags. Keep records of OS patch level, kernel, BIOS, ROCm, model/quant, image digest, context, throughput, and faults.
4. Do not use floating tags for LiteLLM. **2026-10-21 LiteLLM supply-chain incident:** affected v1.107.0 and floating tags; verify digest/provenance before upgrades. See `docs/security.md`.
5. Use official vendor instructions for ROCm compatibility. For Ryzen APUs use inbox kernel driver and `--no-dkms` where that AMD install path specifies it. Never silently change kernel, BIOS memory setting, TTM cap, routing, or firewall.
6. Secrets are local, `.env`-based in prototype; do not commit, print, log, or embed real credentials. Progress toward Docker secrets / external secret store before production. LiteLLM master key is **not** a user/chat key.
7. Stage 4 must publish only proxy ports; never bypass gateway from Open WebUI, and never publish Ollama, PostgreSQL, LiteLLM, or Open WebUI directly.
8. Use versioned changes, tests, rollback notes, and short docs. Keep user-facing explanations concise except important risks.
9. Before modifying images/dependencies, check current upstream documentation and security advisories. Require approval for host changes or exposure expansion.
10. End every task with: changed files, verification run, limitations, how to test on host, and next prompt.

## Definition of done for each milestone
- `bash -n scripts/*.sh` passes and `python3 -m unittest discover -s tests` passes.
- `./scripts/deploy.sh N --config` validates on Docker host; no unintended published ports.
- Runtime smoke test passes; GPU acceleration is confirmed (not CPU fallback).
- Host-specific reproducibility steps and backout documented briefly; previous stages remain selectable.
