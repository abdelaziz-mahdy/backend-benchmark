# Benchmark v2 — structure, methodology, FOAM3, dashboard

Date: 2026-10-04 · Status: draft for review

## Goal

Make the benchmark answer a meaningful question, keep every past result as history,
and make adding/removing a backend a one-folder change.

Headline question: **what is the highest load each framework sustains while
p99 < 100 ms and errors < 1%, and what CPU/memory does it cost?**
Peak throughput is still reported, as a secondary number.

## Decisions (agreed)

| Topic | Decision |
|---|---|
| Structure | Manifest-per-backend, shared runner + scenarios, append-only `results/` |
| History | Never overwrite. Legacy results moved untouched to `results/legacy/` |
| Load generator | k6 (`grafana/k6` container), open-model `constant-arrival-rate` |
| SLO | p99 < 100 ms and error rate < 1% |
| Scenarios | `no_db`, `db_read`, `db_write`, `db_mixed` (80 read / 20 write) |
| DB read fix | Seed 10k rows; paged list + by-id read; constant payload |
| Scope | Restructure, test v2, bump all backends, FOAM3 x2, dashboard refactor |
| Runs | Full suite run unattended on this machine, results committed |
| Delivery | Stacked PRs, none merged until the user approves the whole stack |

## 1. Repository structure

```
backends/<lang>/<framework>/
  backend.yaml          # manifest (below)
  app/                  # source + Dockerfile, build context
bench/
  compose.yaml          # db, benchmark, loadgen; parameterised by env
  scenarios/            # no_db.js, db_read.js, db_write.js, db_mixed.js, lib.js
  run.sh                # entry point
  lib/                  # health wait, seeding, resource sampler, machine fingerprint
  report/               # aggregator → results/index.json + per-run summary.json
results/
  index.json            # all runs: id, date, machine, methodology, backends
  runs/<run_id>/
    run.json            # machine, docker, methodology version, load params
    summary.json        # per backend/variant/scenario aggregates (dashboard input)
    <backend>[-<variant>]/<scenario>/rep-<n>/
      steps.csv         # one row per load step: target rps, achieved rps, p50..p99.9, errors
      timeseries.csv    # per-second rps / latency / cpu / mem
      meta.json         # image digest, framework + runtime versions
  legacy/<backend>/{db_test,no_db_test}/   # old CSVs, unchanged
  legacy/summary.json   # old data.json converted, tagged methodology "v1"
```

`run_id` = `<YYYY-MM-DD>_<machine-slug>_<git-short-sha>`.
Machine slug comes from CPU model + core count + RAM (e.g. `m2pro-10c-32g`).

### backend.yaml

```yaml
name: go mux                 # display name
language: go
framework: gorilla/mux
version: 1.8.1               # framework version (updated with bumps)
runtime: go 1.25
variants:                    # default: [postgres]
  - id: postgres
    db: postgres
  - id: embedded             # FOAM journal variant
    db: none
scenarios: [no_db, db_read, db_write, db_mixed]   # optional override
```

The runner discovers backends by globbing `backends/*/*/backend.yaml`.
Removing a backend = delete its folder; its results stay in `results/`.

### Migration

- `src/`, `app/`, `benchmark/`, `server/`, `benchmark_server/` → `app/` (Serverpod keeps
  its client/flutter folders beside `app/`, untouched).
- Per-backend `docker-compose.yml`, `docker_build_and_run.sh`, `tests/*.py` deleted.
- `internal_scripts/`, `scripts/start_tests.sh`, `scripts/graphs/` replaced by `bench/`.
- Every `tests/results/*` and `backends/dart/relic-*/results` moved to `results/legacy/`.
- Repo-root comparison PNGs and README graph section removed (dashboard replaces them).
- `CLAUDE.md`, `Contribution.md`, README updated.

## 2. Methodology v2

### Resources (Docker VM: 10 CPUs, 12.5 GB)

Pinned with `cpuset`, so services never share cores:

