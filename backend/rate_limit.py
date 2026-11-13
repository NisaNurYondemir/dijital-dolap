"""Bellek-içi basit hıt-limit (login brute-force koruması).

Kaydırma penceresi mantığı: pencere içindeki başarısız deneme sayısı
limiti aşarsa anahtar pencere boyunca kilitlenir. Başarılı giriş
sayacı sıfırlar. Saat test edilebilir olsun diye enjekte edilir.
"""
import time
from collections import defaultdict, deque
from typing import Callable, Optional


class RateLimiter:
    def __init__(
        self,
        max_attempts: int = 5,
        window_seconds: float = 900.0,
        clock: Callable[[], float] = time.monotonic,
    ):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self.clock = clock
        self._attempts: dict[str, deque[float]] = defaultdict(deque)

    def blocked_for(self, key: str) -> Optional[float]:
        """Anahtar kilitliyse kalan saniyeyi, değilse None döner."""
        now = self.clock()
        q = self._attempts.get(key)
        if not q:
            return None
        # pencere dışındaki denemeleri at
        while q and now - q[0] > self.window_seconds:
            q.popleft()
        if len(q) < self.max_attempts:
            return None
        return self.window_seconds - (now - q[0])

    def hit(self, key: str) -> Optional[float]:
        """Başarısız deneme kaydet; kilitlendiyse kalan süreyi döner."""
        now = self.clock()
        q = self._attempts[key]
        q.append(now)
        while q and now - q[0] > self.window_seconds:
            q.popleft()
        if len(q) >= self.max_attempts:
            return self.window_seconds - (now - q[0])
        return None

    def reset(self, key: str) -> None:
        """Başarılı giriş: sayacı temizle."""
        self._attempts.pop(key, None)
