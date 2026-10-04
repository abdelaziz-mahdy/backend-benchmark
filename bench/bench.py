#!/usr/bin/env python3
"""Benchmark runner. Usage: see bench/README.md or `bench/run.sh --help`."""
import argparse
import csv
import datetime as dt
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from benchlib import foam_rpc, machine, manifest, slo
from benchlib.stats import Sampler

ROOT = Path(__file__).resolve().parent.parent
BENCH = ROOT / "bench"
RESULTS = Path(os.environ.get("BENCH_RESULTS", ROOT / "results"))
PORT = int(os.environ.get("BENCH_PORT", "18000"))
# Overrides compose.yaml's "name: bench" so two stacks can coexist.
PROJECT = os.environ.get("COMPOSE_PROJECT_NAME", "bench")
HEALTH_TIMEOUT_S = 240


def log(msg):
    print(f"[{dt.datetime.now():%H:%M:%S}] {msg}", flush=True)


# ---------------------------------------------------------------- compose


class Stack:
    """docker compose wrapper for one item."""

    def __init__(self, item, cpus, out_dir=None):
        self.item = item
        self.env = dict(os.environ)
        self.env.update(
            APP_CPUSET=cpus["app"],
            DB_CPUSET=cpus["db"],
            K6_CPUSET=cpus["k6"],
            APP_DIR=str(item.app_dir),
            BACKEND_SLUG=item.key,
            DATABASE_HOST=item.database_host,
            BENCH_VARIANT=item.variant.id,
            BENCH_PORT=str(PORT),
            OUT_DIR=str(out_dir or BENCH / ".tmp"),
        )

    def _cmd(self, *args, load=False):
        cmd = ["docker", "compose", "-f", str(BENCH / "compose.yaml"), "--project-directory", str(BENCH)]
        for p in self.item.profiles + (["load"] if load else []):
            cmd += ["--profile", p]
        return cmd + list(args)

    def run(self, *args, load=False, check=False, capture=True, timeout=None):
        return subprocess.run(
            self._cmd(*args, load=load),
            env=self.env,
            capture_output=capture,
            text=True,
            check=check,
            timeout=timeout,
        )

    def build(self):
        return self.run("build", "benchmark")

    def image_digest(self):
        out = subprocess.run(
            ["docker", "image", "inspect", f"bench-app-{self.item.key}", "--format", "{{.Id}}"],
            capture_output=True,
            text=True,
        )
        return out.stdout.strip()

    def up(self):
        return self.run("up", "-d", "--wait-timeout", "120", "benchmark")

    def down(self):
        self.run("down", "-v", "--remove-orphans", load=True)

    def k6(self, script, out_name=None, **env):
        args = ["run", "--rm", "--no-deps", "k6", "run", "--quiet", "--no-color"]
        if out_name:
            args += ["--summary-export", f"/out/{out_name}"]
        env.setdefault("API_STYLE", self.item.api_style)
        for k, v in env.items():
            args += ["-e", f"{k}={v}"]
        args.append(f"/scenarios/{script}")
        return self.run(*args, load=True)

    def logs(self):
        return self.run("logs", "--no-color", "--tail", "60", "benchmark").stdout


def wait_healthy(stack):
    deadline = time.time() + HEALTH_TIMEOUT_S
    url = f"http://127.0.0.1:{PORT}{stack.item.health_path}"
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return True
        except (urllib.error.URLError, ConnectionError, TimeoutError, OSError):
            pass
        state = stack.run("ps", "-a", "benchmark", "--format", "{{.State}}").stdout.strip()
        if state in ("exited", "dead"):
            return False
        time.sleep(2)
    return False


# ---------------------------------------------------------------- run bookkeeping


def git_sha():
    return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip() or "nogit"


def git_dirty():
    """True when backends/ or bench/ differ from the recorded commit."""
    out = subprocess.run(
        ["git", "status", "--porcelain", "--", "backends", "bench"], cwd=ROOT, capture_output=True, text=True
    ).stdout
    return bool(out.strip())


