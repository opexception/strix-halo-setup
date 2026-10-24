#!/usr/bin/env bash
# Requires Docker Compose; validates merged port surface of ALL stages, no containers started.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
command -v docker >/dev/null || fail 'Docker CLI unavailable'
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
"$PROJECT_ROOT/scripts/init-config.sh" "$TMP_DIR/.env" >/dev/null
python3 - "$TMP_DIR/.env" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace('OPENWEBUI_API_KEY=REPLACE_WITH_VIRTUAL_KEY', 'OPENWEBUI_API_KEY=sk-offline-validation-key')
s=s.replace('API_DOMAIN=api.halo.example.invalid', 'API_DOMAIN=api.halo.test')
s=s.replace('CHAT_DOMAIN=chat.halo.example.invalid', 'CHAT_DOMAIN=chat.halo.test')
p.write_text(s)
PY
ENV_FILE="$TMP_DIR/.env"
for STAGE in 1 2 3 4; do
  compose_args "$STAGE"
  "${COMPOSE[@]}" config --format json >"$TMP_DIR/$STAGE.json"
done
python3 - "$TMP_DIR" <<'PY'
import json, pathlib, sys
folder=pathlib.Path(sys.argv[1]); targets={1:{'ollama'},2:{'litellm'},3:{'litellm','openwebui'},4:{'caddy'}}
for stage, allowed in targets.items():
    data=json.loads((folder/f'{stage}.json').read_text())
    exposed={s for s,cfg in data['services'].items() if cfg.get('ports')}
    assert exposed == allowed, f'Stage {stage}: exposed {exposed}, expected {allowed}'
    for name,cfg in data['services'].items():
        assert not cfg.get('privileged'), (stage,name)
        assert cfg.get('network_mode') != 'host', (stage,name)
    if stage == 4:
        assert sorted(x['target'] for x in data['services']['caddy']['ports']) == [80,443]
    print(f'Stage {stage}: exposed services = {sorted(exposed)}')
PY
