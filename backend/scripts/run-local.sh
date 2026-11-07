#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LD_LIBRARY_PATH="$PWD/var/postgres/runtime/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
pg_bin="$PWD/var/postgres/runtime/usr/bin"
if ! "$pg_bin/pg_ctl" -D "$PWD/var/postgres/data" status >/dev/null 2>&1; then
  "$pg_bin/pg_ctl" -D "$PWD/var/postgres/data" -l "$PWD/var/postgres/server.log" start
fi
.venv/bin/python - <<'PY'
from dotenv import load_dotenv
from alembic import command
from alembic.config import Config
load_dotenv('.env')
command.upgrade(Config('alembic.ini'), 'head')
PY
exec .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1
