from benchlib import recovery


class FakeClock:
    def __init__(self):
        self.t = 0.0

    def __call__(self):
        return self.t

    def sleep(self, s):
        self.t += s


def run(answers, **kw):
    clock = FakeClock()
    it = iter(answers)

    def probe():
        clock.t += 0.01
        return next(it, (True, 0.01))

    return recovery.wait_recovered(probe, clock=clock, sleep=clock.sleep, **kw)


def test_healthy_backend_passes_after_three_fast_answers():
    ok, waited = run([(True, 0.01)] * 3)
    assert ok and waited < 10


def test_slow_or_failing_answers_reset_the_streak():
    answers = [(True, 0.01), (True, 1.0), (False, 0.0), (True, 0.01), (True, 0.01), (True, 0.01)]
    ok, waited = run(answers)
    assert ok
    assert waited > 5  # needed six polls plus the settle time


def test_never_recovering_backend_times_out():
    ok, waited = run([(False, 0.0)] * 1000, timeout_s=30)
    assert not ok and waited >= 30
