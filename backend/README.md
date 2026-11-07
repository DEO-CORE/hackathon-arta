# ARTA backend

FastAPI + sync SQLAlchemy 2 (psycopg 3) + Alembic + PostgreSQL. Python 3.12+.
Sync was chosen because row locks (`SELECT ... FOR UPDATE`) and Pillow/Argon2 work are blocking
anyway; FastAPI runs sync routes in a thread pool.

Dependencies: `pyproject.toml` is the manifest; locks are `requirements.lock` and
`requirements-dev.lock` (pip-tools: `pip-compile --strip-extras [--extra dev] -o ... pyproject.toml`).

## Run (from `backend/`)

```sh
python3.12 -m venv .venv && source .venv/bin/activate
python -m pip install -r requirements-dev.lock
export DATABASE_URL=...   # postgresql://user:pass@host:port/db
export JWT_SECRET=...     # >= 32 chars, no default
python -m alembic upgrade head
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Settings (names only, see `.env.example`): DATABASE_URL, JWT_SECRET, CORS_ORIGINS,
STORAGE_LOCAL_DIR, ACCESS_TOKEN_MINUTES, RATE_LIMIT_*.

## Local PostgreSQL used for development (Homebrew postgresql@16, own cluster)

The cluster was created with superuser role `arta` (trust auth, loopback only). Exact commands:

```sh
B=/opt/homebrew/opt/postgresql@16/bin; D=$HOME/.arta-pgdata
$B/initdb -D $D -U arta --auth=trust -E UTF8
$B/pg_ctl -D $D -o "-p 54329 -c listen_addresses=127.0.0.1" -l $D/server.log -w start
$B/createdb -h 127.0.0.1 -p 54329 -U arta arta_dev
$B/createdb -h 127.0.0.1 -p 54329 -U arta arta_test
# optional extra superuser roles, e.g. your OS user:
$B/psql -h 127.0.0.1 -p 54329 -U arta -d postgres -c "create role $USER superuser login"
```

Tests were run with `TEST_DATABASE_URL=postgresql://arta@127.0.0.1:54329/arta_test`.

## Tests and lint

Integration tests need a separate PostgreSQL database whose name ends with `_test`; the suite
runs `alembic downgrade base` + `upgrade head` on it and truncates tables between tests.

```sh
export TEST_DATABASE_URL=postgresql://user:pass@host:port/arta_test
python -m pytest
python -m ruff check .
python -m ruff format --check .
```