def docker_cpusets():
    try:
        return machine.cpusets(int(docker_info().get("cpus") or 0))
    except ValueError as e:
        sys.exit(str(e))


def docker_info():
    out = subprocess.run(
        ["docker", "info", "--format", "{{json .}}"], capture_output=True, text=True
    ).stdout
    try:
        info = json.loads(out)
    except json.JSONDecodeError:
        return {}
    return {"version": info.get("ServerVersion"), "cpus": info.get("NCPU"), "mem_gb": round(info.get("MemTotal", 0) / 2**30, 1)}


def infra_images():
    """Pinned infrastructure images from compose.yaml (db, pgbouncer, k6)."""
    import yaml

    services = yaml.safe_load((BENCH / "compose.yaml").read_text())["services"]
    return {name: svc["image"] for name, svc in services.items() if name != "benchmark"}


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True))
    tmp.replace(path)


def new_run(run_id, steps, reps, cpus, contributor):
    m = machine.describe()
    # Random suffix: two contributors on the same day/machine/commit never collide.
    run_id = run_id or f"{dt.date.today():%Y-%m-%d}_{m['slug']}_{git_sha()}_{secrets.token_hex(2)}"
    run_dir = RESULTS / "runs" / run_id
    run_json = run_dir / "run.json"
    if run_json.exists():
        meta = json.loads(run_json.read_text())
        if meta["machine"]["slug"] != m["slug"]:
            sys.exit(f"run {run_id} was recorded on {meta['machine']['slug']}, this is {m['slug']}")
        log(f"resuming run {run_id}")
        return run_dir, meta
    meta = {
        "id": run_id,
        "started_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "git_sha": git_sha(),
        "dirty": git_dirty(),
        "contributor": contributor,
        "machine": m,
        "docker": docker_info(),
        "methodology": slo.METHODOLOGY,
        "params": {
            "steps": steps,
            "step_seconds": slo.STEP_SECONDS,
            "warmup_seconds": slo.WARMUP_SECONDS,
            "reps": reps,
            "seed_rows": slo.SEED_ROWS,
            "slo": {"p99_ms": slo.SLO_P99_MS, "error_rate": slo.SLO_ERROR_RATE, "achieved_ratio": slo.SLO_ACHIEVED_RATIO},
            "cpusets": cpus,
            "memory": {"app": "2g", "db": "2g"},
            "images": infra_images(),
        },
        "items": {},
    }
    write_json(run_json, meta)
    log(f"new run {run_id}")
    return run_dir, meta


def rep_done(rep_dir):
    meta = rep_dir / "meta.json"
    return meta.exists() and json.loads(meta.read_text()).get("status") == "ok"


def cached_from(run_meta, item_key, scenario, digest, reps):
    """Newest earlier run on this machine/methodology with all reps for this image."""
    runs_dir = RESULTS / "runs"
    if not runs_dir.exists():
        return None
    for other in sorted(runs_dir.iterdir(), reverse=True):
        if other.name == run_meta["id"] or not (other / "run.json").exists():
            continue
        meta = json.loads((other / "run.json").read_text())
        if meta["machine"]["slug"] != run_meta["machine"]["slug"] or meta["methodology"] != run_meta["methodology"]:
            continue
        entry = meta.get("items", {}).get(item_key, {}).get("scenarios", {}).get(scenario, {})
        if entry.get("status") == "cached":
            continue  # only point at runs that hold the data themselves
        sdir = other / item_key / scenario
        done = [d for d in sdir.glob("rep-*") if rep_done(d)]
        if len(done) >= reps and all(json.loads((d / "meta.json").read_text()).get("image_digest") == digest for d in done):
            return meta["id"]
    return None


# ---------------------------------------------------------------- one rep


