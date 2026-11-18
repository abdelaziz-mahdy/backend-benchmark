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
