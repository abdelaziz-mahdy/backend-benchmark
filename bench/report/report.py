#!/usr/bin/env python3
"""Builds the dashboard data from raw results.

Reads results/runs/*/ (and results/legacy/summary_v1.json) and writes, by
default into benchmark-app/assets/results/:

  index.json          every run: id, date, machine, methodology, file
  runs/<run_id>.json  per-run summary consumed by the dashboard

These files are generated (CI does it before deploying) and are not committed,
so result PRs only ever add a new results/runs/<run_id>/ folder.

  python3 bench/report/report.py            # build
  python3 bench/report/report.py --check    # validate only, non-zero on problems
"""
import argparse
import csv
import datetime as dt
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "bench"))

from benchlib import slo  # noqa: E402

RESULTS = ROOT / "results"
DEFAULT_OUT = ROOT / "benchmark-app" / "assets" / "results"
STEP_FIELDS = [
    "target_rps",
    "achieved_rps",
    "error_rate",
    "p50_ms",
    "p90_ms",
    "p99_ms",
    "p999_ms",
    "app_cpu",
    "app_mem_mb",
    "db_cpu",
    "db_mem_mb",
    "k6_bound",
    "pass",
    "refine",
]
REQUIRED_RUN_KEYS = ["id", "started_at", "machine", "methodology", "params", "items"]


class Problems(list):
    def add(self, where, msg):
        self.append(f"{where}: {msg}")


# ---------------------------------------------------------------- parsing


def _num(v):
    if v in (None, "", "None"):
        return None
    if v in ("True", "False"):
        return v == "True"
    try:
        return float(v)
    except ValueError:
        return v


def read_steps(path):
    with path.open() as f:
        rows = [{k: _num(v) for k, v in row.items()} for row in csv.DictReader(f)]
    for r in rows:
        r["requests"] = r.get("requests") or 0
        r["pass"] = bool(r.get("pass"))
        r["k6_bound"] = bool(r.get("k6_bound"))
        r["refine"] = bool(r.get("refine"))
    return rows


def read_timeseries(path):
    """Columns by role: {"t": [...], "app_cpu": [...], "app_mem_mb": [...], ...}."""
    if not path.exists():
        return {}
    by_t = {}
    with path.open() as f:
        for row in csv.DictReader(f):
            t = int(row["t"])
            slot = by_t.setdefault(t, {})
            slot[f"{row['role']}_cpu"] = float(row["cpu"])
            slot[f"{row['role']}_mem_mb"] = float(row["mem_mb"])
    keys = sorted({k for slot in by_t.values() for k in slot})
    times = sorted(by_t)
    out = {"t": times}
    for k in keys:
        out[k] = [round(by_t[t].get(k), 2) if by_t[t].get(k) is not None else None for t in times]
    return out


# ---------------------------------------------------------------- v2 runs


def scenario_summary(sdir, problems):
    reps, rep_steps, rep_dirs = [], [], []
    for rep_dir in sorted(sdir.glob("rep-*")):
        meta_path = rep_dir / "meta.json"
        if not meta_path.exists():
            continue
        meta = json.loads(meta_path.read_text())
        if meta.get("status") != "ok":
            continue
        steps_path = rep_dir / "steps.csv"
        if not steps_path.exists():
            problems.add(str(rep_dir), "status ok but steps.csv missing")
            continue
        steps = read_steps(steps_path)
        if not steps:
            problems.add(str(rep_dir), "steps.csv is empty")
            continue
        reps.append(slo.summarize_rep(steps))
        rep_steps.append(steps)
        rep_dirs.append(rep_dir)
    if not reps:
        return None
    out = slo.aggregate(reps)
    mid = slo.median_rep_index(reps)
    out["steps"] = [{k: s.get(k) for k in STEP_FIELDS} for s in rep_steps[mid]]
    out["timeseries"] = read_timeseries(rep_dirs[mid] / "timeseries.csv")
    return out


