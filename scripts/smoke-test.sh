#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
[[ $# -ge 1 ]] || fail 'Usage: smoke-test.sh STAGE [--env-file PATH]'
STAGE="$1"; shift
if [[ ${1:-} == --env-file ]]; then ENV_FILE="${2:?missing file}"; shift 2; fi
[[ $# == 0 ]] || fail 'Unexpected args'
need_env; compose_args "$STAGE"
"${COMPOSE[@]}" ps
"${COMPOSE[@]}" exec -T ollama ollama list
"${COMPOSE[@]}" exec -T ollama ollama show "$(conf OLLAMA_MODEL)" >/dev/null || fail "Model missing. Run ./scripts/pull-model.sh first"
log 'Checking generation via Ollama internal API (may take time for initial model load)...'
"${COMPOSE[@]}" exec -T ollama ollama run "$(conf OLLAMA_MODEL)" 'Reply with the single word READY.'
if (( STAGE >= 2 )); then
  log 'Checking LiteLLM internal health and model listing...'
  "${COMPOSE[@]}" exec -T litellm python -c '
import json, os, urllib.request
r=urllib.request.Request("http://127.0.0.1:4000/v1/models", headers={"Authorization":"Bearer "+os.environ["LITELLM_MASTER_KEY"]})
with urllib.request.urlopen(r, timeout=30) as f:
    x=json.load(f)
assert x.get("data"), x
print("LiteLLM model IDs:", [m.get("id") for m in x["data"]])
'
fi
log "Smoke checks completed for stage $STAGE. Confirm ROCm backend in Ollama logs and run remote/API/TLS tests in docs/validation.md."
