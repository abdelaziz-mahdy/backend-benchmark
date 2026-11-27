"""Load steps, the SLO rule, and per-rep / per-scenario summaries.

Shared by the runner (deciding when to stop stepping) and the report
(computing headline numbers), so both apply exactly the same rule.
"""
import statistics

# v3: vegeta replaces k6 for the load steps (k6 added 10 ms or more to p99
# from 20,000 requests/s and topped out near 48,000), and the ladder ends at
# 80,000, the most vegeta sends cleanly on 4 cores.
METHODOLOGY = "v3"
STEPS = [250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 80000]
STEP_SECONDS = 30
WARMUP_SECONDS = 30
SEED_ROWS = 10000
SLO_P99_MS = 100.0
SLO_ERROR_RATE = 0.01
SLO_ACHIEVED_RATIO = 0.95
SPREAD_FLAG = 0.10
# After the first failing step, binary-search between the highest passing and
# lowest failing rate: at most REFINE_STEPS probes, stopping once the gap is
# below REFINE_TOLERANCE of the passing rate (v2 tested a single midpoint).
REFINE_STEPS = 4
REFINE_TOLERANCE = 0.06
# Reps after the first skip doubling steps below 1/START_FRACTION of the
# first rep's result: they always pass and only cost time. The two or three
# steps kept below the result still warm the app up.
START_FRACTION = 4
# A step that fails only on p99 while nine in ten replies stayed under this
# share of the limit is run once more: the app kept up and a short pause
# (garbage collection, a checkpoint) made the slowest 1%, not the load. In
# the 2026-11-20 run such one-off pauses ended 49 of 252 reps far below the
# other two (e.g. .NET db_write: 7,750 vs 13,500 and 17,000).
NEAR_MISS_P90_RATIO = 0.5
# Above this share of its cores, k6 may be the bottleneck rather than the app.
LOADGEN_BOUND_SHARE = 0.75


def step_from_k6(target_rps, duration_s, summary):
    """Turn a k6 --summary-export dict into one step row."""
    metrics = summary.get("metrics", {})
    dur = metrics.get("http_req_duration", {})
    reqs = metrics.get("http_reqs", {}).get("count", 0)
    failed = metrics.get("http_req_failed", {})
    # RPC styles whose framework answers errors with HTTP 200 (foam_rpc) count
    # those replies in the "rpc_failed" Rate (true only for 2xx error replies,
    # so nothing is counted twice); see scenarios/lib.js.
    rpc_failed = metrics.get("rpc_failed", {}).get("passes", 0)
    dropped = metrics.get("dropped_iterations", {}).get("count", 0)
    return {
        "target_rps": target_rps,
        "achieved_rps": reqs / duration_s if duration_s else 0.0,
        "requests": reqs,
        "dropped": dropped,
        "error_rate": min(1.0, float(failed.get("value", 0.0)) + rpc_failed / reqs) if reqs else 1.0,
        "p50_ms": dur.get("p(50)", 0.0),
        "p90_ms": dur.get("p(90)", 0.0),
        "p99_ms": dur.get("p(99)", 0.0),
        "p999_ms": dur.get("p(99.9)", 0.0),
        "avg_ms": dur.get("avg", 0.0),
    }


def step_from_vegeta(target_rps, duration_s, summary):
    """Turn the load generator's step summary (loadgen/summary) into one step
    row with the same keys as step_from_k6. vegeta never drops a request: when
    it falls behind it sends fewer, so dropped is what it did not send."""
    reqs = summary.get("requests", 0)
    lat = summary.get("latency_ms", {})
    failed = reqs - summary.get("success", 0) + summary.get("rpc_failed", 0)
    return {
        "target_rps": target_rps,
        "achieved_rps": reqs / duration_s if duration_s else 0.0,
        "requests": reqs,
        "dropped": max(0, round(target_rps * duration_s) - reqs),
        "error_rate": min(1.0, failed / reqs) if reqs else 1.0,
        "p50_ms": lat.get("p50", 0.0),
        "p90_ms": lat.get("p90", 0.0),
        "p99_ms": lat.get("p99", 0.0),
        "p999_ms": lat.get("p999", 0.0),
        "avg_ms": lat.get("mean", 0.0),
    }


