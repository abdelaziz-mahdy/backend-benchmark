# Relic 1 and 2, bytes per request, overall score

Plan only. Nothing has been built or run yet.

## What we know

- **Relic 2.0.0** was published on pub.dev on 2026-11-12. The last 1.x release
  is **1.2.0** (2026-03-11).
- Relic 2.0's main change is **`relic_native`**, an opt-in native HTTP adapter
  started with `app.serveNative()`. Its changelog claims about 5x the requests
  a second of `relic_io`, which is what `app.serve()` uses.
- 2.0 also has breaking header and body API changes: `Headers` is no longer a
  `Map`, and the `Body` sets Content-Type and Content-Length.
- The repo already benchmarks older versions: `history:` in `backend.yaml`
  plus a `FRAMEWORK_VERSION` Docker build argument. Serverpod uses it for 4.0.3.
- **Bytes data already exists.** Every stored k6 step summary has
  `data_received` and `data_sent`, so bytes per request can be worked out for
  every past run, with no new runs. At the 250 a second step:

  | Framework | No DB in / out | Reading in / out |
  |---|---|---|
  | rust-actix-web | 136 / 85 | 837 / 88 |
  | go-mux | 137 / 85 | 839 / 88 |
  | dart-server-pod | 219 / 141 | 1,152 / 153 |
  | java-foam3 | 384 / 461 | 1,373 / 470 |

  "In" is bytes received by the client and includes headers. FOAM and
  Serverpod are higher because of their RPC envelopes.
- **Gzip:** our FOAM config turns gzip off (`excludedGzipPaths: ["/*"]` in
  `backends/java/foam3/app/deployment/bench/services.jrl`). Kevin says FOAM
  has it on by default.
- The benchmark machine is this Mac (M2 Pro, 10 cores, 32 GB). Docker is not
  running right now.

## The work

### 1. Relic backend (`backends/dart/relic`)

- `backend.yaml`:
  - `version: "2.0.0"`;
  - `history: [{version: "1.2.0"}]`, so Relic 1 and Relic 2 show in the same
    version history;
  - `db: postgres`.
- App:
  - plain Relic router;
  - `package:postgres` with a pool of 20, like the others;
  - the standard API contract: `/health`, `/no_db_endpoint/`, and the
    `/notes/` routes.
- `Dockerfile`: same pattern as Serverpod. `dart:3.14.0`, an
  `ARG FRAMEWORK_VERSION` that pins the `relic` version, and a compiled exe on
  a `scratch` image.
- If one source file cannot compile against both 1.2 and 2.0 because of the
  header API changes, keep two small source files and pick one by major
  version in the Dockerfile.
- **Open:**
  - How many isolates (question 3)?
  - Should `relic_native` be its own variant (question 2)?

### 2. Bytes per request

- `bench/report/report.py`: add `bytes_in` and `bytes_out` per request to
  each test result. Use `data_received / http_reqs` and
  `data_sent / http_reqs` at the step that gave the result. Add both keys to
  `HEADLINE_KEYS`.
- Regenerate `benchmark-app/assets/results/`. Every past run gets the numbers.
- Dashboard: add two lower-is-better measures to the "What to show" picker,
  "Bytes a reply" and "Bytes a request". Also show them on the framework page
  and in Compare.
  - The (i) says the count includes headers and any RPC wrapper.
- Bytes are not part of the overall score (your choice).

### 3. Overall score

- For each test, each framework's result is divided by the best result in that
  test, which gives a number from 0 to 1.
- **Score = 100 × geometric mean of the four tests.**
- Edge cases, decided once:
  - A framework missing a test gets no score and shows "—", with a tooltip
    naming the missing test.
  - A capped result ("+") uses its cap value, and the score shows "+".
  - Variants (FOAM embedded and FOAM postgres) are scored separately, like
    every other entry.
  - Only the current version counts. History versions are not ranked.
- Computed in `report.py`, so the dashboard and any later tool read one
  number.
- **Open:** where it shows (question 4).

### 4. Gzip for FOAM

- Recommended: a new FOAM variant, **`embedded-gzip`**. It runs FOAM's
  default config with gzip on, next to today's gzip-off variants, so the
  dashboard shows what gzip saves in bytes and costs in speed.
- Gzip only happens when the client asks for it. First check whether k6 sends
  `Accept-Encoding: gzip` by default. If it does not, send it only to this
  variant through a manifest flag, so no other backend's conditions change.
- **Open:** a variant or a switch (question 1).

### 5. Runs (only after you say go)

- Start Docker Desktop.
- Run `bench/run.sh --only dart/relic`, which covers both versions and every
  variant across 4 tests and 3 repetitions.
- Run the new FOAM gzip variant.
- **Drift check:** rerun go-mux as well. The October runs are six weeks old,
  and macOS or Docker updates may have shifted speeds. If go-mux moved by more
  than about 5%, rerun everything before comparing.
- Then run `python3 bench/report/report.py` and the bench tests.

### 6. Ship

- One PR, with highlighted before/after screenshots.
- Before pushing:
  - `flutter analyze`, `flutter test` and `dart format` over the whole
    `benchmark-app`;
  - `cd bench && python3 -m pytest tests`.
- Merge on your word.

## Questions for you

1. **Gzip:** add an `embedded-gzip` FOAM variant (recommended), or switch FOAM
   to gzip on everywhere?
2. **`relic_native`:** add it as a Relic 2 variant (recommended, since it is
   the headline of 2.0), or only `app.serve()`?
3. **Isolates:** 2 isolates on both versions, one per app core (recommended),
   or 1 like Serverpod?
4. **Overall score:** an "All tests" entry at the top of the test picker on
   Who's fastest, showing ranked bars of the score (recommended), or its own
   section on the home page?