def build_run(run_dir, problems):
    meta = json.loads((run_dir / "run.json").read_text())
    for key in REQUIRED_RUN_KEYS:
        if key not in meta:
            problems.add(str(run_dir / "run.json"), f"missing {key}")
    if meta.get("id") != run_dir.name:
        problems.add(str(run_dir / "run.json"), f"id {meta.get('id')!r} does not match folder name")
    backends = []
    for key, item in sorted(meta.get("items", {}).items()):
        entry = {
            "key": key,
            "name": item.get("name", key),
            "language": item.get("language"),
            "framework": item.get("framework"),
            "version": item.get("version"),
            "runtime": item.get("runtime"),
            "variant": item.get("variant"),
            "db": item.get("db"),
            "pgbouncer": item.get("pgbouncer", False),
            "notes": item.get("notes"),
            "status": item.get("status", "unknown"),
            "scenarios": {},
        }
        for scenario, sentry in sorted(item.get("scenarios", {}).items()):
            source = run_dir
            if sentry.get("status") == "cached":
                source = run_dir.parent / sentry.get("from", "")
                if not source.exists():
                    problems.add(f"{run_dir.name}/{key}/{scenario}", f"cached from missing run {sentry.get('from')}")
                    continue
            summary = scenario_summary(source / key / scenario, problems)
            if summary:
                if source != run_dir:
                    summary["from_run"] = source.name
                entry["scenarios"][scenario] = summary
        backends.append(entry)
    return {
        "id": meta.get("id"),
        "date": (meta.get("started_at") or "")[:10],
        "started_at": meta.get("started_at"),
        "finished_at": meta.get("finished_at"),
        "git_sha": meta.get("git_sha"),
        "dirty": meta.get("dirty", False),
        "contributor": meta.get("contributor"),
        "machine": meta.get("machine", {}),
        "docker": meta.get("docker", {}),
        "methodology": meta.get("methodology"),
        "params": meta.get("params", {}),
        "backends": backends,
    }


# ---------------------------------------------------------------- legacy v1


def build_legacy(path):
    """Convert the v1 dashboard data into the v2 summary shape."""
    raw = json.loads(path.read_text())
    backends = {}
    first_ts = None
    for name, blob in raw.items():
        label, scenario = name.rsplit(" ", 1)
        key = label.replace(" ", "-")
        lang, _, fw = label.partition(" ")
        s = blob.get("summary", {})
        data = blob.get("data", [])
        for row in data:
            ts = row.get("timestamp")
            if ts and (first_ts is None or ts < first_ts):
                first_ts = ts
        entry = backends.setdefault(
            key,
            {
                "key": key,
                "name": fw,
                "language": lang,
                "framework": fw,
                "version": None,
                "runtime": None,
                "variant": "postgres",
                "db": "postgres",
                "status": "ok",
                "scenarios": {},
            },
        )

        def stat(v):
            return {"median": v, "min": v, "max": v} if v is not None else None

        entry["scenarios"][scenario] = {
            "reps": 1,
            "sustainable_rps": None,
            "peak_rps": None,
            "avg_rps": stat(s.get("Average Requests/s")),
            "p50_ms": stat(s.get("Average Response Time 50% (ms)")),
            "p90_ms": None,
            "p99_ms": stat(s.get("Average Response Time 99% (ms)")),
            "p999_ms": None,
            "error_rate": stat(
                (s.get("Average Failures/s") or 0) / s["Average Requests/s"] if s.get("Average Requests/s") else None
            ),
            "app_cpu": stat(s.get("Average Server CPU Usage")),
            "app_mem_mb": stat(s.get("Average Server Memory (MB)")),
            "db_cpu": stat(s.get("Average Database CPU Usage")),
            "db_mem_mb": stat(s.get("Average Database Memory (MB)")),
            "spread": 0.0,
            "unstable": False,
            "loadgen_bound": False,
            "steps": [],
            "timeseries": {
                "t": [r.get("Timestamp") for r in data],
                "rps": [r.get("Requests/s") for r in data],
                "p99_ms": [r.get("99%") for r in data],
                "users": [r.get("User Count") for r in data],
                "app_cpu": [r.get("benchmark_cpu_usage") for r in data],
                "app_mem_mb": [r.get("benchmark_mem_usage_mb") for r in data],
                "db_cpu": [r.get("db_cpu_usage") for r in data],
            },
        }
    date = dt.datetime.fromtimestamp(first_ts, dt.timezone.utc).date().isoformat() if first_ts else None
    return {
        "id": "legacy-v1",
        "kind": "legacy",
        "date": date,
        "started_at": None,
        "finished_at": None,
        "git_sha": None,
        "dirty": False,
        "contributor": None,
        "machine": {"slug": "m2pro-10c-32g", "cpu": "Apple M2 Pro", "cores": 10, "ram_gb": 32},
        "docker": {},
        "methodology": "v1",
        "params": {"tool": "locust", "users": 10000, "runtime_s": 120, "app_cpus": 1.0},
        "backends": sorted(backends.values(), key=lambda b: b["key"]),
    }


# ---------------------------------------------------------------- main


