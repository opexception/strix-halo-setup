# Architecture

```text
Stage 1: Client --[trusted LAN/VPN only]--> Ollama:11434
Stage 2: Client --[trusted LAN/VPN only]--> LiteLLM:4000 --> Ollama
Stage 3: Client --[trusted LAN/VPN only]--> LiteLLM:4000 --> Ollama
         Browser --[trusted LAN/VPN only]--> Open WebUI:3000 --> LiteLLM
Stage 4: Clients -- HTTPS --> Caddy:443 --> LiteLLM / Open WebUI
                                             \--> Ollama
                         PostgreSQL (LiteLLM keys; internal only)
```

Only stage overlays publish host ports. `compose/components/*.yml` hold stable services and named volumes. Stage 4 hosts API and UI on **separate FQDNs** through the same Caddy container. **API proxying is appropriate**: LiteLLM supports HTTPS reverse proxies; retain end-to-end API key authentication and do not publish the backend directly. Caddy handles WebSocket upgrade for chat. No distributed orchestration is included: choose a stage **per machine** by running the same repo with machine-local `.env` and volumes.

Stage 1's Ollama API has no built-in authentication; its default bind is loopback. Stages 2–3 also default to loopback for secure local testing. Access remotely over SSH forwarding, VPN, or set `PUBLIC_BIND_IP` to a restricted private interface with strict network firewall rules. Docker published ports may bypass UFW expectations: verify actual reachability separately.

## Model and data

- Default smoke-test model: `llama3.2:3b` (small, not a performance recommendation).
- Set both `OLLAMA_MODEL` and `OLLAMA_PROVIDER_MODEL=ollama_chat/<same-model>`.
- Name shown to clients: `LITELLM_MODEL_NAME` (default `local-default`).
- Volumes: model store, LiteLLM PostgreSQL, Open WebUI state, Caddy certs. Preserve these on upgrades.
- Runtime choice is deliberately swappable; benchmark Ollama/ROCm before introducing llama.cpp, vLLM, or Vulkan profiles.
