# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A multi-language backend benchmarking suite. Each backend runs in Docker against PostgreSQL (or its own store), is load-tested with k6 in fixed-rate steps, and results are kept as append-only history. A Flutter web app (GitHub Pages) visualizes them.

## Layout

- `backends/<lang>/<framework>/backend.yaml` — manifest (name, versions, variants)
- `backends/<lang>/<framework>/app/` — source + Dockerfile, serves on port 8000
- `bench/` — shared compose stack, k6 scenarios, runner, report generator
- `results/runs/<date>_<machine>_<sha>/` — one folder per run, never overwritten
- `results/legacy/` — v1 Locust results, kept untouched for history
- `benchmark-app/` — Flutter dashboard

## API contract (every backend)

`GET /health`, `GET /no_db_endpoint/`, `POST /notes/`, `GET /notes/?limit=&offset=`, `GET /notes/{id}`.
DB settings from `DATABASE_HOST/PORT/NAME/USER/PASSWORD` (defaults db/5432/postgres/postgres/postgres).

## Adding / removing a backend

Add a folder with `backend.yaml` + `app/`; delete the folder to remove it. Past results stay in `results/`.

## Benchmark Web App

```bash
cd benchmark-app
flutter pub get
flutter run -d chrome
flutter build web --base-href /backend-benchmark/
# Deployment is automated via GitHub Actions on push to main
```
