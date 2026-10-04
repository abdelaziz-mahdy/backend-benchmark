# Contributing

## Repository layout

```
backends/<language>/<framework>/
  backend.yaml      # manifest: display name, versions, variants
  app/              # source + Dockerfile (Docker build context)
bench/              # shared runner, k6 scenarios, report generator
results/
  index.json        # every run, consumed by the dashboard
  runs/<run_id>/    # one folder per run, never overwritten
  legacy/           # v1 (Locust) results, kept for history
benchmark-app/      # Flutter web dashboard
```

## Adding a backend

1. Create `backends/<language>/<framework>/app/` with the source and a `Dockerfile`.
   The app listens on port 8000.
2. Add `backends/<language>/<framework>/backend.yaml`:

   ```yaml
   name: go mux             # display name
   language: go
   framework: gorilla/mux
   version: "1.8.1"         # framework version
   runtime: go 1.26
   variants:
     - id: postgres
       db: postgres          # or: none (backend stores data itself)
       pgbouncer: false      # optional, route DB traffic through pgbouncer
   # optional:
   # api_style: rest         # or serverpod_rpc, foam_rpc (see bench/README.md)
   # health_path: /health
   # notes: one line shown in the dashboard
   # How the app is run; shown on the dashboard so readers can judge fairness.
   implementation:
     server: net/http with gorilla/mux          # what answers HTTP, in which mode
     concurrency: goroutine per request          # how the 2 cores are used
     db_access: database/sql with lib/pq         # driver / ORM
     pool: "20 (SetMaxOpenConns)"                # DB connections
   ```

   `implementation` is four short sentences; keep them accurate when you change
   the app (the report shows the block recorded with each run, and falls back to
   the current manifest for runs made before the block existed).

3. Implement the API contract below. Read DB settings from
   `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`
   (defaults `db`, `5432`, `postgres`, `postgres`, `postgres`).
4. Run it the way it runs in production: release build, production server,
   and use the CPUs given in `BENCH_CPUS` (2) — e.g. one worker per CPU for
   single-threaded runtimes. Keep the DB pool at about 20 connections in total.
5. Check it: `bench/run.sh --smoke --only <language>/<framework>`.

That is all: the runner discovers every `backend.yaml`.

## Removing a backend

Delete its folder. Its past results stay under `results/` and remain visible
in the dashboard's history.

## API contract

| Endpoint | Behaviour |
|---|---|
| `GET /health` | 200 once ready (DB reachable when the variant uses one) |
| `GET /no_db_endpoint/` | small static JSON |
| `POST /notes/` | insert `{title, content}`, return the created row |
| `GET /notes/?limit=20&offset=N` | rows ordered by id, at most `limit` |
| `GET /notes/{id}` | one row, 404 when missing |

Create the table however the framework normally does (migrations, ORM). The
runner seeds data through `POST /notes/`, so table and column names are up to you;
ids must start at 1 on a fresh database.

## Running benchmarks

```bash
bench/run.sh --smoke     # every backend builds and answers correctly
bench/run.sh             # full run (several hours)
```

See [bench/README.md](bench/README.md) for options and what a run measures.

## Submitting results

Results from your own machine are welcome as a pull request.

1. Run on a clean checkout of `main` (the run is marked `dirty` otherwise),
   with nothing else heavy running. Docker needs at least 6 CPUs.
2. `bench/run.sh --contributor <your-handle>` (all backends, or `--only` a few).
3. Commit only the new folder `results/runs/<run_id>/` and open a PR.
   Do not edit other runs or any generated file.
4. CI validates the folder (`bench/report/report.py --check`).

Runs are compared only with runs from the same machine and methodology; the
dashboard groups them by machine.

## Results history

Each run writes to a new `results/runs/<date>_<machine>_<sha>_<rand>/` folder.
Nothing under `results/` is edited after it is written. The dashboard data
(`benchmark-app/assets/results/`) is generated from these folders by CI.
