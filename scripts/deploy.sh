#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
usage() {
  cat <<'TXT'
Usage: ./scripts/deploy.sh {1|2|3|4} [--env-file PATH] [--config|--config-json|--pull|--down]
  --config       Render Compose YAML without deploying
  --config-json  Render Compose JSON (validation/test tooling)
  --pull         Pull configured images, then deploy
  --down         Stop/remove containers and networks, retain volumes
Switching stages uses the same project and removes unused services.
TXT
}
[[ $# -gt 0 ]] || { usage; exit 2; }
[[ ${1:-} != --help ]] || { usage; exit 0; }
STAGE="$1"; shift
ACTION=up
while (( $# )); do
  case "$1" in
    --env-file) [[ $# -ge 2 ]] || fail '--env-file needs PATH'; ENV_FILE="$2"; shift 2 ;;
    --config) ACTION=config; shift ;;
    --config-json) ACTION=config-json; shift ;;
    --pull) ACTION=pull; shift ;;
    --down) ACTION=down; shift ;;
    *) fail "Unknown option: $1" ;;
  esac
done
need_env
compose_args "$STAGE"
command -v docker >/dev/null || fail 'Docker not installed; run bootstrap.sh'
if [[ $ACTION == config ]]; then
  "${COMPOSE[@]}" config
elif [[ $ACTION == config-json ]]; then
  "${COMPOSE[@]}" config --format json
else
  if [[ $ACTION != down ]]; then check_security "$STAGE"; fi
  if [[ $ACTION == down ]]; then
    "${COMPOSE[@]}" down
  else
    if [[ $ACTION == pull ]]; then "${COMPOSE[@]}" pull; fi
    "${COMPOSE[@]}" up -d --remove-orphans
    log "Stage $STAGE started; run ./scripts/smoke-test.sh $STAGE."
  fi
fi
