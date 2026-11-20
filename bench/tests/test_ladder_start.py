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


def run_climb(ladder, passes, retry_first):
    """passes: the pass/fail answers do_step gives, in order."""
    answers, tried, retried = iter(passes), [], []

    def do_step(rate):
        tried.append(rate)
        return next(answers)

    bench.climb(ladder, do_step, retry_first=retry_first, on_retry=lambda: retried.append(True))
    return tried, bool(retried)


def test_a_cold_first_step_is_tried_once_more():
    # Go db_mixed, 2026-11-18: 4000 failed straight after warmup at 250.
    assert run_climb([4000, 8000, 16000], [False, True, True, False], True) == ([4000, 4000, 8000, 16000], True)


def test_a_first_step_that_fails_twice_stops_the_climb():
    assert run_climb([4000, 8000], [False, False], True) == ([4000, 4000], True)


def test_only_the_first_step_gets_a_second_try():
    assert run_climb([4000, 8000, 16000], [True, False], True) == ([4000, 8000], False)


def test_a_full_ladder_does_not_retry():
    assert run_climb([250, 500], [False], False) == ([250], False)


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
