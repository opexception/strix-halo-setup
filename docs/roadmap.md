# Roadmap and acceptance gates

| Gate | Deliverable | Pass condition | State |
|---|---|---|---|
| 0 | Host bootstrap | Ubuntu 24.04, valid kernel/ROCm pair, `rocminfo` gfx1151, correct TTM and Docker | **Implementation scaffold** |
| 1 | Ollama | API model list and completion from permitted remote client; measured GPU use | **Compose scaffold** |
| 2 | LiteLLM | authenticated `/v1/models`, completion through gateway; Ollama unpublished | **Compose scaffold** |
| 3 | Open WebUI | successful logged-in chat with LiteLLM virtual key, gateway still sole inference API | **Compose scaffold** |
| 4 | Caddy | valid TLS to both FQDNs; only 80/443 published; API and UI usable remotely | **Compose scaffold** |
| 5 | Productize | pinned image digests, backup/restore, rollback, provisioning, tuning and benchmark matrix | Planned |

A scaffold is **not** a recorded hardware test. Track tested combinations under `docs/validation.md`; do not change gate status without evidence.

Suggested next work: pin digest for LiteLLM pre-incident release, smoke-test stage 1 on gfx1151, then move gate-by-gate. Avoid premature multi-host management and performance tuning until single-host repeatability is proven.
