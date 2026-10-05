from benchlib import slo


def step(target, p99=10.0, err=0.0, achieved=None, requests=100, k6_bound=False):
    s = {
        "target_rps": target,
        "achieved_rps": target if achieved is None else achieved,
        "requests": requests,
        "error_rate": err,
        "p50_ms": 1.0,
        "p90_ms": 2.0,
        "p99_ms": p99,
        "p999_ms": p99 * 2,
        "app_cpu": 150.0,
        "app_mem_mb": 100.0,
        "db_cpu": None,
        "db_mem_mb": None,
        "k6_bound": k6_bound,
    }
    s["pass"] = slo.passes(s)
    return s


def test_step_from_k6_reads_summary_export():
    summary = {
        "metrics": {
            "http_req_duration": {"avg": 3, "p(50)": 2, "p(90)": 4, "p(99)": 9, "p(99.9)": 20},
            "http_reqs": {"count": 2970},
            "http_req_failed": {"value": 0.002},
            "dropped_iterations": {"count": 30},
        }
    }
    s = slo.step_from_k6(100, 30, summary)
    assert s["achieved_rps"] == 99
    assert s["p99_ms"] == 9
    assert s["error_rate"] == 0.002
    assert s["dropped"] == 30


def test_rpc_error_replies_count_as_errors():
    summary = {
        "metrics": {
            "http_reqs": {"count": 1000},
            "http_req_failed": {"value": 0.01, "passes": 10, "fails": 990},
            "rpc_failed": {"value": 0.02, "passes": 20, "fails": 980},
        }
    }
    assert abs(slo.step_from_k6(100, 10, summary)["error_rate"] - 0.03) < 1e-9


def test_no_requests_is_full_error_and_fails():
    s = slo.step_from_k6(100, 30, {"metrics": {}})
    assert s["error_rate"] == 1.0
    assert not slo.passes(s)


def test_slo_boundaries_fail():
    assert slo.passes(step(100, p99=99.9))
    assert not slo.passes(step(100, p99=100.0))
    assert not slo.passes(step(100, err=0.01))
    assert slo.passes(step(100, achieved=95))
    assert not slo.passes(step(100, achieved=94.9))


def test_refine_midpoint_rounded_to_50():
    steps = [step(1000), step(2000), step(4000, p99=500)]
    assert slo.refine_rate(steps) == 3000
    assert slo.refine_rate([step(250), step(500, p99=500)]) == 400  # 375 rounds to 400
    assert slo.refine_rate([step(250)]) is None
    assert slo.refine_rate([step(250, p99=500)]) is None


def test_all_steps_fail_gives_zero_not_crash():
    rep = slo.summarize_rep([step(250, p99=500)])
    assert rep["sustainable_rps"] == 0
    assert rep["p99_ms"] is None
    assert rep["peak_rps"] == 250


def test_summarize_picks_highest_passing_and_peak():
    rep = slo.summarize_rep([step(1000), step(2000, p99=50), step(4000, p99=300, achieved=3000)])
    assert rep["sustainable_rps"] == 2000
    assert rep["p99_ms"] == 50
    assert rep["peak_rps"] == 3000


def test_loadgen_bound_flag():
    assert slo.summarize_rep([step(1000, k6_bound=True)])["loadgen_bound"]
    assert not slo.summarize_rep([step(1000)])["loadgen_bound"]
    assert slo.k6_bound(370, 4)
    assert not slo.k6_bound(290, 4)
    assert not slo.k6_bound(None, 4)


def test_aggregate_median_and_spread():
    reps = [slo.summarize_rep([step(r)]) for r in (1000, 1000, 2000)]
    agg = slo.aggregate(reps)
    assert agg["sustainable_rps"] == {"median": 1000, "min": 1000, "max": 2000}
    assert agg["spread"] == 1.0
    assert agg["unstable"]
    assert agg["db_cpu"] is None


def test_median_rep_index():
    reps = [{"sustainable_rps": 3, "peak_rps": 0}, {"sustainable_rps": 1, "peak_rps": 0}, {"sustainable_rps": 2, "peak_rps": 0}]
    assert slo.median_rep_index(reps) == 2


def simulate(true_limit, steps=slo.STEPS):
    """Run the runner's search (doubling, then bounded bisection) against a
    backend that passes every rate <= true_limit."""
    rows = []
    for rate in steps:
        rows.append(step(rate, p99=10 if rate <= true_limit else 500))
        if not rows[-1]["pass"]:
            break
    probes = 0
    for _ in range(slo.REFINE_STEPS):
        mid = slo.refine_rate(rows)
        if not mid:
            break
        probes += 1
        rows.append(step(mid, p99=10 if mid <= true_limit else 500))
    return slo.summarize_rep(rows)["sustainable_rps"], probes, rows


def test_bisection_reports_within_tolerance():
    for limit in [300, 777, 1234, 5000, 11000, 17500, 23999, 30000, 47000]:
        found, probes, rows = simulate(limit)
        assert found <= limit
        assert probes <= slo.REFINE_STEPS
        assert (limit - found) / limit <= 0.0625 + 0.01, (limit, found)
        rates = [r["target_rps"] for r in rows]
        assert len(rates) == len(set(rates)), "a rate was tested twice"


def test_refine_stops_when_bracket_is_tight():
    rows = [step(10000), step(10500, p99=500)]
    assert slo.refine_rate(rows) is None  # 5% < 6% tolerance
    assert slo.refine_rate(rows, tolerance=0.01) == 10250


def test_refine_stops_on_empty_bracket_from_noise():
    # 4000 passed, then a probe at 3000 failed: no valid bracket left.
    rows = [step(2000), step(4000), step(8000, p99=500), step(3000, p99=500)]
    assert slo.refine_rate(rows) is None


def test_refine_never_repeats_a_tested_rate():
    rows = [step(250), step(300, p99=500), step(275, p99=500)]
    # bracket 250..275 is 10% wide; midpoint rounds to 250 or 300 -> stop
    assert slo.refine_rate(rows) is None


def test_methodology_is_v21():
    assert slo.METHODOLOGY == "v2.1"


def test_first_rep_climbs_every_step():
    assert slo.start_steps(slo.STEPS, 0) == slo.STEPS
    assert slo.start_steps(slo.STEPS, None) == slo.STEPS


def test_later_reps_skip_steps_far_below_the_first_result():
    # 23k sustained: start at 8k, keeping 8k and 16k as warm passing steps.
    assert slo.start_steps(slo.STEPS, 23000) == [8000, 16000, 32000, 64000]
    # exactly on a step: that quarter is kept
    assert slo.start_steps(slo.STEPS, 16000) == [4000, 8000, 16000, 32000, 64000]


def test_low_results_keep_the_whole_ladder():
    assert slo.start_steps(slo.STEPS, 1000) == slo.STEPS
