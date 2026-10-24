# Validation record (fill out per host)

| Parameter | Value |
|---|---|
| Host / model | TBD |
| Ubuntu point release / kernel | TBD |
| ROCm / GPU ID | TBD; expect `gfx1151` |
| BIOS VRAM / TTM cap / free RAM | TBD |
| Image versions + digests | TBD |
| Model / quantization / context | TBD |
| Stage / date / operator | TBD |
| Prefill throughput / decode tokens/s / TTFT | TBD |
| Reliability / GPU-vs-CPU proof | TBD |

## Mandatory tests

```bash
bash -n scripts/*.sh
python3 -m unittest discover -s tests
./scripts/deploy.sh 1 --config
./scripts/deploy.sh 1 --pull
./scripts/pull-model.sh
./scripts/smoke-test.sh 1
```

- **Stage 1:** From a permitted client, `curl http://HOST:11434/api/tags`; generate text; inspect `docker compose logs ollama` for ROCm and `ollama ps` for GPU. Other stages should not be running.
- **Stage 2:** `./scripts/deploy.sh 2`, then `curl -H 'Authorization: Bearer <virtual-key>' http://HOST:4000/v1/models` and `/v1/chat/completions`. Verify direct `HOST:11434` fails.
- **Stage 3:** Generate a separate chat virtual key before deployment. Log into `http://HOST:3000`, verify inference routes through LiteLLM, and direct Ollama access fails.
- **Stage 4:** Confirm `docker compose config --format json` shows **published ports only on caddy**, check `https://API_DOMAIN/v1/models` with API key and `https://CHAT_DOMAIN`, inspect certificate chain, and verify host `4000`, `3000`, `11434`, `5432` cannot be reached directly.

For the first stage 4 rollout: test only from VPN/private LAN with internal CA, then move to public DNS and ACME when authentication, backups, rate limits, and access controls have been reviewed. TLS protects transport; it does not replace authorization.
