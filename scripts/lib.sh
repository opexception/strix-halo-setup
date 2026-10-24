#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*" >&2; }
need_env() { [[ -f "$ENV_FILE" ]] || fail "Missing $ENV_FILE. Run ./scripts/init-config.sh"; }
# Limited .env reader for this project's simple one-line KEY=VALUE settings.
conf() {
  local key="$1" default="${2:-}" val
  val="$(grep -m1 -E "^${key}=" "$ENV_FILE" 2>/dev/null || true)"
  [[ -n "$val" ]] && printf '%s' "${val#*=}" || printf '%s' "$default"
}
compose_args() {
  local stage="$1"
  [[ "$stage" =~ ^[1-4]$ ]] || fail "Stage must be 1, 2, 3, or 4"
  COMPOSE=(docker compose --project-directory "$PROJECT_ROOT" --env-file "$ENV_FILE"
    -f "$PROJECT_ROOT/compose/components/ollama.yml")
  if (( stage >= 2 )); then
    COMPOSE+=(-f "$PROJECT_ROOT/compose/components/gateway.yml")
  fi
  if (( stage >= 3 )); then
    COMPOSE+=(-f "$PROJECT_ROOT/compose/components/chat.yml")
  fi
  if (( stage >= 4 )); then
    COMPOSE+=(-f "$PROJECT_ROOT/compose/components/proxy.yml")
  fi
  COMPOSE+=(-f "$PROJECT_ROOT/compose/stages/$stage.yml")
}
check_security() {
  local stage="$1" lite master salt pg webpw webkey image
  if ((stage >= 2)); then
    lite="$(conf LITELLM_IMAGE)"
    [[ "$lite" =~ ^[^[:space:]]+:(v[0-9]+\.[0-9]+\.[0-9]+)$ || "$lite" =~ @sha256:[a-fA-F0-9]{64}$ ]] || fail "LiteLLM must have an explicit version or immutable digest; not :latest / :main-stable"
    [[ "$lite" != *':v1.107.0' ]] || fail "LiteLLM v1.107.0 was compromised; see docs/security.md"
    master="$(conf LITELLM_MASTER_KEY)"
    salt="$(conf LITELLM_SALT_KEY)"
    pg="$(conf POSTGRES_PASSWORD)"
    [[ "$master" == sk-* && ${#master} -ge 24 && "$master" != *REPLACE* ]] || fail 'Generate a strong LiteLLM master key using init-config.sh'
    [[ "$salt" == sk-* && ${#salt} -ge 24 && "$salt" != *REPLACE* ]] || fail 'Generate a strong LiteLLM salt using init-config.sh'
    [[ ${#pg} -ge 24 && "$pg" != *REPLACE* ]] || fail 'Generate a strong PostgreSQL password using init-config.sh'
  fi
  if ((stage >= 3)); then
    webkey="$(conf OPENWEBUI_API_KEY)"
    webpw="$(conf WEBUI_ADMIN_PASSWORD)"
    [[ "$webkey" == sk-* && "$webkey" != "$(conf LITELLM_MASTER_KEY)" && "$webkey" != *REPLACE* ]] || fail 'Stage 3/4 requires a separate LiteLLM virtual key. Run create-virtual-key.sh --for-webui'
    [[ ${#webpw} -ge 24 && "$webpw" != *REPLACE* ]] || fail 'Generate an Open WebUI admin password using init-config.sh'
  fi
  if ((stage == 4)); then
    [[ "$(conf API_DOMAIN)" != *example.invalid* && "$(conf CHAT_DOMAIN)" != *example.invalid* ]] || fail 'Set real API_DOMAIN and CHAT_DOMAIN before stage 4'
    [[ "$(conf API_DOMAIN)" != "$(conf CHAT_DOMAIN)" ]] || fail 'API_DOMAIN and CHAT_DOMAIN must differ'
    image="$(conf CADDYFILE_PATH)"
    [[ "$image" == './config/caddy/Caddyfile.public' || "$image" == './config/caddy/Caddyfile.internal' ]] || fail 'CADDYFILE_PATH must select one of the included vetted Caddyfiles'
  fi
}
