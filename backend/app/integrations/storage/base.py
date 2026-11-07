from typing import Protocol


class ObjectStorage(Protocol):
    """Private object store. Callers keep only the object key, never a URL.

    A Supabase Storage adapter (closed bucket, signed URLs) will implement the same interface.
    """

    def put(self, key: str, data: bytes, content_type: str) -> None: ...

    def delete(self, key: str) -> None: ...
