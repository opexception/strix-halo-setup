# Strix Halo AI Workstation

Git-ready starter for repeatable **AMD Ryzen AI Max+ 395 / 128 GB** deployments on **Ubuntu 24.04**. Four independent, cumulative Docker Compose stages:

| Stage | Containers | Published endpoints |
|---|---|---|
| 1 | Ollama/ROCm | Ollama `11434` |
| 2 | Ollama + LiteLLM + PostgreSQL | LiteLLM `4000` |
| 3 | Stage 2 + Open WebUI | LiteLLM `4000`, chat `3000` |
| 4 | Stage 3 + Caddy | Caddy `80/443` **only** |

All other services are reachable **only on the Compose network**. By default, stages 1–3 bind to `127.0.0.1`; to serve trusted LAN/VPN clients, configure a private `PUBLIC_BIND_IP`. Never expose stages 1–3 directly to the public internet. Stage 4 supports public ACME TLS or Caddy's internal CA for private networks.

## Quick start

```bash
# On Ubuntu host: review available flags; reboot between kernel/ROCm steps when instructed.
sudo ./scripts/bootstrap.sh --help
sudo ./scripts/bootstrap.sh --hostname halo-01 --docker-user "$USER"
# Optional (after compatibility review): install kernel or ROCm; see docs/bootstrap.md.

# After host is ready, and after reconnecting if group membership changed:
./scripts/init-config.sh
./scripts/deploy.sh 1 --pull
./scripts/pull-model.sh
./scripts/smoke-test.sh 1

# Promote after stage 1 passes:
./scripts/deploy.sh 2 --pull
./scripts/create-virtual-key.sh --for-webui
./scripts/deploy.sh 3 --pull
./scripts/deploy.sh 4 --pull  # first configure DNS, TLS, domains in .env
```

Use `./scripts/deploy.sh N --config` to view the rendered Compose configuration; `./scripts/deploy.sh N --down` stops that stage **without deleting volumes**. Switching stages reuses persistent volumes. `./scripts/deploy.sh N --pull` pulls images first (do not do this blindly after release incidents).

For each host, copy this repo, run `init-config.sh` locally, and choose the desired stage. Use a unique `COMPOSE_PROJECT_NAME` when running multiple installations on one host. To initialize Git in an unpacked starter: `git init && git add . && git commit -m "Initial Strix Halo AI workstation scaffold"`.

## Start here

- [`AGENTS.md`](AGENTS.md): coding-assistant contracts, priorities, definition of done.
- [`prompts/`](prompts/): sequential human-to-agent prompts, one milestone per prompt.
- [`docs/architecture.md`](docs/architecture.md): networking and stage boundaries.
- [`docs/bootstrap.md`](docs/bootstrap.md): kernel, ROCm, GPU and shared memory decisions.
- [`docs/security.md`](docs/security.md): required before publishing endpoints.
- [`docs/roadmap.md`](docs/roadmap.md): current status and validation gates.

**Starter, not a hardware-certified release:** Compose structure, scripts, and configuration can be checked offline; GPU inference, real image availability, TLS/ACME, and performance must be tested on the actual Strix Halo machines and recorded. No credentials, host addresses, or certificates belong in Git.