def k6_bound(k6_cpu, k6_cores):
    """True when k6 used nearly all of its cores during a step."""
    return bool(k6_cpu) and k6_cpu >= LOADGEN_BOUND_SHARE * 100.0 * k6_cores


def passes(step):
    """True when the step meets the SLO. A boundary value counts as a fail."""
    return (
        step["requests"] > 0
        and step["p99_ms"] < SLO_P99_MS
        and step["error_rate"] < SLO_ERROR_RATE
        and step["achieved_rps"] >= SLO_ACHIEVED_RATIO * step["target_rps"]
    )


def near_miss(step):
    """True when a failed step met every limit except p99 and its p90 stayed
    under NEAR_MISS_P90_RATIO of the p99 limit: a pause, worth one more try.
    Real overload slows most replies, so its p90 is high too."""
    return (
        not passes(step)
        and step["requests"] > 0
        and step["error_rate"] < SLO_ERROR_RATE
        and step["achieved_rps"] >= SLO_ACHIEVED_RATIO * step["target_rps"]
        and step.get("p90_ms", 0.0) < NEAR_MISS_P90_RATIO * SLO_P99_MS
    )


def refine_rate(steps, tolerance=REFINE_TOLERANCE):
    """Next probe: midpoint between the highest passing and lowest failing
    rate, rounded to 50 rps. None when there is no bracket (all pass, all
    fail, or noise made a lower rate fail after a higher one passed), when
    the bracket is already narrower than tolerance, or when rounding lands
    on an already-tested rate."""
    passing = [s["target_rps"] for s in steps if s["pass"]]
    failing = [s["target_rps"] for s in steps if not s["pass"]]
    if not passing or not failing:
        return None
    lo, hi = max(passing), min(failing)
    if hi <= lo or (hi - lo) / lo < tolerance:
        return None
    mid = int(round((lo + hi) / 2 / 50.0) * 50)
    tested = {s["target_rps"] for s in steps}
    return mid if lo < mid < hi and mid not in tested else None


def start_steps(steps, known_best):
    """The doubling steps a rep climbs, given an earlier rep's sustainable
    rate (0 or None: climb them all)."""
    if not known_best:
        return list(steps)
    return [s for s in steps if s >= known_best / START_FRACTION] or list(steps)


def summarize_rep(steps):
    """Headline numbers for one rep. steps must already carry "pass"."""
    passing = [s for s in steps if s["pass"]]
    best = max(passing, key=lambda s: s["target_rps"]) if passing else None
    peak = max((s["achieved_rps"] for s in steps), default=0.0)
    out = {
        "sustainable_rps": best["target_rps"] if best else 0,
        "peak_rps": peak,
        "loadgen_bound": any(s.get("k6_bound", False) for s in steps),
    }
    keys = ["p50_ms", "p90_ms", "p99_ms", "p999_ms", "error_rate", "app_cpu", "app_mem_mb", "db_cpu", "db_mem_mb"]
    for k in keys:
        out[k] = best.get(k) if best else None
    return out


def aggregate(reps):
    """Median across reps with min/max, plus a spread flag on the headline."""
    if not reps:
        return {}
    out = {"reps": len(reps)}
    for key in reps[0]:
        values = [r[key] for r in reps if r.get(key) is not None]
        if key == "loadgen_bound":
            out[key] = any(values)
            continue
        if not values:
            out[key] = None
            continue
        out[key] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
    head = out.get("sustainable_rps")
    if head and head["median"]:
        out["spread"] = (head["max"] - head["min"]) / head["median"]
    else:
        out["spread"] = 0.0
    out["unstable"] = out["spread"] > SPREAD_FLAG
    return out


def median_rep_index(reps):
    """Index of the rep whose sustainable rps is the median (for charts)."""
    order = sorted(range(len(reps)), key=lambda i: (reps[i]["sustainable_rps"], reps[i]["peak_rps"]))
    return order[len(order) // 2] if order else None
