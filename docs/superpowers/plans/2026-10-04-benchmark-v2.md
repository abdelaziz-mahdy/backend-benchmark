# Benchmark v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the repo around backend manifests and append-only results, replace Locust with a k6 step-load methodology, bump every backend, add FOAM3 (embedded + postgres), and refactor the dashboard onto the new data.

**Architecture:** Each backend is `backend.yaml` + `app/`. A single `bench/run.sh` discovers manifests, starts a shared compose stack (`db`, `benchmark`, `k6`) with pinned CPUs, runs k6 scenarios step by step, and writes raw CSV/JSON into `results/runs/<run_id>/`. `bench/report/report.py` builds `summary.json` per run and `results/index.json`; the Flutter app reads those.

**Tech Stack:** bash, Docker Compose, k6 (JS), Python 3 stdlib (report, no pandas), Flutter web + fl_chart + provider.

**Spec:** `docs/superpowers/specs/2026-10-04-benchmark-v2-design.md`

## Global Constraints

- SLO: p99 < 100 ms, error rate < 1%, achieved ≥ 95% of target rps.
- Steps: 250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000 rps; 30 s each; 30 s warmup; one midpoint refine step.
- Reps: 3; report median, keep min/max.
- cpusets: benchmark `0-1` (2 GB), db `2-3` (2 GB), k6 `4-7`.
- Seed 10,000 notes before every DB scenario; paged reads `limit=20`.
- Endpoints: `GET /health`, `GET /no_db_endpoint/`, `POST /notes/`, `GET /notes/?limit=&offset=`, `GET /notes/{id}`; port 8000.
- Results are append-only; nothing under `results/legacy/` is edited after the move.
- `run_id` = `<YYYY-MM-DD>_<machine-slug>_<git-short-sha>`.
- Flutter: `dart format` + `flutter analyze` + `flutter test` over the whole app before every push.
- Stacked PRs, none merged.

## Review Focus

1. A backend whose build fails must not abort the whole suite: runner logs it, records `status: build_failed` in the run, continues. (Task 2.3 test.)
2. A backend that never passes the first step (250 rps) gets `sustainable_rps: 0`, not a crash or missing key. (Task 2.4 test.)
3. Rerunning the suite on the same machine/sha must append reps or skip via cache, never overwrite a finished run directory. (Task 2.3 test.)
4. Dashboard with a run missing a scenario for some backend (e.g. FOAM embedded has no postgres CPU) must render "—", not throw. (Task 5.2 test.)
5. Legacy v1 runs and v2 runs must never be joined in the same History series. (Task 5.4 test.)

---

## PR 1 — `restructure` (base: main)

### Task 1.1: Move legacy results

**Files:** move `backends/*/*/tests/results/{db_test,no_db_test}/*` → `results/legacy/<lang>-<framework>/{db_test,no_db_test}/`; `results_data.json` → `results/legacy/results_data_2024.json`; copy `benchmark-app/assets/data.json` → `results/legacy/summary_v1.json`.

- [ ] `git mv` each directory (keeps history). Verify file count before/after equal (125 files).
- [ ] Write `results/legacy/README.md`: methodology v1 (Locust, 10k users ramp over 120 s, 1 CPU, unbounded `GET /notes/`), not comparable with v2.
- [ ] Commit `refactor: move v1 results into results/legacy`.

### Task 1.2: Manifests + `app/` rename

**Files:** create `backends/<lang>/<fw>/backend.yaml` for 10 backends; `git mv` source dirs → `app/`:
- go/mux `src`→`app`; rust/actix-web root files (`Cargo.toml`, `Dockerfile`, `src`, `migration.sql`)→`app/`;
- javascript/express-{node,bun} root files→`app/`; python/fast-api `app` stays; django-{sync,async} `benchmark`→`app`;
- c_sharp/dot-net `benchmark`→`app` (delete `obj/`); java/spring-boot `server`→`app`;
- dart/server-pod `benchmark_server`→`app` (client/flutter folders stay).

- [ ] Delete per-backend `docker-compose.y*ml`, `docker_build_and_run.sh`, `tests/`, empty `results/`, `workflow.yml`.
- [ ] Each Docker build still works: `docker build backends/<x>/app` for all 10 (smoke in PR 2).
- [ ] Commit `refactor: one app/ dir and backend.yaml per backend`.

### Task 1.3: Remove old scripts + docs

- [ ] Delete `internal_scripts/`, `scripts/start_tests.sh`, `scripts/graphs/`, `README_template.md`, root graph PNGs (none tracked now), `scripts/version_benchmark.sh` (serverpod-only, paths obsolete).
- [ ] Keep `scripts/cleaning/clean_docker_space.sh`; drop `delete_results.sh` (results append-only).
- [ ] Update `CLAUDE.md`, `Contribution.md`, `README.md` for the new layout (runner lands in PR 2; say so).
- [ ] Commit, push, open PR 1.

## PR 2 — `bench-v2` (base: restructure)

### Task 2.1: Shared compose + lib

**Files:** `bench/compose.yaml`, `bench/lib/{health.sh,seed.sh,stats.sh,machine.sh}`, `bench/sql/schema.sql`.