def run_rep(stack, item, scenario, steps, rep_dir, digest, k6_cores):
    rep_dir.mkdir(parents=True, exist_ok=True)
    stack.env["OUT_DIR"] = str(rep_dir)
    stack.down()
    up = stack.up()
    if up.returncode != 0 or not wait_healthy(stack):
        logs = stack.logs()
        stack.down()
        return {"status": "unhealthy", "error": (up.stderr or "")[-2000:] + logs[-2000:]}
    time.sleep(5)  # let start-up work (JIT, pools, build leftovers) settle

    if scenario in manifest.DB_SCENARIOS:
        seed = stack.k6("seed.js", SEED_ROWS=slo.SEED_ROWS)
        if seed.returncode != 0:
            logs = stack.logs()
            stack.down()
            return {"status": "error", "error": "seeding failed: " + (seed.stdout + seed.stderr)[-2000:] + logs[-1000:]}

    sampler = Sampler(PROJECT)
    sampler.start()
    t0 = time.time()
    stack.k6(f"{scenario}.js", RATE=steps[0], DURATION=f"{slo.WARMUP_SECONDS}s", SEED_ROWS=slo.SEED_ROWS)

    rows = []

    def do_step(rate, refine=False):
        start = time.time()
        res = stack.k6(
            f"{scenario}.js",
            out_name=f"k6-{rate:05d}.json",
            RATE=rate,
            DURATION=f"{slo.STEP_SECONDS}s",
            SEED_ROWS=slo.SEED_ROWS,
        )
        end = time.time()
        summary_path = rep_dir / f"k6-{rate:05d}.json"
        summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
        row = slo.step_from_k6(rate, slo.STEP_SECONDS, summary)
        # Skip the first 3 s of each step for resource averages (k6 start-up).
        usage = sampler.window(start + 3, end)
        row["app_cpu"] = usage.get("app", {}).get("cpu")
        row["app_mem_mb"] = usage.get("app", {}).get("mem_mb")
        row["db_cpu"] = usage.get("db", {}).get("cpu")
        row["db_mem_mb"] = usage.get("db", {}).get("mem_mb")
        row["k6_cpu"] = usage.get("k6", {}).get("cpu", 0.0)
        row["k6_bound"] = slo.k6_bound(row["k6_cpu"], k6_cores)
        row["refine"] = refine
        row["k6_exit"] = res.returncode
        row["start_s"] = round(start - t0, 1)
        row["end_s"] = round(end - t0, 1)
        row["pass"] = slo.passes(row)
        rows.append(row)
        log(
            f"    {rate:>6} rps -> {row['achieved_rps']:>8.0f} achieved, p99 {row['p99_ms']:7.1f} ms, "
            f"err {row['error_rate']:.2%}, app cpu {row['app_cpu'] or 0:5.0f}% "
            f"{'PASS' if row['pass'] else 'FAIL'}"
        )
        return row["pass"]

    for rate in steps:
        if not do_step(rate):
            break
    mid = slo.refine_rate(rows)
    if mid:
        do_step(mid, refine=True)
    sampler.stop()
    stack.down()

    rows.sort(key=lambda r: r["target_rps"])
    write_csv(rep_dir / "steps.csv", rows)
    write_timeseries(rep_dir / "timeseries.csv", sampler.samples, t0)
    return {"status": "ok", "image_digest": digest}


def write_csv(path, rows):
    if not rows:
        return
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


def write_timeseries(path, samples, t0):
    """One row per second per role: t, role, cpu, mem_mb."""
    buckets = {}
    for t, role, cpu, mem in samples:
        if t < t0:
            continue
        key = (int(t - t0), role)
        b = buckets.setdefault(key, [0.0, 0.0, 0])
        b[0] += cpu
        b[1] += mem
        b[2] += 1
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["t", "role", "cpu", "mem_mb"])
        for (sec, role), (cpu, mem, n) in sorted(buckets.items()):
            w.writerow([sec, role, round(cpu / n, 2), round(mem / n, 2)])


