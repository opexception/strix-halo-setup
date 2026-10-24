# ADR 0001: modular Compose, Ollama, LiteLLM, Open WebUI, Caddy

Accepted as **initial experimental design**, not performance winner. Use Ollama ROCm for easiest gfx1151 baseline, LiteLLM for managed OpenAI-compatible API and virtual keys, Open WebUI for interactive chat, PostgreSQL for gateway authentication, and Caddy for HTTPS. Common Compose services + individual port overlays preserve all four deployment options. Later evaluate llama.cpp/vLLM with repeatable metrics, not preference alone. One host = one local configuration / project namespace; fleet orchestration is explicitly deferred.
