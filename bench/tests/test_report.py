import csv
import importlib.util
import json
from pathlib import Path

_spec = importlib.util.spec_from_file_location("report", Path(__file__).resolve().parent.parent / "report" / "report.py")
report = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(report)

STEP_HEADER = ["target_rps", "achieved_rps", "requests", "dropped", "error_rate", "p50_ms", "p90_ms", "p99_ms",
               "p999_ms", "avg_ms", "app_cpu", "app_mem_mb", "db_cpu", "db_mem_mb", "k6_cpu", "k6_bound", "refine",
               "k6_exit", "start_s", "end_s", "pass"]


def make_rep(rep_dir: Path, rates_pass):
    rep_dir.mkdir(parents=True)
    with (rep_dir / "steps.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(STEP_HEADER)
        for rate, ok in rates_pass:
            w.writerow([rate, rate, rate * 30, 0, 0.0, 1, 2, 5 if ok else 500, 9, 1, 50, 100, "", "", 10,
                        False, False, 0, 0, 30, ok])
    (rep_dir / "timeseries.csv").write_text("t,role,cpu,mem_mb\n0,app,10,100\n0,k6,5,20\n1,app,20,101\n")
    (rep_dir / "meta.json").write_text(json.dumps({"status": "ok", "image_digest": "sha256:x"}))


def make_run(results: Path, run_id, items, machine="m2pro-10c-32g"):
    run_dir = results / "runs" / run_id
    run_dir.mkdir(parents=True)
    (run_dir / "run.json").write_text(json.dumps({
        "id": run_id, "started_at": "2026-10-04T00:00:00+00:00", "machine": {"slug": machine},
        "methodology": "v2", "params": {}, "items": items,
    }))
    return run_dir


def test_run_summary_with_cached_scenario(tmp_path):
    old = make_run(tmp_path, "2026-10-01_m_a_0001", {"go-mux": {"name": "go mux", "scenarios": {"no_db": {"status": "ok"}}}})
    for r in (1, 2, 3):
        make_rep(old / "go-mux" / "no_db" / f"rep-{r}", [(1000, True), (2000, r != 3)])
    new = make_run(tmp_path, "2026-10-04_m_b_0002", {
        "go-mux": {"name": "go mux", "scenarios": {"no_db": {"status": "cached", "from": "2026-10-01_m_a_0001"},
                                                    "db_read": {"status": "ok"}}},
    })
    make_rep(new / "go-mux" / "db_read" / "rep-1", [(250, False)])
    problems = report.Problems()
    s = report.build_run(new, problems)
    assert problems == []
    sc = s["backends"][0]["scenarios"]
    assert sc["no_db"]["from_run"] == "2026-10-01_m_a_0001"
    assert sc["no_db"]["sustainable_rps"]["median"] == 2000
    assert sc["no_db"]["sustainable_rps"]["min"] == 1000
    assert sc["db_read"]["sustainable_rps"]["median"] == 0
    assert sc["db_read"]["p99_ms"] is None
    assert sc["no_db"]["timeseries"]["app_cpu"] == [10.0, 20.0]
    assert sc["no_db"]["timeseries"]["k6_cpu"] == [5.0, None]


def test_check_flags_bad_runs(tmp_path):
    bad = make_run(tmp_path, "folder-name", {})
    data = json.loads((bad / "run.json").read_text())
    data["id"] = "other"
    (bad / "run.json").write_text(json.dumps(data))
    (tmp_path / "runs" / "no-run-json").mkdir()
    empty = make_run(tmp_path, "empty-steps", {"x": {"scenarios": {"no_db": {"status": "ok"}}}})
    rep = empty / "x" / "no_db" / "rep-1"
    rep.mkdir(parents=True)
    (rep / "meta.json").write_text('{"status": "ok"}')
    (rep / "steps.csv").write_text("")
    problems = report.Problems()
    report.build_all(tmp_path, problems)
    text = "\n".join(problems)
    assert "does not match folder name" in text
    assert "run.json missing" in text
    assert "steps.csv is empty" in text


def test_clean_nan():
    assert report.clean({"a": [float("nan"), 1.0], "b": float("inf")}) == {"a": [None, 1.0], "b": None}
