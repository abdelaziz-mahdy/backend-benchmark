# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A multi-language backend benchmarking suite that compares framework performance using Locust load testing against Dockerized services with PostgreSQL. Results are visualized via a React web app deployed to GitHub Pages.

## Running Benchmarks

All benchmarks require Docker. Every backend runs as a Docker Compose stack with three services: `db` (PostgreSQL), `benchmark` (the app), and `tester` (Locust).

```bash
# Run all backends (both db_test and no_db_test for each)
bash scripts/start_tests.sh

# Run specific frameworks or languages
INCLUDE="fast-api,mux" bash scripts/start_tests.sh
INCLUDE="python" bash scripts/start_tests.sh

# Custom Locust parameters (defaults: 10000 users, 2min runtime)
LOCUST_USERS=5000 LOCUST_SPAWN_RATE=5 LOCUST_RUNTIME=10 bash scripts/start_tests.sh

# Run a single backend manually
cd backends/go/mux
export test_type=db_test  # or no_db_test
bash docker_build_and_run.sh
```

## Graph Generation

After benchmarks complete, `start_tests.sh` auto-runs graph generation. To regenerate manually:

```bash
cd scripts/graphs
bash create_graphs.sh
```

This builds a Docker image that runs `graph_generator.py` (matplotlib/pandas), which:
- Reads `benchmark_stats_history.csv` and `cpu_usage.csv` from each backend's `tests/results/{db_test,no_db_test}/`
- Generates per-backend graphs and comparison graphs at repo root
- Writes merged JSON data to `benchmark-app/public/data.json`
- Regenerates `README.md` from `README_template.md` with updated graph paths

## Architecture

### Backend Structure

Each backend follows this convention at `backends/<language>/<framework>/`:
- `src/` — Application code + Dockerfile
- `tests/db_test.py` — Locust test hitting DB endpoints (`POST /notes/`, `GET /notes/`)
- `tests/no_db_test.py` — Locust test hitting static endpoint (`GET /no_db_endpoint/`)
- `tests/results/{db_test,no_db_test}/` — CSV results, CPU/mem usage, generated graphs
- `docker-compose.yml` — Defines `db`, `benchmark`, `tester`, `tester_worker` services
- `docker_build_and_run.sh` — Entry point that sources env setup, checks for changes (skips if unchanged), builds, runs, records resource usage

### Caching/Skip Logic

`internal_scripts/record_usages.sh` records Docker image hashes and Locust config after each run. On subsequent runs, if nothing changed, the backend is skipped entirely.

### Scripts

- `internal_scripts/set_required_envs.sh` — Sets default Locust env vars (LOCUST_RUNTIME, LOCUST_USERS, LOCUST_SPAWN_RATE)
- `internal_scripts/set_test_type.sh` — Prompts for test type if `$test_type` not set; creates results directory
- `internal_scripts/record_usages.sh` — Orchestrates docker compose build/up, CPU/memory recording, tester monitoring, and teardown

### Benchmark Web App

React app in `benchmark-app/` (Create React App). Reads `data.json` to display interactive charts (Chart.js).

```bash
cd benchmark-app
npm install
npm start        # Dev server
npm run build    # Production build
npm run deploy   # Deploy to GitHub Pages
```

## Adding a New Backend

1. Create `backends/<language>/<framework>/` with `src/`, `tests/`, `docker-compose.yml`, `docker_build_and_run.sh`
2. Copy `docker_build_and_run.sh` from an existing backend (minimal edits needed)
3. In `docker-compose.yml`, services must be named `db`, `benchmark`, `tester`, `tester_worker`
4. App must serve on port 8000 with endpoints: `POST /notes/`, `GET /notes/`, `GET /no_db_endpoint/`
5. DB credentials: postgres/postgres/postgres on the `db` service host

## Current Backends

Python (django-sync, django-async, fast-api), Dart (server-pod), JavaScript (express-node, express-bun), C# (dot-net), Go (mux), Rust (actix-web), Java (spring-boot)
