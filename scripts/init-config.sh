#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/.env"
if [[ ${1:-} == --help ]]; then
  echo "Usage: $0 [destination-file] (creates private config; refuses overwrite)"; exit 0
fi
[[ $# -le 1 ]] || { echo 'Too many arguments' >&2; exit 1; }
[[ $# -eq 1 ]] && OUT="$1"
[[ ! -e "$OUT" ]] || { echo "Refusing to overwrite: $OUT" >&2; exit 1; }
command -v openssl >/dev/null || { echo 'Install openssl' >&2; exit 1; }
umask 077
mkdir -p "$(dirname "$OUT")"
cp "$ROOT/.env.example" "$OUT"
export INIT_MASTER="sk-$(openssl rand -hex 32)"
export INIT_SALT="sk-$(openssl rand -hex 32)"
export INIT_DB="$(openssl rand -hex 32)"
export INIT_WEBUI_SECRET="$(openssl rand -hex 32)"
export INIT_ADMIN_PASS="$(openssl rand -hex 24)"
export INIT_RENDER_GID="$(getent group render | cut -d: -f3 || true)"
export INIT_VIDEO_GID="$(getent group video | cut -d: -f3 || true)"
[[ "$INIT_RENDER_GID" =~ ^[0-9]+$ && "$INIT_VIDEO_GID" =~ ^[0-9]+$ ]] || {
  rm -f "$OUT"; echo 'render/video groups not found; initialize config on Linux host' >&2; exit 1;
}
python3 - "$OUT" <<'PY'
import os, pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text()
repl = {
  'LITELLM_MASTER_KEY': os.environ['INIT_MASTER'],
  'LITELLM_SALT_KEY': os.environ['INIT_SALT'],
  'POSTGRES_PASSWORD': os.environ['INIT_DB'],
  'WEBUI_SECRET_KEY': os.environ['INIT_WEBUI_SECRET'],
  'WEBUI_ADMIN_PASSWORD': os.environ['INIT_ADMIN_PASS'],
  'RENDER_GID': os.environ['INIT_RENDER_GID'],
  'VIDEO_GID': os.environ['INIT_VIDEO_GID'],
}
lines = []
for line in s.splitlines():
    key = line.partition('=')[0]
    lines.append(f'{key}={repl[key]}' if key in repl and line.startswith(key+'=') else line)
p.write_text('\n'.join(lines) + '\n')
PY
chmod 600 "$OUT"
echo "Created $OUT (mode 600). Back up encrypted; preserve LiteLLM salt and PostgreSQL credentials."
echo 'Set PUBLIC_BIND_IP, model, and TLS names as appropriate; never commit this file.'