`compose.yaml` services: `db` (postgres:18, cpuset 2-3, profile `postgres`), `benchmark` (build `${APP_DIR}`, cpuset 0-1, mem 2g, env `DATABASE_*`), `k6` (grafana/k6, cpuset 4-7, network host-less, mounts `bench/scenarios` and the rep output dir).
`schema.sql`: `CREATE TABLE IF NOT EXISTS notes(id SERIAL PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL)` — backends with ORM migrations keep theirs; runner seeds via `psql` with `generate_series`.

### Task 2.2: k6 scenarios

**Files:** `bench/scenarios/{lib.js,no_db.js,db_read.js,db_write.js,db_mixed.js}`.
Each script reads `__ENV.RATE`, `__ENV.DURATION`, uses `constant-arrival-rate`, `preAllocatedVUs: min(RATE, 2000)`, `maxVUs: 10000`, `--summary-export` JSON. `db_read`: 50% paged list, 50% by id (random in 1..10000). `db_mixed`: 80% read (same split) / 20% `POST`.

### Task 2.3: `bench/run.sh`

Interfaces: `bench/run.sh [--only a,b] [--scenario s] [--reps n] [--force] [--smoke] [--run-id id]`.
Flow per (backend, variant, scenario, rep): build → up → health (120 s) → seed → warmup → steps (stop on first SLO fail) → refine → write `steps.csv`, `timeseries.csv`, `meta.json` → down -v.
Writes `run.json` at start (machine via `machine.sh`, docker version, methodology `v2`, params). Status per item: `ok | build_failed | unhealthy | error`.
- [ ] Test (bats-free, bash): `bench/tests/test_runner.sh` uses a stub backend (`bench/tests/fixtures/echo` tiny Go app or `nginx` static) with `--reps 1 --scenario no_db` and steps capped via `STEPS=250,500` env; asserts files exist and status ok.
- [ ] Test: broken Dockerfile fixture → status `build_failed`, suite continues (Review Focus 1).
- [ ] Test: rerun same run-id → existing rep dirs untouched, skipped (Review Focus 3).

### Task 2.4: Report

**Files:** `bench/report/report.py`, `bench/report/test_report.py`.
`summarize_rep(steps) -> {sustainable_rps, peak_rps, p50, p90, p99, p999, error_rate, cpu, mem, db_cpu}`; `aggregate(reps) -> median + min/max + spread`; `build_run_summary(run_dir) -> summary.json`; `build_index(results_dir) -> index.json` (legacy included as run `legacy-v1`, methodology `v1`).
- [ ] pytest: SLO boundary (p99 = 100 → fail), all-fail → 0 (Review Focus 2), median of 3, spread flag > 10%.
- [ ] Copies `index.json` + run summaries to `benchmark-app/assets/results/`.

### Task 2.5: New endpoints in all 10 backends

For each backend: `/health`, paged `GET /notes/`, `GET /notes/{id}`; keep `POST`, `/no_db_endpoint/`. One commit per language. `bench/run.sh --smoke` passes for each.

- [ ] Open PR 2.

## PR 3 — `bump-backends` (base: bench-v2)

### Task 3.1–3.10: one per backend

Latest stable framework + runtime + base image; idiomatic multi-core production mode for 2 cores. Update `backend.yaml` `version`/`runtime`. `--smoke` passes. One commit each.

### Task 3.11: Full v2 run

- [ ] `bench/run.sh` (all, 3 reps). Commit `results/runs/<run_id>/` + regenerated index. Open PR 3.

## PR 4 — `foam3` (base: bump-backends)

### Task 4.1: Spike
Clone foam-foundation/foam3, build in Docker, confirm a Java handler can serve JSON on :8000 over a `Note` model DAO. Record findings in `backends/java/foam3/README.md`.

### Task 4.2: embedded variant (MDAO + journal) · Task 4.3: postgres variant (JDBC DAO, fallback plain JDBC)
`backend.yaml` with two variants; `--smoke` both.

### Task 4.4: Run FOAM in the same machine/methodology
`bench/run.sh --only java/foam3 --run-id <PR 3 run_id>` appends into the same run. Commit. Open PR 4.

## PR 5 — `dashboard-v3` (base: foam3)

### Task 5.1: Data layer
`models/run.dart` (`RunIndexEntry`, `RunSummary`, `ScenarioResult`), `services/results_service.dart` (loads `assets/results/index.json`, lazy run summary), provider rewritten: selected run, scenario, language filter, compare set (max 4), detail backend. Unit tests on JSON parsing incl. missing fields → null (Review Focus 4).

### Task 5.2: Overview · 5.3: Framework · 5.4: Compare · 5.5: History
Per spec §5. Widget tests: leaderboard sort, missing value renders "—", compare chips disabled at 4, history splits series by `(machine, methodology)` (Review Focus 5).

### Task 5.6: Cleanup
Delete radar, sidebar, winner cards, `dashboard_screen.dart`, old `assets/data.json` + model. Format, analyze, test, build web. Screenshot each tab. Open PR 5.