def clean(v):
    """NaN/inf -> None so the output is strict JSON."""
    if isinstance(v, float) and (v != v or v in (float("inf"), float("-inf"))):
        return None
    if isinstance(v, dict):
        return {k: clean(x) for k, x in v.items()}
    if isinstance(v, list):
        return [clean(x) for x in v]
    return v


HEADLINE_KEYS = ["sustainable_rps", "peak_rps", "avg_rps", "p50_ms", "p99_ms", "error_rate", "app_cpu", "app_mem_mb"]


def headline(summary):
    """Median of the headline metrics per backend and scenario, for History."""
    out = {}
    for b in summary["backends"]:
        per = {}
        for scenario, sc in b["scenarios"].items():
            per[scenario] = {k: (sc.get(k) or {}).get("median") for k in HEADLINE_KEYS if sc.get(k)}
        if per:
            out[b["key"]] = per
    return out


def latest_views(summaries):
    """One combined view per (machine, methodology): the newest result of
    every backend and scenario across that machine's runs. Lets a run that
    only measured one new backend sit next to an earlier full run."""
    groups = {}
    for s in summaries:
        if s.get("kind") == "legacy":
            continue
        groups.setdefault((s["machine"].get("slug"), s["methodology"]), []).append(s)
    views = []
    for (slug, methodology), runs in sorted(groups.items()):
        runs = sorted(runs, key=lambda r: (r["date"] or "", r["id"]))
        backends = {}
        for run in runs:  # oldest first, newer runs overwrite
            for b in run["backends"]:
                entry = backends.setdefault(b["key"], {**b, "scenarios": {}})
                entry.update({k: v for k, v in b.items() if k != "scenarios"})
                for scenario, sc in b["scenarios"].items():
                    entry["scenarios"][scenario] = {**sc, "from_run": sc.get("from_run", run["id"])}
        newest = runs[-1]
        views.append(
            {
                **{k: newest.get(k) for k in ("date", "started_at", "finished_at", "docker", "params")},
                "id": f"latest_{slug}_{methodology}",
                "kind": "latest",
                "git_sha": None,
                "dirty": any(r.get("dirty") for r in runs),
                "contributor": None,
                "machine": newest["machine"],
                "methodology": methodology,
                "runs": [r["id"] for r in runs],
                "backends": sorted(backends.values(), key=lambda b: b["key"]),
            }
        )
    return views


def index_entry(summary, file):
    return {
        "id": summary["id"],
        "kind": summary.get("kind", "run"),
        "date": summary["date"],
        "machine": summary["machine"],
        "methodology": summary["methodology"],
        "dirty": summary["dirty"],
        "contributor": summary["contributor"],
        "backends": [b["key"] for b in summary["backends"]],
        "scenarios": sorted({s for b in summary["backends"] for s in b["scenarios"]}),
        "runs": summary.get("runs"),
        "headline": headline(summary),
        "file": file,
    }


def build_all(results_dir, problems):
    summaries = []
    legacy = results_dir / "legacy" / "summary_v1.json"
    if legacy.exists():
        summaries.append(build_legacy(legacy))
    runs_dir = results_dir / "runs"
    if runs_dir.exists():
        for run_dir in sorted(p for p in runs_dir.iterdir() if p.is_dir()):
            if not (run_dir / "run.json").exists():
                problems.add(str(run_dir), "run.json missing")
                continue
            try:
                summaries.append(build_run(run_dir, problems))
            except (json.JSONDecodeError, KeyError, ValueError) as e:
                problems.add(str(run_dir), f"unreadable: {e}")
    return summaries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--results", type=Path, default=RESULTS)
    ap.add_argument("--check", action="store_true", help="validate only")
    args = ap.parse_args()

    problems = Problems()
    summaries = build_all(args.results, problems)
    if args.check:
        for p in problems:
            print("problem:", p)
        print(f"{len(summaries)} runs, {len(problems)} problems")
        sys.exit(1 if problems else 0)

    (args.out / "runs").mkdir(parents=True, exist_ok=True)
    index = []
    for s in summaries + latest_views(summaries):
        file = f"runs/{s['id']}.json"
        (args.out / file).write_text(json.dumps(clean(s), separators=(",", ":"), allow_nan=False, default=str))
        index.append(index_entry(s, file))
    kind_order = {"latest": 0, "run": 1, "legacy": 2}
    index.sort(key=lambda e: (e["date"] or "", e["id"]), reverse=True)
    index.sort(key=lambda e: kind_order.get(e["kind"], 9))
    (args.out / "index.json").write_text(json.dumps({"runs": index}, indent=1))
    for p in problems:
        print("warning:", p)
    print(f"wrote {len(index)} runs to {args.out}")


if __name__ == "__main__":
    main()