# ---------------------------------------------------------------- smoke


def smoke(item, cpus):
    stack = Stack(item, cpus)
    log(f"smoke {item.key}: build")
    b = stack.build()
    if b.returncode != 0:
        print(b.stdout[-3000:], b.stderr[-3000:])
        return False
    stack.down()
    stack.up()
    ok = wait_healthy(stack)
    checks = []
    if ok:
        base = f"http://127.0.0.1:{PORT}"

        rpc = item.api_style in ("serverpod_rpc", "foam_rpc")

        def op(name, arg=None):
            """The four benchmark operations, in the backend's API style."""
            if item.api_style == "foam_rpc":
                _, body = foam_rpc.request(name, arg)
                return foam_rpc.unwrap(*call("POST", foam_rpc.PATH, body, foam_rpc.HEADERS))
            if rpc:
                body = {
                    "no_db": {},
                    "create": {"note": arg},
                    "list": arg,
                    "get": {"id": arg},
                }[name]
                method = {"no_db": "noDbEndpoint", "create": "createNote", "list": "getNotes", "get": "getNote"}[name]
                return call("POST", f"/note/{method}", body)
            if name == "no_db":
                return call("GET", "/no_db_endpoint/")
            if name == "create":
                return call("POST", "/notes/", arg)
            if name == "list":
                return call("GET", f"/notes/?limit={arg['limit']}&offset={arg['offset']}")
            return call("GET", f"/notes/{arg}")

        def call(method, path, body=None, headers=None):
            data = json.dumps(body).encode() if body is not None else None
            req = urllib.request.Request(base + path, data=data, method=method, headers=headers or {"Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=5) as r:
                    return r.status, r.read().decode(errors="replace")
            except urllib.error.HTTPError as e:
                return e.code, e.read().decode(errors="replace")
            except OSError as e:
                return 0, str(e)

        checks.append(("no_db", op("no_db"), {200}))
        if item.scenarios != ["no_db"]:
            checks.append(("create", op("create", {"title": "t", "content": "c"}), {200, 201}))
            checks.append(("create", op("create", {"title": "t2", "content": "c2"}), {200, 201}))
            list_res = op("list", {"limit": 1, "offset": 1})
            checks.append(("list limit=1 offset=1", list_res, {200}))
            try:
                rows = json.loads(list_res[1])
                paged_ok = isinstance(rows, list) and len(rows) == 1 and rows[0].get("title") == "t2"
            except (ValueError, AttributeError, KeyError, IndexError):
                paged_ok = False
            checks.append(("paging returns 1 row, the 2nd note", (200 if paged_ok else 0, list_res[1][:200]), {200}))
            checks.append(("get id=1", op("get", 1), {200}))
            if not rpc:  # RPC returns null with 200 for a missing row
                checks.append(("get missing -> 404", op("get", 999999), {404}))
            elif item.api_style == "foam_rpc":
                status, body = op("get", 999999)
                checks.append(("get missing -> null", (status if body == "null" else 0, body), {200}))
    else:
        print(stack.logs())
    stack.down()
    all_ok = ok and all(res[0] in want for _, res, want in checks)
    for name, (status, body), want in checks:
        mark = "ok " if status in want else "BAD"
        log(f"  {mark} {name}: {status} {body[:120]!r}")
    log(f"smoke {item.key}: {'PASS' if all_ok else 'FAIL'}")
    return all_ok


# ---------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--only", help="comma-separated substrings of backend path/key, e.g. go/mux,python")
    ap.add_argument("--scenario", help="comma-separated scenarios (default: all the backend supports)")
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--steps", help="override load steps, e.g. 250,500")
    ap.add_argument("--run-id", help="append to / resume this run id")
    ap.add_argument("--force", action="store_true", help="ignore the cross-run cache")
    ap.add_argument("--smoke", action="store_true", help="build, start and check every endpoint; no load")
    ap.add_argument("--list", action="store_true", help="list discovered backends")
    ap.add_argument("--contributor", help="optional name or handle stored in run.json")
    args = ap.parse_args()

    items = manifest.filter_items(manifest.load_items(ROOT), args.only)
    if not items:
        sys.exit("no backends matched")
    if args.list:
        for i in items:
            print(f"{i.key:32} {i.path:28} db={i.variant.db} scenarios={','.join(i.scenarios)}")
        return
    if args.smoke:
        cpus = docker_cpusets()
        results = {i.key: smoke(i, cpus) for i in items}
        failed = [k for k, ok in results.items() if not ok]
        print("\nsmoke:", "all passed" if not failed else "FAILED: " + ", ".join(failed))
        sys.exit(1 if failed else 0)

    steps = [int(s) for s in args.steps.split(",")] if args.steps else slo.STEPS
    wanted = set(args.scenario.split(",")) if args.scenario else None
    cpus = docker_cpusets()
    run_dir, run_meta = new_run(args.run_id, steps, args.reps, cpus, args.contributor)
    cpus = run_meta["params"]["cpusets"]  # a resumed run keeps its original split
    run_json = run_dir / "run.json"

    for item in items:
        entry = run_meta["items"].setdefault(item.key, {"scenarios": {}})
        entry.update(
            name=item.manifest.get("name", item.key),
            path=item.path,
            language=item.manifest.get("language"),
            framework=item.manifest.get("framework"),
            version=item.manifest.get("version"),
            runtime=item.manifest.get("runtime"),
            variant=item.variant.id,
            db=item.variant.db,
            pgbouncer=item.variant.pgbouncer,
            api_style=item.api_style,
            notes=item.manifest.get("notes"),
        )
        stack = Stack(item, cpus)
        log(f"== {item.key}: build")
        b = stack.build()
        if b.returncode != 0:
            entry["status"] = "build_failed"
            entry["error"] = (b.stdout + b.stderr)[-3000:]
            write_json(run_json, run_meta)
            log(f"   build failed, skipping {item.key}")
            continue
        digest = stack.image_digest()
        entry["status"] = "ok"
        entry["image_digest"] = digest
        write_json(run_json, run_meta)  # visible to the report while running
        for scenario in item.scenarios:
            if wanted and scenario not in wanted:
                continue
            sentry = entry["scenarios"].setdefault(scenario, {})
            if not args.force:
                src = cached_from(run_meta, item.key, scenario, digest, args.reps)
                if src:
                    sentry.update(status="cached", **{"from": src})
                    write_json(run_json, run_meta)
                    log(f"   {scenario}: cached from {src}")
                    continue
            for rep in range(1, args.reps + 1):
                rep_dir = run_dir / item.key / scenario / f"rep-{rep}"
                if rep_done(rep_dir):
                    log(f"   {scenario} rep {rep}: already done")
                    continue
                log(f"   {scenario} rep {rep}/{args.reps}")
                result = run_rep(stack, item, scenario, steps, rep_dir, digest, cpus["k6_cores"])
                result.update(
                    finished_at=dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
                    framework_version=item.manifest.get("version"),
                    runtime=item.manifest.get("runtime"),
                )
                write_json(rep_dir / "meta.json", result)
                sentry.update(status="running")
                write_json(run_json, run_meta)
                if result["status"] != "ok":
                    log(f"   {scenario} rep {rep}: {result['status']}")
            done = sum(rep_done(run_dir / item.key / scenario / f"rep-{r}") for r in range(1, args.reps + 1))
            sentry.update(status="ok" if done == args.reps else "incomplete", reps=done)
            write_json(run_json, run_meta)

    run_meta["finished_at"] = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    write_json(run_json, run_meta)
    log("report")
    subprocess.run([sys.executable, str(BENCH / "report" / "report.py")], check=False)


if __name__ == "__main__":
    main()
