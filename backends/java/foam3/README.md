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
| `src/bench/notes/NoteService.js` | `foam.INTERFACE` with `createNote`, `getNotes(limit, offset)`, `getNote(id)`, `noDb`. `skeleton: true` generates `NoteServiceSkeleton`. |
| `src/bench/notes/NoteServiceImpl.js` | Java implementation; calls `noteDAO`. |
| `src/bench/notes/ClientNoteService.js` | JS client stub (`Stub` property over a box). |
| `src/bench/notes/NoteHealthWebAgent.js` | `/service/health` (see below). |
| `journals/services.jrl` | CSpecs: `noteDAO`, `JDBCConnectionSpec`, `noteService`, `health`. |
| `deployment/bench/services.jrl` | The `http` CSpec: FOAM's Jetty `HttpServer` on port 8000 with only `NanoRouter` at `/service/*`. |

### Calling the service

`noteService` is a CSpec with `serve: true`, `boxClass:
bench.notes.NoteServiceSkeleton` and `serviceClass:
bench.notes.NoteServiceImpl`, and its `client` is the usual
`ClientNoteService` over `HTTPBox` to `service/noteService`. NanoRouter
serves it through `ServiceWebAgent` and `SessionServerBox`, FOAM's standard
box RPC path, so it is called exactly as FOAM's own client calls it. The
benchmark runner uses `api_style: foam_rpc` (see `bench/README.md`).

Wire format, captured with FOAM's JS client (`ClientNoteService` built from
the CSpec's `client` JSON, running under node) through a logging proxy. Every
call is `POST /service/noteService` with `Content-Type: application/json;
charset=utf-8`; the first arg is the Context argument, always `null`:

| Call | Request body (`message`) | Reply (`message`) |
|---|---|---|
| `noDb` | `{"class":"foam.box.RPCMessage","name":"noDb","args":[null]}` | `{"class":"foam.box.RPCReturnMessage","executionTime":1,"data":"No db endpoint"}` |
| `createNote` | `{"class":"foam.box.RPCMessage","name":"createNote","args":[null,{"class":"bench.notes.Note","title":"t2","content":"c2"}]}` | `{"class":"foam.box.RPCReturnMessage","executionTime":0,"data":{"class":"bench.notes.Note","id":2,"title":"t2","content":"c2"}}` |
| `getNotes` | `{"class":"foam.box.RPCMessage","name":"getNotes","args":[null,1,1]}` | `{"class":"foam.box.RPCReturnMessage","executionTime":0,"data":[{"class":"bench.notes.Note","id":2,"title":"t2","content":"c2"}]}` |
| `getNote` | `{"class":"foam.box.RPCMessage","name":"getNote","args":[null,1]}` | `{"class":"foam.box.RPCReturnMessage","executionTime":0,"data":{"class":"bench.notes.Note","id":1,...}}` |
| `getNote` (missing) | `... "args":[null,999999]}` | `{"class":"foam.box.RPCReturnMessage","executionTime":0}` (no `data`: null) |
| error | `createNote` with `[null,null]` | `{"class":"foam.box.RPCErrorMessage","data":{"class":"foam.box.RemoteException","id":"java.lang.IllegalArgumentException","message":"note required",...}}` |

The full request body wraps the message:
`{"class":"foam.box.Envelope","message":<message>,"replyBox":{"class":"foam.box.HTTPReplyBox"}}`,
and the reply is `{"class":"foam.box.Envelope","message":<message>}`. FOAM
returns HTTP 200 for both return and error replies; the runner reads the
body to count errors.

### Health

`GET /service/health` (`health_path` in `backend.yaml`). FOAM's built-in
`health` service (`foam.core.app.HealthWebAgent`) reports UP as soon as the
server runs and does not look at Postgres, so the `health` CSpec is replaced
with `NoteHealthWebAgent`. It returns 200 once `noteDAO` is built and, in the
postgres variant, a Postgres connection is valid.

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

`noteService` and `health` are CSpecs with `"authenticate": false`. For the
served `noteService`, `SessionServerBox` then accepts calls without a
`sessionId` (they run in FOAM's shared `anonymous` session) and skips the
`service.noteService` permission check; `health` is not wrapped in
`AuthWebAgent`. `noteDAO` is built with `setAuthorize(false)` (no
`AuthorizationDAO`) and `setRuler(false)`, and is not served itself
(`"serve": false`): clients reach it only through `noteService`.

## Benchmark caveats

- The image runs the whole FOAM platform (users, rules, cron, logging services
  and so on), not only these endpoints, so memory use is higher than a minimal
  app. Startup takes a few seconds.
- Every call goes through FOAM's full RPC path: NanoRouter (CSpec lookup, a
  PM entry), `ServiceWebAgent` (JSON parse of the Envelope), `SessionServerBox`
  (looks up and touches the shared anonymous session, builds the session
  context, another PM entry), the skeleton, and `HTTPReplyBox` (formats the
  reply Envelope). Bodies are larger than plain REST JSON (class names on
  every object).
- Postgres: the id comes from the in-process `SequenceNumberDAO`, not a
  database sequence; the insert runs outside its lock. `PostgresDAO` writes
  with an upsert (`insert ... on conflict (id) do update`).
- Embedded: journal writes go through one synchronous writer per journal, so
  writes are serialized on the journal; reads go to the MDAO and take no lock.
- `PostgresDAO` logs SQL errors and returns null rather than throwing.
  `createNote` turns a null put into an exception (an RPC error the runner
  counts) and `getNotes` fails on the null sink, but `getNote` cannot tell a
  database error from a missing row: both return null.
