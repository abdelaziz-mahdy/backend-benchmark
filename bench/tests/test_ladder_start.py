import json

import bench


def make_run(runs, run_id, slug, item, scenario, rows):
    d = runs / run_id
    (d / item / scenario / "rep-1").mkdir(parents=True)
    (d / "run.json").write_text(json.dumps({"id": run_id, "machine": {"slug": slug}}))
    lines = ["target_rps,pass"] + [f"{r},{p}" for r, p in rows]
    (d / item / scenario / "rep-1" / "steps.csv").write_text("\n".join(lines) + "\n")


def test_first_rep_starts_from_the_newest_earlier_run_on_this_machine(tmp_path, monkeypatch):
    runs = tmp_path / "runs"
    make_run(runs, "2026-10-01_m_a", "m", "rust", "db_read", [(16000, True), (32000, True), (64000, False)])
    make_run(runs, "2026-11-01_m_b", "m", "rust", "db_read", [(16000, True), (32000, False)])
    make_run(runs, "2026-11-02_other_c", "other", "rust", "db_read", [(64000, True)])
    monkeypatch.setattr(bench, "RESULTS", tmp_path)
    meta = {"id": "2026-11-18_m_new", "machine": {"slug": "m"}}
    assert bench.earlier_best(meta, "rust", "db_read") == (16000, "2026-11-01_m_b")
    assert bench.earlier_best(meta, "rust", "db_write") == (0, None)


def run_climb(ladder, passes, retry_first, near_misses=()):
    """passes: the pass/fail answers do_step gives, in order. near_misses:
    the indexes of the answers whose failure was a near miss."""
    answers, tried, retried = iter(passes), [], []
    near = set(near_misses)

    def do_step(rate):
        tried.append(rate)
        return next(answers)

    def near_miss():
        return "near miss" if len(tried) - 1 in near else None

    bench.climb(
        ladder,
        do_step,
        retry_first=retry_first,
        on_retry=retried.append,
        near_miss=near_miss,
    )
    return tried, retried


def test_a_cold_first_step_is_tried_once_more():
    # Go db_mixed, 2026-11-18: 4000 failed straight after warmup at 250.
    assert run_climb([4000, 8000, 16000], [False, True, True, False], True) == (
        [4000, 4000, 8000, 16000],
        ["first step"],
    )


def test_a_first_step_that_fails_twice_stops_the_climb():
    assert run_climb([4000, 8000], [False, False], True) == ([4000, 4000], ["first step"])


def test_a_plain_failure_after_the_first_step_ends_the_climb():
    assert run_climb([4000, 8000, 16000], [True, False], True) == ([4000, 8000], [])


def test_a_full_ladder_does_not_retry_a_plain_failure():
    assert run_climb([250, 500], [False], False) == ([250], [])


def test_a_near_miss_anywhere_on_the_ladder_is_tried_once_more():
    # .NET db_write, 2026-11-20 rep 2: 8,000 failed on a short pause; rep 3
    # went on to 17,000.
    assert run_climb([4000, 8000, 16000], [True, False, True, False], False, near_misses={1}) == (
        [4000, 8000, 8000, 16000],
        ["near miss"],
    )


def test_a_near_miss_that_misses_again_ends_the_climb():
    assert run_climb([4000, 8000, 16000], [True, False, False], False, near_misses={1, 2}) == (
        [4000, 8000, 8000],
        ["near miss"],
    )


def test_a_first_step_gets_one_second_try_not_two():
    assert run_climb([4000, 8000], [False, False], True, near_misses={0, 1}) == (
        [4000, 4000],
        ["near miss"],
    )


def test_a_stopped_app_is_not_tried_again():
    tried = []

    def do_step(rate):
        tried.append(rate)
        return False

    assert not bench.try_twice(8000, do_step, lambda: "near miss", stopped=lambda: True)
    assert tried == [8000]


def test_try_twice_returns_the_second_answer():
    answers = iter([False, True])
    retried = []
    assert bench.try_twice(8000, lambda r: next(answers), lambda: "near miss", on_retry=retried.append)
    assert retried == ["near miss"]


def test_try_twice_leaves_a_failure_without_a_reason_alone():
    tried = []

    def do_step(rate):
        tried.append(rate)
        return False

    assert not bench.try_twice(8000, do_step, lambda: None)
    assert tried == [8000]


class _Stack:
    def __init__(self, profiles):
        self.item = type("Item", (), {"profiles": profiles})()
        self.calls = []

    def run(self, *args, **kw):
        self.calls.append(args)
        return "done"


def test_seeded_postgres_is_vacuumed_so_autovacuum_stays_out_of_the_steps():
    stack = _Stack(["postgres"])
    assert bench.vacuum_db(stack) == "done"
    assert stack.calls == [("exec", "-T", "db", "psql", "-U", "postgres", "-c", "VACUUM ANALYZE")]


def test_a_backend_without_postgres_is_not_vacuumed():
    stack = _Stack([])
    assert bench.vacuum_db(stack) is None
    assert stack.calls == []
