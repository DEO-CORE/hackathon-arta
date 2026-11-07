from functools import lru_cache

from app.core.config import get_settings
from app.integrations.storage.base import ObjectStorage
from app.integrations.storage.local import LocalObjectStorage


@lru_cache
def get_storage() -> ObjectStorage:
    # Supabase adapter (BLK-03) will be selected here once credentials exist.
    return LocalObjectStorage(get_settings().storage_local_dir)
