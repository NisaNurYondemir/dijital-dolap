from rate_limit import RateLimiter


def test_allows_under_limit():
    t = [0.0]
    rl = RateLimiter(max_attempts=3, window_seconds=60, clock=lambda: t[0])
    assert rl.blocked_for("a") is None
    for _ in range(2):
        assert rl.hit("a") is None
    assert rl.blocked_for("a") is None


def test_blocks_after_limit_within_window():
    t = [0.0]
    rl = RateLimiter(max_attempts=3, window_seconds=60, clock=lambda: t[0])
    for _ in range(3):
        rl.hit("a")
    assert rl.blocked_for("a") is not None
    assert rl.blocked_for("a") <= 60


def test_unlocks_after_window():
    t = [0.0]
    rl = RateLimiter(max_attempts=3, window_seconds=60, clock=lambda: t[0])
    for _ in range(3):
        rl.hit("a")
    t[0] = 61.0
    assert rl.blocked_for("a") is None


def test_reset_clears_attempts():
    rl = RateLimiter(max_attempts=3, window_seconds=60, clock=lambda: 0.0)
    for _ in range(3):
        rl.hit("a")
    rl.reset("a")
    assert rl.blocked_for("a") is None


def test_keys_are_isolated():
    rl = RateLimiter(max_attempts=1, window_seconds=60, clock=lambda: 0.0)
    rl.hit("ip1:user@x")
    assert rl.blocked_for("ip1:user@x") is not None
    assert rl.blocked_for("ip2:user@x") is None
