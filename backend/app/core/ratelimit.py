import math
import threading
import time
from collections import defaultdict, deque

from app.core.errors import AppError


class RateLimiter:
    """In-process sliding window. Adequate for a single-instance MVP; not shared across workers."""

    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def hit(self, key: str, limit: int, window_seconds: int) -> None:
        now = time.monotonic()
        with self._lock:
            q = self._hits[key]
            while q and now - q[0] >= window_seconds:
                q.popleft()
            if len(q) >= limit:
                retry = max(1, math.ceil(window_seconds - (now - q[0])))
                raise AppError(
                    429,
                    "RATE_LIMITED",
                    details={"retry_after_seconds": retry},
                    headers={"Retry-After": str(retry)},
                )
            q.append(now)

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()
