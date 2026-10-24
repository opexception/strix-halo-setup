#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
STAGE=1
MODEL=""
while (( $# )); do
  case "$1" in
    --stage) STAGE="$2"; shift 2 ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --help) echo 'Usage: pull-model.sh [--stage 1..4] [--model ollama-tag] [--env-file PATH]'; exit 0 ;;
    *) fail "Unexpected option $1" ;;
  esac
done
need_env; compose_args "$STAGE"
[[ -n "$MODEL" ]] || MODEL="$(conf OLLAMA_MODEL)"
[[ "$MODEL" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./:-]*$ ]] || fail 'Invalid model tag'
"${COMPOSE[@]}" exec -T ollama ollama pull "$MODEL"
log 'If model changed, update both OLLAMA_MODEL and OLLAMA_PROVIDER_MODEL in .env, then redeploy.'
