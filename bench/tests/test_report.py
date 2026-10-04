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


def test_latest_view_takes_newest_result_per_backend(tmp_path):
    old = make_run(tmp_path, "2026-10-01_m_a_0001", {
        "go-mux": {"name": "go mux", "scenarios": {"no_db": {"status": "ok"}}},
        "rust-actix-web": {"name": "rust", "scenarios": {"no_db": {"status": "ok"}}},
    })
    make_rep(old / "go-mux" / "no_db" / "rep-1", [(1000, True)])
    make_rep(old / "rust-actix-web" / "no_db" / "rep-1", [(4000, True)])
    new = make_run(tmp_path, "2026-10-02_m_b_0002", {"go-mux": {"name": "go mux", "scenarios": {"no_db": {"status": "ok"}}}})
    make_rep(new / "go-mux" / "no_db" / "rep-1", [(2000, True)])
    other_machine = make_run(tmp_path, "2026-10-03_x_c_0003", {"go-mux": {"name": "go mux", "scenarios": {"no_db": {"status": "ok"}}}}, machine="x")
    make_rep(other_machine / "go-mux" / "no_db" / "rep-1", [(9000, True)])

    problems = report.Problems()
    summaries = report.build_all(tmp_path, problems)
    views = {v["id"]: v for v in report.latest_views(summaries)}
    assert set(views) == {"latest_m2pro-10c-32g_v2", "latest_x_v2"}
    view = views["latest_m2pro-10c-32g_v2"]
    backends = {b["key"]: b for b in view["backends"]}
    assert backends["go-mux"]["scenarios"]["no_db"]["sustainable_rps"]["median"] == 2000
    assert backends["go-mux"]["scenarios"]["no_db"]["from_run"] == "2026-10-02_m_b_0002"
    assert backends["rust-actix-web"]["scenarios"]["no_db"]["from_run"] == "2026-10-01_m_a_0001"
    assert view["runs"] == ["2026-10-01_m_a_0001", "2026-10-02_m_b_0002"]
    entry = report.index_entry(view, "x")
    assert entry["kind"] == "latest"
    assert entry["headline"]["go-mux"]["no_db"]["sustainable_rps"] == 2000


IMPL = {"server": "net/http", "concurrency": "goroutines", "db_access": "database/sql", "pool": "20"}


def write_manifest(backends: Path, rel, text):
    d = backends / rel
    d.mkdir(parents=True, exist_ok=True)
    (d / "backend.yaml").write_text(text)


def manifest_yaml(impl, extra=""):
    lines = ["name: x", extra, "implementation:"] + [f"  {k}: {v!r}" for k, v in impl.items()]
    return "\n".join(l for l in lines if l) + "\n"


def test_implementation_recorded_in_run_wins(tmp_path):
    backends = tmp_path / "backends"
    write_manifest(backends, "go/mux", manifest_yaml({**IMPL, "pool": "changed later"}))
    run = make_run(tmp_path, "2026-10-04_m_a_0001", {
        "go-mux": {"name": "go mux", "path": "go/mux", "implementation": IMPL, "scenarios": {"no_db": {"status": "ok"}}},
    })
    make_rep(run / "go-mux" / "no_db" / "rep-1", [(1000, True)])
    s = report.build_run(run, report.Problems(), backends)
    b = s["backends"][0]
    assert b["implementation"] == IMPL
    assert b["implementation_from"] == "run"
    assert b["path"] == "go/mux"
    assert b["api_style"] == "rest"


def test_old_run_falls_back_to_current_manifest(tmp_path):
    backends = tmp_path / "backends"
    write_manifest(backends, "go/mux", manifest_yaml(IMPL))
    write_manifest(backends, "java/foam3", manifest_yaml({"server": "jetty"}, "api_style: foam_rpc"))
    write_manifest(backends, "dart/relic", "name: no block\n")
    run = make_run(tmp_path, "2026-10-04_m_a_0001", {
        "go-mux": {"name": "go mux", "path": "go/mux", "scenarios": {"no_db": {"status": "ok"}}},
        "java-foam3-embedded": {"name": "foam3", "scenarios": {"no_db": {"status": "ok"}}},  # no path: slug match
        "dart-relic": {"name": "relic", "scenarios": {"no_db": {"status": "ok"}}},
        "gone-backend": {"name": "gone", "scenarios": {"no_db": {"status": "ok"}}},
    })
    for key in ("go-mux", "java-foam3-embedded", "dart-relic", "gone-backend"):
        make_rep(run / key / "no_db" / "rep-1", [(1000, True)])
    s = report.build_run(run, report.Problems(), backends)
    by = {b["key"]: b for b in s["backends"]}
    assert by["go-mux"]["implementation"] == IMPL
    assert by["go-mux"]["implementation_from"] == "manifest"
    assert by["java-foam3-embedded"]["path"] == "java/foam3"
    assert by["java-foam3-embedded"]["implementation"] == {"server": "jetty"}
    assert by["java-foam3-embedded"]["api_style"] == "foam_rpc"
    assert by["dart-relic"]["implementation"] is None
    assert by["dart-relic"]["implementation_from"] is None
    assert by["gone-backend"]["path"] is None
    assert by["gone-backend"]["implementation"] is None


def test_legacy_backends_get_current_manifest(tmp_path):
    backends = tmp_path / "backends"
    write_manifest(backends, "go/mux", manifest_yaml(IMPL))
    legacy = tmp_path / "summary_v1.json"
    legacy.write_text(json.dumps({
        "go mux no_db_test": {"summary": {"Average Requests/s": 10.0}, "data": []},
        "rust actix web no_db_test": {"summary": {"Average Requests/s": 20.0}, "data": []},
    }))
    s = report.build_legacy(legacy, backends)
    by = {b["key"]: b for b in s["backends"]}
    assert by["go-mux"]["path"] == "go/mux"
    assert by["go-mux"]["implementation_from"] == "manifest"
    assert by["rust-actix-web"]["implementation"] is None


def test_without_pyyaml_the_fallback_is_skipped(tmp_path, monkeypatch):
    backends = tmp_path / "backends"
    write_manifest(backends, "go/mux", manifest_yaml(IMPL))
    monkeypatch.setattr(report, "_load_yaml", lambda path: None)
    report._manifests.clear()
    assert report.describe_backend(backends, "go-mux", {}) == {
        "path": "go/mux", "api_style": "rest", "implementation": None, "implementation_from": None,
    }
    report._manifests.clear()


def test_variant_names_are_distinct():
    assert report._display_name({"name": "foam3", "variant": "embedded"}, "java-foam3-embedded") == "foam3 (embedded)"
    assert report._display_name({"name": "go mux", "variant": "postgres"}, "go-mux") == "go mux"