| Service | cpuset | Memory |
|---|---|---|
| benchmark | 0-1 (2 cores) | 2 GB limit |
| db (postgres 18) | 2-3 | 2 GB |
| k6 | 4-7 | — |
| Docker/host | 8-9 | — |

Each backend runs in its idiomatic production mode and must use both cores
(e.g. gunicorn/uvicorn workers, Node cluster, release builds). Configured during the bump.

### API contract (all backends)

| Endpoint | Behaviour |
|---|---|
| `GET /health` | 200 when ready (DB reachable if variant has DB) |
| `GET /no_db_endpoint/` | small static JSON (unchanged) |
| `POST /notes/` | insert `{title, content}`, return created row |
| `GET /notes/?limit=20&offset=N` | ordered by id, at most `limit` rows |
| `GET /notes/{id}` | one row, 404 if missing |

Before DB scenarios the runner truncates `notes` and seeds 10,000 rows via SQL
(or via `POST` for the FOAM embedded variant). Reads pick random offsets/ids in the seeded range.

### Run procedure (per backend × variant × scenario × rep)

1. `compose up`, wait for `/health`, seed if DB scenario.
2. Warmup: 30 s at the first step rate (discarded).
3. Step load, open model (`constant-arrival-rate`): rates 250, 500, 1k, 2k, 4k, 8k,
   16k, 32k, 64k req/s, 30 s each. Stop after the first step that breaks the SLO.
4. Refine: binary search between the last passing and first failing rate, up to
   4 probes of 30 s, stopping when the gap is under 6% (methodology v2.1, see
   `docs/planned-work/2026-10-04-finer-load-search.md`; v2 tested one midpoint).
5. Sample backend + db CPU/memory every second (`docker stats`).
6. `compose down -v`.

Reps: 3. Reported value = median of reps; min/max kept for error bars.

### Metrics per scenario

- **Sustainable rps** (headline): highest step rate with p99 < 100 ms, errors < 1%,
  and achieved rps ≥ 95% of target (k6 dropped iterations count as a miss).
- **Peak rps**: highest achieved rps across steps.
- p50 / p90 / p99 / p99.9 at the sustainable step.
- CPU % and memory MB (avg) at the sustainable step; db CPU too.
- Efficiency: sustainable rps per core, per 100 MB.
- Rep spread (max−min)/median; flagged if > 10%.

### Skip cache

A backend/variant/scenario is skipped if the newest run on the same machine
and methodology already has it with the same image digest. `--force` overrides.

### CLI

```
bench/run.sh                         # everything
bench/run.sh --only go/mux,rust      # glob on path
bench/run.sh --scenario db_read --reps 1 --force
bench/run.sh --smoke                 # health + one request per endpoint, no load
```

## 3. Backend bumps

Each backend gets its latest stable framework, runtime and base image,
plus the new endpoints and `/health`. One commit per backend.
Verified by `--smoke`, then included in the full run.

## 4. FOAM3 (foam-foundation/foam3)

One backend folder `backends/java/foam3/` with two variants:

- `embedded`: notes in FOAM's own DAO stack (MDAO in-memory + journal file persistence).
- `postgres`: same model, DAO backed by Postgres via FOAM's JDBC DAO support.

Endpoints are exposed as plain JSON HTTP routes on port 8000 (a thin servlet/handler
over the DAO), so k6 scenarios are identical to other backends.

Risk: FOAM3 is a meta-framework and not designed as a minimal REST server.
A spike comes first. If the JDBC DAO isn't viable, the postgres variant uses plain
JDBC inside the FOAM handler, and the README says so. If FOAM can't serve HTTP
in Docker at all, the stack stops at that PR and the user is told.

## 5. Dashboard (benchmark-app)

Data: loads `results/index.json` (copied to `assets/`), then each run's `summary.json` on demand.

Header: run picker (default latest), scenario selector, language filter.
Tabs:

- **Overview**: one-line leaders per metric; sortable leaderboard as the hero
  (sustainable rps, peak rps, p99, CPU, memory, efficiency) with inline bars;
  row click → Framework.
- **Framework**: dropdown; 6 key tiles (+ "more"); time charts (rps, latency, CPU, mem);
  percentile bars; step-load curve (target vs achieved, p99 per step); history sparkline.
- **Compare**: 2–4 chips (extra chips disabled at 4, no snackbar); grouped bars
  (radar removed); overlaid time series with metric toggles (old Time Series tab);
  detail table.
- **History**: metric picker; each framework across runs. Different machine or
  methodology = separate series, never joined. Legacy runs labelled "v1 method".

Dropped: winner cards, radar, Time Series tab + sidebar, sidebar toggle.

## 6. PR stack (base → top)

1. `restructure` → main: layout, legacy move, spec, docs.
2. `bench-v2` → restructure: runner, k6 scenarios, report, endpoint changes per backend.
3. `bump-backends` → bench-v2: version bumps + first v2 run.
4. `foam3` → bump-backends: two variants + their run (same machine/methodology).
5. `dashboard-v3` → foam3: UI refactor.

Each PR: CI green, `flutter analyze` + `dart format` over the whole app, smoke test passing.

## Changes made during implementation

- **Paged reads use offsets below 200.** With offsets anywhere in the 10k
  rows, Postgres scanned ~5k rows per list request and saturated its 3 cores
  at ~6k rps for every fast framework (dotnet: DB 286% CPU, app 87%), so
  `db_read` measured Postgres, not the framework. Found in the first full run,
  which was discarded.
- **Recovery wait after a failing step** (2026-10-05): FOAM3 needed ~15 s to
  drain the backlog an overloaded step left behind; probing straight away
  made every finer-search probe fail (~300 rps served, 100% errors), so its
  result fell back to the last doubling step. The runner now waits for the
  health path to answer fast three times in a row before the next step. The
  other ten backends recover instantly (0 affected probes in the v2.1 run).
- **FOAM clients send a session** (2026-10-05): without FOAM's
  SessionedMessage wrapper every call journaled a new anonymous session,
  serializing all requests (thread dumps: ~760 of 1000 threads waiting on the
  journal). Real FOAM clients always send one.
- **Seeding goes through the API** (`POST /notes/` via k6), not SQL. ORMs name
  tables differently and the FOAM embedded variant has no SQL at all.
- **CPU sets scale with the Docker VM** (min 6 CPUs). On 10 CPUs: app 0-1,
  Postgres 2-4 (a 2-core Postgres capped go/mux's `db_mixed` at ~6k rps with
  the app at 46% CPU), k6 5-8, one spare. Stored in `run.json`.
- **Load-generator flag**: a step where k6 used > 75% of its cores is marked
  `k6_bound`; the fastest `no_db` backends reach this on a 10-core laptop.
- **Time series are per-second CPU/memory**; latency and throughput are per
  step (per-request k6 output at 60k rps is too large to keep).
- **Community result PRs**: generated files (`index.json`, run summaries) are
  built by CI, not committed; a run PR only adds `results/runs/<run_id>/`.
  Run ids get a random suffix, runs record `dirty` and an optional
  `contributor`, and `validate-results.yml` rejects edits to existing results.
- **`api_style`**: Serverpod is measured through its RPC API
  (`serverpod_rpc`), with the same four operations mapped in `scenarios/lib.js`.
- **Production modes fixed** while adding endpoints: Django ran on `runserver`
  with `DEBUG=True`, FastAPI blocked its event loop with sync SQLAlchemy,
  Node/Bun used one process, Rust shared one DB connection.
- The runner is Python (`bench/bench.py`, `bench/benchlib/`) behind `bench/run.sh`.

## Out of scope

Remote/CI benchmark runners; cross-machine normalisation; HTTP/2 or TLS;
auth endpoints; changing the Notes data model.
