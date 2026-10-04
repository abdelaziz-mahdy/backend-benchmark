# Planned work: finer load-step search (methodology v2.1)

Date: 2026-10-04 · Status: in progress (PR 6 of the v2 stack)

## Problem

The first full v2 run (`2026-10-04_m2pro-10c-32g_bff6922_0461`, PR #21) reports
sustainable load with coarse resolution. Load doubles per step (250 → 64k rps)
and after the first failing step the runner tests **one** midpoint, so results
land on a handful of values:

| Values seen (db scenarios) | Frameworks |
|---|---|
| 16.0k | asp.net core, go mux, spring boot, rust (db_write) |
| 24.0k | asp.net core, go mux, spring boot, express (node), db_read |
| 32.0k | express (bun), rust actix-web (db_read) |

The true limit of a framework that shows 16k can be anywhere in 16k–24k, so
two frameworks up to ~50% apart can tie, and a real 10% difference is invisible.

## Goal

Report sustainable load to within ~6% without making a run much longer, so
the leaderboard separates frameworks that really differ.

Out of scope: the `no_db` top tier, which is capped by the load generator on a
10-core laptop (k6 tops out ~57k rps). Finer search reports that cap more
precisely but cannot lift it; the `load-gen limit` flag stays.

## Design

1. Keep the doubling steps (cheap way to find the bracket).
2. After the first failing step, run a bounded binary search between the
   highest passing and the lowest failing rate:
   - at most `REFINE_STEPS = 4` 30 s probes (today: 1);
   - stop early when `(fail - pass) / pass < REFINE_TOLERANCE = 0.06`;
   - midpoints rounded to 50 rps; a midpoint equal to either bound stops it.
   Each probe halves the bracket: from a 2x gap, 4 probes leave at most
   6.25% between the reported value and the first failing rate.
3. Noise: if a lower rate fails after a higher one passed, the bracket is
   empty (`fail <= pass`) and the search stops; the reported value stays the
   highest passing step, as today.
4. Methodology becomes `v2.1`. The dashboard never joins different methods
   in History, the "latest" view is per machine + method, and the skip cache
   never reuses v2 results for a v2.1 run.

Implementation: `bench/benchlib/slo.py` (`REFINE_STEPS`, `REFINE_TOLERANCE`,
`refine_rate` with tolerance), `bench/bench.py` (loop instead of one probe),
unit tests in `bench/tests/test_slo.py`, docs (`bench/README.md`, spec,
dashboard Method tab text).

## Cost

+3 probes (90 s) per rep in the common case: ~5.5 → ~7 min per rep.
Full suite (12 backend variants × 4 scenarios × 3 reps = 144 reps): ~17 h.

## Rollout

1. Implement + unit tests (no machine load).
2. Verify on one backend with a short real run (after the FOAM v2 run ends).
3. Re-run all 12 variants with `--force` on a quiet machine; commit the run
   folder to this PR.
4. v2 results (PR #21/#22) stay as history; the dashboard defaults to the
   newest method's "latest" view.

## Acceptance

- Unit tests cover: bracket narrowing, early stop at tolerance, empty bracket,
  all-pass, all-fail, rounding never repeating a tested rate.
- A real rep shows up to 4 refine steps and a sustainable value that is not
  one of the doubling steps or the old single midpoint.
- Full re-run: 144/144 reps OK, `report.py --check` clean, fewer exact ties
  than v2 in the DB scenarios.
