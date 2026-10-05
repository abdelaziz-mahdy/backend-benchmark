#!/usr/bin/env python3
"""Live progress of a benchmark run, read from its results folder.

    python3 bench/status.py                 # newest run, refresh every 10 s
    python3 bench/status.py --once          # print once and exit
    python3 bench/status.py --run-id <id> --only foam3
    python3 bench/status.py --serve 8766   # same view as a web page

The total comes from run.json "plan" (written by bench.py). Runs started
before that field existed fall back to the manifests, filtered by --only the
same way bench.py filters them.
"""
import argparse
import csv
import datetime as dt
import html
import json
import os
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULTS = Path(os.environ.get("BENCH_RESULTS", ROOT / "results"))


def newest_run():
    runs = sorted((RESULTS / "runs").glob("*/run.json"), key=lambda p: p.stat().st_mtime)
    return runs[-1].parent if runs else None


def plan_from_manifests(only):
    sys.path.insert(0, str(ROOT / "bench"))
    try:
        from benchlib import manifest
    except ImportError:  # PyYAML missing
        return None
    return [{"key": i.key, "scenarios": list(i.scenarios)} for i in manifest.filter_items(manifest.load_items(ROOT), only)]


def running_only():
    """--only of a bench.py that is running now, for runs without a plan."""
    ps = subprocess.run(["ps", "-Ao", "args"], capture_output=True, text=True).stdout
    for line in ps.splitlines():
        args = line.split()
        if any(a.endswith("bench.py") for a in args) and "--only" in args[:-1]:
            return args[args.index("--only") + 1]
    return None


def rep_state(rep_dir):
    """('done' | 'running' | 'failed' | None, restarts, last tested rate)."""
    if not rep_dir.exists():
        return None, 0, None
    rates = sorted(int(p.stem.split("-")[1]) for p in rep_dir.glob("k6-*.json"))
    last = rates[-1] if rates else None
    meta = rep_dir / "meta.json"
    if not meta.exists():
        return "running", 0, last
    restarts = 0
    steps = rep_dir / "steps.csv"
    if steps.exists():
        with steps.open() as f:
            restarts = sum(r.get("restarted") == "True" for r in csv.DictReader(f))
    status = json.loads(meta.read_text()).get("status")
    return ("done" if status == "ok" else "failed"), restarts, last


def fmt_duration(seconds):
    seconds = int(seconds)
    h, m = divmod(seconds // 60, 60)
    return f"{h}h {m:02d}m" if h else f"{m}m"


def render(run_dir, only):
    meta = json.loads((run_dir / "run.json").read_text())
    reps = meta["params"]["reps"]
    plan = meta.get("plan") or plan_from_manifests(only or running_only())
    if plan is None:
        plan = [{"key": k, "scenarios": list(v.get("scenarios", {}))} for k, v in meta["items"].items()]

    started = dt.datetime.fromisoformat(meta["started_at"])
    now = dt.datetime.now(dt.timezone.utc)
    elapsed = (now - started).total_seconds()

    lines = [f"run      {meta['id']}  ({meta['methodology']})"]
    total = done = failed = restarts = 0
    current = None
    for item in plan:
        lines.append(f"\n{item['key']}")
        for scenario in item["scenarios"]:
            status = meta["items"].get(item["key"], {}).get("scenarios", {}).get(scenario, {})
            marks = []
            for rep in range(1, reps + 1):
                total += 1
                if status.get("status") == "cached":
                    done += 1
                    marks.append("c")
                    continue
                state, r, last = rep_state(run_dir / item["key"] / scenario / f"rep-{rep}")
                restarts += r
                if state == "done":
                    done += 1
                    marks.append("✓")
                elif state == "failed":
                    failed += 1
                    marks.append("✗")
                elif state == "running":
                    marks.append("▶")
                    current = (item["key"], scenario, rep, last)
                else:
                    marks.append("·")
            lines.append(f"  {scenario:9} {' '.join(marks)}")

    finished = meta.get("finished_at")
    pct = 100 * (done + failed) / total if total else 0
    bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
    head = [lines[0], f"progress {bar} {done + failed}/{total} reps ({pct:.0f}%)"]
    if finished:
        head.append(f"status   finished at {dt.datetime.fromisoformat(finished).astimezone():%H:%M}")
    else:
        if current:
            key, scenario, rep, last = current
            step = f", last step {last} rps" if last else ", warming up"
            head.append(f"now      {key} {scenario} rep {rep}/{reps}{step}")
        eta = ""
        if done + failed:
            left = elapsed / (done + failed) * (total - done - failed)
            end = (now + dt.timedelta(seconds=left)).astimezone()
            eta = f", ~{fmt_duration(left)} left (about {end:%H:%M})"
        head.append(f"elapsed  {fmt_duration(elapsed)}{eta}")
    head.append(f"restarts {restarts} (finished reps)" + (f", failed reps {failed}" if failed else ""))
    legend = "\n✓ done  ▶ running  · waiting  ✗ failed  c cached"
    return "\n".join(head + lines[1:] + [legend])


PAGE = """<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="{every}">
<title>Benchmark progress</title>
<style>
body {{ margin: 0; padding: 24px 16px; background: #fff; color: #1f2328;
  font: 14px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; }}
@media (prefers-color-scheme: dark) {{ body {{ background: #0d1117; color: #e6edf3; }} }}
pre {{ margin: 0 auto; max-width: 720px; white-space: pre-wrap; }}
</style>
<pre>{text}</pre>"""


def serve(port, current_text, every):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            try:
                text = current_text()
            except Exception as e:  # a half-written run.json; next refresh retries
                text = f"could not read the run: {e}"
            body = PAGE.format(every=int(every), text=html.escape(text)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    print(f"serving on http://localhost:{port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--run-id", help="default: the newest run")
    ap.add_argument("--only", help="same filter the run used, for runs without a plan in run.json")
    ap.add_argument("--once", action="store_true", help="print once and exit")
    ap.add_argument("--every", type=float, default=10, help="refresh interval in seconds")
    ap.add_argument("--serve", type=int, metavar="PORT", help="serve the view as a web page on this port")
    args = ap.parse_args()

    def current_text():
        run_dir = RESULTS / "runs" / args.run_id if args.run_id else newest_run()
        if not run_dir or not (run_dir / "run.json").exists():
            return "no run found"
        return render(run_dir, args.only) + f"\n\nupdated {dt.datetime.now():%H:%M:%S}"

    if args.serve:
        serve(args.serve, current_text, args.every)
        return
    while True:
        text = current_text()
        if args.once:
            print(text)
            return
        print("\033[2J\033[H" + text + ", Ctrl-C to quit", flush=True)
        try:
            time.sleep(args.every)
        except KeyboardInterrupt:
            return


if __name__ == "__main__":
    main()
