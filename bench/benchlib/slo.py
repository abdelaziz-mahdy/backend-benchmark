"""Load steps, the SLO rule, and per-rep / per-scenario summaries.

Shared by the runner (deciding when to stop stepping) and the report
(computing headline numbers), so both apply exactly the same rule.
"""
import statistics

METHODOLOGY = "v2"
STEPS = [250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000]
STEP_SECONDS = 30
WARMUP_SECONDS = 30
SEED_ROWS = 10000
SLO_P99_MS = 100.0
SLO_ERROR_RATE = 0.01
SLO_ACHIEVED_RATIO = 0.95
SPREAD_FLAG = 0.10
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


def refine_rate(steps):
    """Midpoint between the last passing and first failing rate, or None."""
    passing = [s["target_rps"] for s in steps if s["pass"]]
    failing = [s["target_rps"] for s in steps if not s["pass"]]
    if not passing or not failing:
        return None
    lo, hi = max(passing), min(failing)
    if hi <= lo:
        return None
    mid = int(round((lo + hi) / 2 / 50.0) * 50)
    return mid if lo < mid < hi else None


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
