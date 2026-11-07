"""Test environment. Must run before app modules read settings.

Integration tests need a dedicated PostgreSQL database whose name ends with "_test";
set TEST_DATABASE_URL. SQLite is deliberately not supported (row locking is under test).
"""

import os
import tempfile

TEST_JWT_SECRET = "test-only-secret-test-only-secret-0123456789"  # not a real secret

os.environ["JWT_SECRET"] = TEST_JWT_SECRET
os.environ["DATABASE_URL"] = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+psycopg://invalid@127.0.0.1:1/unset_test"
)
os.environ["EMAIL_CODE_HMAC_KEY"] = (
    "test-only-hmac-key-test-only-hmac-key-0123"  # not a real secret
)
os.environ.setdefault("STORAGE_LOCAL_DIR", tempfile.mkdtemp(prefix="arta-test-storage-"))
for _k in (
    "RATE_LIMIT_LOGIN_PER_EMAIL",
    "RATE_LIMIT_LOGIN_PER_IP",
    "RATE_LIMIT_REGISTER_PER_IP",
    "RATE_LIMIT_UPLOAD_PER_USER",
    "RATE_LIMIT_LIFECYCLE_PER_USER",
):
    os.environ[_k] = "1000"
