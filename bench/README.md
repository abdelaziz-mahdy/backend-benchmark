# bench — benchmark runner

Requires Docker (at least 6 CPUs given to Docker) and Python 3.10+.
`run.sh` uses [uv](https://docs.astral.sh/uv/) for PyYAML when available,
otherwise `pip install pyyaml` first.

```bash
bench/run.sh --list                          # discovered backends
bench/run.sh --smoke                         # build + check every endpoint, no load
bench/run.sh                                 # full run: every backend, scenario, 3 reps
bench/run.sh --only go/mux,python            # substring of backend path or key
bench/run.sh --scenario db_read --reps 1     # subset
bench/run.sh --run-id <id>                   # resume / append to an existing run
bench/run.sh --force                         # ignore results cached from earlier runs
bench/run.sh --contributor <handle>          # optional, stored in run.json
python3 bench/report/report.py               # rebuild dashboard data
python3 bench/report/report.py --check       # validate results/, exit 1 on problems
```

## What a run does

For each backend × variant × scenario × rep:

1. Start the shared stack (`compose.yaml`): `db` (Postgres 18), optional
   `pgbouncer`, and the backend, each pinned to its own CPU set.
2. Wait for the health path, then for DB scenarios insert 10,000 notes through
   the API (`scenarios/seed.js`), so every backend is seeded the same way.
3. Warm up for 30 s, then step the load with k6's open-model
   `constant-arrival-rate` executor: 250, 500, 1k … 64k requests/s, 30 s each.
4. Stop at the first step that misses the SLO (p99 < 100 ms, errors < 1%,
   achieved ≥ 95% of target), then test the midpoint once.
5. Sample CPU and memory of every container each second; tear down.

| Scenario | Requests |
|---|---|
| `no_db` | `GET /no_db_endpoint/` |
| `db_read` | 50% `GET /notes/?limit=20&offset=N` (N < 200), 50% `GET /notes/{id}` (any of 10k) |
| `db_write` | `POST /notes/` |
| `db_mixed` | 40% paged list, 40% by id, 20% create |

### CPU sets

Sized from the CPUs Docker reports: app `0-1`, Postgres `2-3` (`2-4` from 10
CPUs up), k6 the rest (keeping one spare from 10 CPUs up). The split is stored
in `run.json`. A step where k6 itself used over 75% of its cores is flagged
`k6_bound`: results there are limited by the load generator, not the app.

## Output

```
results/runs/<date>_<machine>_<sha>_<rand>/
  run.json                                   machine, Docker, params, per-backend status
  <backend>/<scenario>/rep-<n>/
    steps.csv        one row per load step
    timeseries.csv   per-second CPU/memory by container role
    k6-<rate>.json   raw k6 summary per step
    meta.json        status, image digest, versions
```

Nothing is overwritten. If a newer run on the same machine and methodology
finds results for the same image digest, it records `"status": "cached"` and
points at that run instead of measuring again.

`report/report.py` turns `results/` into `benchmark-app/assets/results/`
(`index.json` + one JSON per run). Those files are generated, not committed.

## Backend API styles

Backends implement the REST contract in `Contribution.md`. A framework whose
native API is RPC can set `api_style` in `backend.yaml`; `serverpod_rpc` maps
the same four operations to `POST /note/<method>` (see `scenarios/lib.js`).

`foam_rpc` sends what FOAM's own client sends for a service call: `POST
/service/noteService` with a `foam.box.Envelope` holding a
`foam.box.RPCMessage` (`name` = the `NoteService` method, `args` = `[null,
...]`, the null being the Context argument), and reads back an Envelope with
an `RPCReturnMessage` (result in `data`). FOAM reports exceptions as an
`RPCErrorMessage` with HTTP 200, so for this style k6 reads the body and
counts such replies in the `rpc_failed` metric, which the runner adds to the
error rate (`benchlib/slo.py`). The smoke test unwraps replies with
`benchlib/foam_rpc.py`; a missing note returns `null` instead of 404.
