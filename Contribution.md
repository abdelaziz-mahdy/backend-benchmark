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
   ```

3. Implement the API contract below. Read DB settings from
   `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`
   (defaults `db`, `5432`, `postgres`, `postgres`, `postgres`).

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

Table: `notes(id SERIAL PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL)`.

## Running benchmarks

The shared runner lands in `bench/` (see `bench/README.md` once present).

## Results history

Each run writes to a new `results/runs/<date>_<machine>_<sha>/` folder.
Nothing under `results/` is edited after it is written; compare runs only
when machine and methodology match (the dashboard enforces this).
