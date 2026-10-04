# Backend Benchmark

Compares backend frameworks under the same load, on the same machine, with the
same API. **[View the dashboard](https://abdelaziz-mahdy.github.io/backend-benchmark/)**

## The question it answers

What is the highest load each framework sustains while **p99 latency stays
under 100 ms and errors under 1%**, and what CPU and memory does that cost?
Peak throughput is reported as a secondary number.

## Backends

| Language | Frameworks |
|---|---|
| Python | Django (sync, async, via PgBouncer), FastAPI |
| Dart | Serverpod |
| JavaScript | Express on Node, Express on Bun |
| C# | ASP.NET Core |
| Go | gorilla/mux |
| Rust | actix-web |
| Java | Spring Boot |

Each backend lives in `backends/<language>/<framework>/` as a `backend.yaml`
manifest plus an `app/` folder. See [Contribution.md](Contribution.md) to add one.

## Scenarios

- `no_db` — static JSON, framework overhead only
- `db_read` — paged list and read-by-id over 10,000 seeded rows
- `db_write` — inserts
- `db_mixed` — 80% reads, 20% writes

## History

Every run is kept in `results/runs/`. Results from the earlier Locust-based
method are in `results/legacy/` and are not comparable with current runs
(see [results/legacy/README.md](results/legacy/README.md)).
