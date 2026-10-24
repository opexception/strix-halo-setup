#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
FOR_WEBUI=0
STAGE=2
while (( $# )); do
  case "$1" in
    --for-webui) FOR_WEBUI=1; shift ;;
    --stage) STAGE="$2"; shift 2 ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --help) echo 'Usage: create-virtual-key.sh [--stage 2|3|4] [--for-webui] [--env-file PATH]'; exit 0 ;;
    *) fail "Unknown option $1" ;;
  esac
done
need_env
[[ "$STAGE" =~ ^[234]$ ]] || fail 'Requires stage 2, 3, or 4'
# Use the same Compose network, avoiding publication of the master-key endpoint.
compose_args "$STAGE"
# --for-webui can be used while stage 2 is running to prepare for stage 3.
if (( STAGE >= 3 )); then check_security "$STAGE"; else check_security 2; fi
KEY="$("${COMPOSE[@]}" exec -T -e KEY_MODEL="$(conf LITELLM_MODEL_NAME local-default)" litellm python -c '
import json, os, urllib.request
url="http://127.0.0.1:4000/key/generate"
payload=json.dumps({"models":[os.environ["KEY_MODEL"]]}).encode()
req=urllib.request.Request(url, data=payload, headers={"Content-Type":"application/json", "Authorization":"Bearer "+os.environ["LITELLM_MASTER_KEY"]}, method="POST")
with urllib.request.urlopen(req, timeout=25) as response:
    body=json.load(response)
key=body.get("key")
if not key or not key.startswith("sk-"):
    raise RuntimeError("Gateway did not return a virtual key")
print(key)
')" || fail 'Virtual key creation failed; check stage 2 logs and database readiness'
if (( FOR_WEBUI )); then
  umask 077
  python3 - "$ENV_FILE" "$KEY" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); key=sys.argv[2]
lines=p.read_text().splitlines()
assert sum(x.startswith('OPENWEBUI_API_KEY=') for x in lines)==1
p.write_text('\n'.join('OPENWEBUI_API_KEY='+key if x.startswith('OPENWEBUI_API_KEY=') else x for x in lines)+'\n')
p.chmod(0o600)
PY
  log 'Saved separate Open WebUI virtual key in private .env; do not share LiteLLM master key.'
else
  printf '%s\n' "$KEY"
  log 'Virtual key printed once; store securely. Never commit or put in shell command history.'
fi
