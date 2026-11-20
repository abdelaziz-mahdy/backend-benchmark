"""Waiting for a backend to recover after an overloaded load step.

A failing step can leave a backlog of queued requests behind. Probing the
next rate straight away then measures the aftermath of the overload rather
than the framework's capacity (FOAM3 kept failing every follow-up probe
for ~15 s this way). Before the next step the runner waits until the
health endpoint answers quickly a few times in a row.

Recovery turned out to be all or nothing: in the FOAM3 run of 2026-10-05
every failing step either recovered within ~7 s or not within 120 s (an
out-of-memory JVM). TIMEOUT_S is therefore 30 s, so a dead app is restarted
after half a minute instead of two.
"""
import time

FAST_S = 0.1  # a health answer slower than this means the backlog is not drained
CONSECUTIVE = 3
TIMEOUT_S = 30.0
SETTLE_S = 5.0
POLL_S = 1.0
# After a restart the app is cold (JIT, pools). Hitting it straight away at
# its last passing rate stalled FOAM3 for good (p99 4.4 s at 16,000 a second
# on 2026-11-19), and every later probe failed. So the runner climbs back
# gently, REWARM_STEP_S at each rate, multiplying by REWARM_FACTOR, ending at
# the last passing rate, then waits for recovery before the next probe.
REWARM_STEP_S = 10.0
REWARM_FACTOR = 4


def wait_recovered(probe, clock=time.monotonic, sleep=time.sleep,
                   fast_s=FAST_S, consecutive=CONSECUTIVE,
                   timeout_s=TIMEOUT_S, settle_s=SETTLE_S, poll_s=POLL_S):
    """Block until `probe()` returns (ok, seconds) fast and ok `consecutive`
    times in a row, then settle. Returns (recovered, waited_seconds)."""
    start = clock()
    streak = 0
    while clock() - start < timeout_s:
        ok, took = probe()
        streak = streak + 1 if ok and took < fast_s else 0
        if streak >= consecutive:
            sleep(settle_s)
            return True, clock() - start
        sleep(poll_s)
    return False, clock() - start


def rewarm_rates(first, top, factor=REWARM_FACTOR):
    """The rates of the gentle climb after a restart: first, then times
    factor while below top, then top itself."""
    rates = []
    rate = first
    while rate < top:
        rates.append(rate)
        rate *= factor
    rates.append(max(top, first))
    return rates
