# Legacy results (methodology v1)

Results produced before the v2 benchmark runner, kept unchanged for history.
Last refreshed 2026-02-17 (PR #17) on an Apple M2 Pro (10 cores, 32 GB).

How v1 measured, and why its numbers are not comparable with v2:

- Load generator: Locust (1 master + 1 worker) on the same machine, unpinned.
- Load shape: ramp to 10,000 users over the whole 120 s run (spawn rate 83.33/s),
  so no steady state was ever measured.
- Backend limited to 1.0 CPU (v2 pins 2 cores).
- `GET /notes/` returned every row while `POST /notes/` kept inserting,
  so read payloads grew during the run.
- One run per backend, no warmup, no repetitions.
- Python backends ran in development mode: Django on `manage.py runserver`
  with `DEBUG = True`, FastAPI as a single uvicorn process calling synchronous
  SQLAlchemy from async handlers. Node/Bun ran one process.

Layout:

- `<lang>-<framework>/{db_test,no_db_test}/` — raw Locust CSVs, `cpu_usage.csv`,
  recorded image hashes and Locust params.
- `summary_v1.json` — the dashboard data built from those CSVs (was `benchmark-app/assets/data.json`).
- `results_data_2024.json` — older combined data from the React dashboard era.
