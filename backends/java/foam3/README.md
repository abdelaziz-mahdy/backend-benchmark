# FOAM3 backend

[FOAM3](https://github.com/foam-foundation/foam3), pinned to commit
`a0e878e2c74f53016bd990ed04d2b2aaa965aa26` (2026-10-03). The Dockerfile clones
that commit at build time; no FOAM sources live in this repo.

## Build and run

The app uses the layout from foam3's own project generator
(`./build.sh -T+setup/Project`): a root `pom.js` that includes `foam3/pom`,
`src/bench/notes/pom` and `journals/pom`. The Dockerfile follows the generated
project Dockerfile:

1. `node foam3/tools/build.js -Jbench --build-docker-tar` and
   `--build-resources-tar`: FOAM's build generates Java from the models, compiles
   everything and packages the binary JAR and the resources JAR (journals).
   `-Jbench` adds `deployment/bench/`.
2. FOAM's `install-docker.sh` installs the JARs into `/opt/bench`, and
   `run-docker.sh -W 8000` starts the server. JVM flags are FOAM's production
   defaults (`etc/shrc.local`: ZGC, heap at 75% of the container memory); no
   debug agent.

## Pieces

| File | Role |
|---|---|
| `src/bench/notes/Note.js` | The `Note` model (`id` Long, `title`, `content`). Java is generated from it. |
| `journals/services.jrl` | CSpecs: `noteDAO`, `JDBCConnectionSpec`, and the web agents `notes`, `no_db_endpoint`, `health`. |
| `src/bench/notes/NoteWebAgent.js` | `WebAgent` for `/notes/...`: parses JSON with FOAM's `JSONParser`, writes with `JSONFObjectFormatter`. |
| `src/bench/notes/NoDbWebAgent.js`, `NoteHealthWebAgent.js` | `/no_db_endpoint/` and `/health`. |
| `src/bench/notes/RootRouter.java` | FOAM's `NanoRouter`, mounted at `/` instead of `/service/`. |
| `deployment/bench/services.jrl` | The `http` CSpec: FOAM's Jetty `HttpServer` on port 8000 with only `RootRouter` mapped. |

### Routes

FOAM serves CSpec services through `NanoRouter` at `/service/<name>/...`.
The benchmark contract needs `/notes/`, `/health` and `/no_db_endpoint/`, so
`RootRouter` (a small `NanoRouter` subclass) rewrites `/<name>/...` to
`/service/<name>/...`. Everything else is NanoRouter's normal path: CSpec
lookup, the `authenticate` flag, per-request PM.

The `http` CSpec override also drops FOAM's static file servlet, CSP filter,
error pages and websockets, and turns gzip off for all paths (the other
backends do not compress).

### Storage (`BENCH_VARIANT`)

`noteDAO` is built with FOAM's `EasyDAO.Builder`; `setSeqNo(true)` puts a
`SequenceNumberDAO` in front of the store, which hands out ids 1, 2, 3, ...
under a lock, so concurrent POSTs get unique, gap-free ids.

- **embedded** (`db: none`): EasyDAO's default store, an in-memory `MDAO`,
  wrapped in a `SINGLE_JOURNAL` journal named `notes`. Each put is appended to
  `/opt/bench/journals/notes` and flushed to the OS (FOAM does not fsync).
  The image declares no volume, so every container starts with an empty journal.
- **postgres** (`db: postgres`): `setPostgres(true)` makes EasyDAO use FOAM's
  own `foam.dao.jdbc.PostgresDAO`, which creates table `note`
  (`id bigint primary key, title text, content text`, from the `sqlType` of each
  property) and turns `find`, `select` with `orderBy/skip/limit`, and `put` into
  SQL (`where id = ?`, `order by id limit 20 offset N`, `insert ... on conflict`).
  The connection comes from the `JDBCConnectionSpec` CSpec, filled from the
  `DATABASE_*` env vars.

No fallback was needed: FOAM3 has a JDBC/Postgres DAO.

One adjustment: FOAM's `JDBCPooledDataSource` keeps the commons-pool2 defaults
(at most 8 connections). The `noteDAO` script raises the pool (`PoolA`) to 20,
the size the contract asks for, through commons-dbcp2's `PoolingDriver`.

### Auth

The three web agents are CSpecs with `"authenticate": false`, so NanoRouter
does not wrap them in `AuthWebAgent`: no session or login. `noteDAO` is built
with `setAuthorize(false)` (no `AuthorizationDAO`) and `setRuler(false)`, and
is not served over FOAM's box protocol (`"serve": false`).

## Benchmark caveats

- The image runs the whole FOAM platform (users, rules, cron, logging services
  and so on), not only these endpoints, so memory use is higher than a minimal
  app. Startup takes a few seconds.
- NanoRouter records a PM (timing) entry per request, as it does for every
  FOAM service.
- Postgres: the id comes from the in-process `SequenceNumberDAO`, not a
  database sequence; the insert runs outside its lock. `PostgresDAO` writes
  with an upsert (`insert ... on conflict (id) do update`).
- Embedded: journal writes go through one synchronous writer per journal, so
  writes are serialized on the journal; reads go to the MDAO and take no lock.
