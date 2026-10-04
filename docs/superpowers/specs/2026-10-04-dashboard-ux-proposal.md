# Dashboard UX proposal — "find, understand, trust"

Date: 2026-10-04 · Status: approved in advance; open questions resolved below · Branch: `dashboard-ux`

Goal (user's words): refactor the dashboard so a visitor can (1) see which frameworks fit
their need, (2) find a framework fast and understand its numbers, (3) see how each backend
is implemented and configured so they can judge fairness, (4) understand the method and
caveats without a wall of text.

Grounding: `benchmark-app/lib/**`, the dev screenshots at 1440/1024/400 px
(`pr-assets/dashboard-v3/dev/*.jpg`), `bench/report/report.py`, `backends/*/*/backend.yaml`
and each `app/`.

## 1. Audit of the current dashboard

### Affordances today

| Area | Affordance | Code |
|---|---|---|
| Header | Title; run picker (latest / run / legacy, "modified code" flag) | `app_header.dart` `_RunPicker` |
| Header | Tabs Overview / Framework / Compare / History | `_Tabs` |
| Header | Scenario chips with help tooltip | `_FilterBar` |
| Header | Language filter chips + Clear (hidden on Framework tab) | `_FilterBar` |
| Overview | Method note (one paragraph: scenario help + SLO + machine) | `_MethodNote` |
| Overview | Leader strip: highest sustainable, highest rps/core, lowest memory (click → Framework) | `_Leaders` |
| Overview | Leaderboard: sortable columns (headline, peak, p99, errors, CPU, memory, rps/core) with inline bars + min–max whisker, flags (`load-gen limit`, `±N%`, `note`), row click → Framework, compare checkbox | `_LeaderTable`, `_LeaderCards` (phone) |
| Framework | Dropdown picker (alphabetical) + flags + notes text | `_Picker` |
| Framework | 6 stat tiles + "More metrics" toggle + reps/min–max footnote | `_tiles` |
| Framework | Throughput-per-step and p99-per-step charts | `_stepCharts` |
| Framework | Latency percentile bars | `_percentiles` |
| Framework | CPU / memory over time (+ rps for v1) | `_resources` |
| Framework | Headline by scenario (click switches scenario) | `_AcrossScenarios` |
| Framework | History sparkline for this backend | `_History` |
| Compare | Chip chooser (ranked), Top 3 / Clear, max 4 | `_Chooser` |
| Compare | 6 bar groups (best bold) | `_Bars` |
| Compare | Step charts overlaid + legend | `_steps` |
| Compare | Over-time chart with CPU / Memory / DB CPU / rps toggle | `_overTimeCard` |
| Compare | Side-by-side metric table (best green, info icons) | `_Table` |
| History | Metric segmented picker; one chart per machine+method group; legacy labelled | `history_screen.dart` |
| Global | Empty states: no match, no result for scenario, <2 to compare, load error | `EmptyState` |
| Global | Tooltips on metric names (help text) | `Metric.help` |

### Problems (with evidence)

| # | Problem | Evidence |
|---|---|---|
| P1 | **No way to see how a backend is implemented.** Only `vX · runtime` under the name and an optional free-text note. A visitor cannot tell that django-sync is gunicorn gthread via PgBouncer while FastAPI is uvicorn+asyncpg, or that Serverpod uses one isolate. Fairness is unjudgeable. | `BackendResult` has only version/runtime/db/notes; manifests carry nothing about server/concurrency/pool. |
| P2 | **No link to the source.** Nothing points to `backends/<lang>/<fw>` on GitHub. | no URL anywhere in `lib/`. |
| P3 | **Finding a framework is slow.** Framework tab uses a plain dropdown (alphabetical, ~12 entries with FOAM variants); no search, no prev/next, no deep link. On Overview a row must be clicked. | `_Picker` `DropdownButton`. |
| P4 | **Decision framing is absent.** The leaderboard is sorted by one metric; "what matters to you" (throughput vs resource cost vs DB-heavy vs not) is expressed only as raw column sorting + a scenario chip with jargon labels (`No DB`, `DB mixed`). | 1440-1-overview: column headers `Peak p99 Errors CPU Memory rps/core`. |
| P5 | **Method is a wall of text in a box**, repeated verbatim on every scenario switch; machine info is appended as dim text. Run params (steps, warmup, SLO numbers, images, cpusets) exist in `run.json` but are never shown. Caveat flags (`load-gen limit`, `±40%`, `note`) are only explained on hover, which does not exist on phones. | `_MethodNote`; `RunSummary.params` unused except `reps`. |
| P6 | **Jargon without a glossary**: p99, SLO, rps/core, `k6_bound`, "served everything" diagonal, `v1 method`. Help only via hover tooltips. | `Metric.help`, chart subtitles. |
| P7 | **Hierarchy on Framework**: the identity row is a small dropdown; the most important context (how it ranks, what it is) is missing; the "by scenario" and "History" cards are at the very bottom after 5 charts. | 1440-2-framework. |
| P8 | **Compare side-by-side is numbers only**: no implementation rows, so "why is X slower" has no answer on the page. Table is left-aligned narrow (`DataTable` inside a wide card). | 1440-3-compare bottom. |
| P9 | **Mobile**: tabs scroll off-screen ("Hist…" cut at 400 px), filter bar takes 3 rows, leaderboard cards hide the sort control entirely (no way to sort on phone), Compare at 400 px is a 2000+ px scroll of six bar cards before any chart. | 400-1-overview, 400-3-compare. |
| P10 | **Empty/edge states**: a backend with no result for the chosen scenario on Framework shows a bare "Pick another scenario"; a legacy run shows the same UI with a yellow note and hides that sustainable load does not exist there. Single-run History renders a lone dot. | `framework_screen.dart:43`, 1440-4-history. |
| P11 | **Information scent**: tab names say nothing about the question they answer; "Framework" is a singular noun, "Compare" has no indication of how many are selected. | `_Tabs`. |

## 2. Keep / move / drop (every affordance)

| Affordance | Decision | Where it goes |
|---|---|---|
| Title | keep | header |
| Run picker (+ modified-code flag) | keep | header (same place) |
| Tabs | keep, rename + add one | `Leaderboard · Framework · Compare (n) · History · Method` |
| Scenario chips + tooltip | keep | header; label gains plain-language help in the Method tab |
| Language filter + Clear | keep | header on Leaderboard, Compare, History (unchanged; the Framework finder lists every backend so a filter there would only hide things) |
| Method note paragraph | **move** | one-line summary stays on Leaderboard with "How it's measured →" link; full text, params and glossary move to the **Method** tab |
| Leader strip (3 leaders) | keep | Leaderboard, under the "Rank by" presets |
| Leaderboard table (sort, bars, whiskers, flags, row click, compare tick) | keep | Leaderboard; rows gain an implementation one-liner |
| Phone leaderboard cards | keep | gains a "Sort by" dropdown (sorting was desktop-only) |
| Framework dropdown | **move/replace** | becomes a searchable finder (type-ahead) + prev/next buttons; same `setDetail` |
| Framework flags + notes text | keep | inside the new Implementation card |
| Stat tiles + More metrics + reps footnote | keep | unchanged |
| Step charts, percentiles, over-time charts | keep | unchanged, below Implementation |
| Headline by scenario | **move up** | directly under the tiles (it answers "DB-heavy or not" for this backend) |
| Framework History card | keep | bottom (unchanged) |
| Compare chooser / Top 3 / Clear / max 4 | keep | unchanged |
| Compare bar groups | keep | unchanged |
| Compare step charts, over-time toggle | keep | unchanged |
| Compare side-by-side table | keep + extend | gains an "Implementation" section (server, concurrency, DB access, pool, API, versions, source) |
| History metric picker, per-group charts, legacy label | keep | unchanged |
| Empty states | keep + improve | Framework "no result in this scenario" lists the scenarios that do have results (tap to switch) |
| Metric tooltips | keep | also listed as a glossary on Method |
| **Dropped** | — | nothing is dropped |

## 3. Information architecture and flows

### Patterns applied

| Pattern | Where | Why |
|---|---|---|
| Progressive disclosure | Method tab; Leaderboard one-liner → "How it's measured"; More metrics | Caveats without a wall of text (P5, P6) |
| Decision-oriented presets ("Rank by") | Leaderboard: `Most load · Cheapest CPU · Least memory · Lowest p99` | Turns raw columns into questions (P4) |
| Scannable comparison table + inline bars | Leaderboard (existing) | kept |
| Search / type-ahead finder | Header on Framework tab (and the leaderboard filters by it) | Fast "find X" (P3) |
| Implementation card (fact sheet) | Framework tab, Compare table | Fairness judgement (P1, P2) |
| Glossary + flag legend | Method tab | Jargon (P6) on phones too |
| Contextual rank summary | Framework tab: "#2 of 6 · 83% of the leader" | Understand a number in context (P7) |
| Consistent empty states with a next action | Framework / Compare | P10 |

### Tabs

```
Leaderboard   who fits my need?         (presets, leaders, sortable table, impl one-liner)
Framework     tell me about X           (finder, identity + implementation card, rank, numbers)
Compare (n)   X vs Y                    (chips, bars, charts, table incl. implementation rows)
History       did it change over time?  (unchanged)
Method        can I trust this?         (what is measured, scenarios, fairness rules, run params, flags, glossary)
```

### Key flows

| Flow | Steps |
|---|---|
| "Max throughput for a DB-heavy API" | Leaderboard → scenario `DB mixed` → preset `Most load` → row 1; implementation line shows e.g. `node cluster ×2 · pg pool 20` → click → Framework |
| "FastAPI vs Express" | Leaderboard tick two rows (or Compare → chips) → Compare: bars, step curves, table with implementation rows side by side |
| "Is this trustworthy / how is X implemented" | Framework → finder "fast" → Implementation card: server, concurrency, DB access, pool, API style, versions, source link, notes, flags; "Method" tab for SLO, steps, cores, images |
| "What does p99 / load-gen limit mean" | tap the term's info icon (tooltip) or Method → Glossary |

## 4. Data needs

### New manifest block (`backends/<lang>/<fw>/backend.yaml`)

```yaml
implementation:
  server: gunicorn (gthread)                 # process/server that answers HTTP
  concurrency: 5 workers x 4 threads         # how the 2 cores are used
  db_access: Django ORM (psycopg 3)          # driver / ORM
  pool: 20 app-side, PgBouncer in front      # DB connections
# existing, reused: api_style (rest | serverpod_rpc | foam_rpc), notes, version, runtime
```

Four free-text strings; one per variant is not needed (FOAM's two variants differ only in
`db_access`, expressed in the string with "embedded: … / postgres: …"). Source link is
derived, not stored: `https://github.com/abdelaziz-mahdy/backend-benchmark/tree/main/backends/<path>`.

### Flow

```
backend.yaml --(bench.py: manifest.get("implementation"))--> run.json items[key].implementation
run.json ----(report.py build_run)--> runs/<id>.json backends[].implementation, .path, .api_style
                                      + implementation_from: "run" | "manifest"
runs/<id>.json --(results.dart BackendResult.implementation)--> Framework card, leaderboard line, compare rows
```

### Runs recorded before the field existed

`report.py` falls back to the current manifest: `backends/<item.path>/backend.yaml`
(`path` is already in every v2 `run.json` item; for legacy v1 keys the slug is matched
against `backends/*/*` folders). The dashboard labels such data "from the current
source, not the run" so nobody mistakes it for a snapshot.

PyYAML: `report.py` is stdlib-only, but `bench.py` already requires PyYAML, and
`validate-results.yml` already installs it. Decision: `pip install pyyaml` in
`deploy.yml` and `dashboard.yml` too, and `report.py` imports it lazily — without it the
fallback is skipped with a warning, so `--check` keeps working anywhere.

## 5. Wireframes

### Leaderboard (desktop ≥ 760 px)

```
┌ Backend Benchmarks                 [ Latest results · Apple M2 Pro        v ] ┐
│ Leaderboard | Framework | Compare (2) | History | Method                      │
│ Scenario (No DB)(DB read)(DB write)(DB mixed)   Languages (Go)(Python)…  Find [_____] │
├──────────────────────────────────────────────────────────────────────────────┤
│ i  DB mixed: 80% reads, 20% inserts. Sustainable load = … 2 cores, median of 3.  How it's measured → │
│ Rank by  [Most load] [Cheapest CPU] [Least memory] [Lowest p99 ⓘ]              │
│ [Highest sustainable · express 48.0K] [Highest rps/core · go mux 40.6K] [Lowest memory · go mux 91 MB] │
│ ┌ Leaderboard ───────────────────────────────────────────────────────────┐   │
│ │ #  Framework                      Sustainable load   Peak  p99  CPU  Mem  rps/core ☐ │
│ │ 1  ● express (node)  v5.2.1 · node 24.21   ███████████ 48.0K  57.5K 60ms 134% 262MB 35.9K ☐ │
│ │       node cluster ×2 · pg pool 20 · REST                                │   │
│ │ 2  ● go mux  …                                                           │   │
│ └──────────────────────────────────────────────────────────────────────────┘   │
```

### Leaderboard (phone < 760 px)

```
┌ Backend Benchmarks            ┐
│ [Latest results · M2 Pro   v] │
│ Leaderboard Framework Compare… (scrolls)
│ Scenario (No DB)(DB mixed)    │
│ Languages (Go)(JS)(Py)        │
│ i DB mixed … How it's measured →
│ Rank by [Most load v]         │
│ ┌ 1 ● express (node)  48.0K ☐┐│
│ │   v5.2.1 · node 24.21      ││
│ │   ███████████████████       ││
│ │   cluster ×2 · pg pool 20  ││
│ │   Peak 57.5K p99 60ms …    ││
│ └────────────────────────────┘│
```

### Framework (desktop)

```
│ Find framework [fast_______ v]  ‹ ›      (type-ahead; Enter opens best match)
│ ┌ ● fastapi  v0.142.2 · python 3.14          #3 of 6 by sustainable load · 41% of leader ┐
│ │ Server       uvicorn, 2 workers             DB access   SQLAlchemy async + asyncpg      │
│ │ Concurrency  asyncio event loop per worker  Pool        10 per worker (20 total)         │
│ │ API          REST                            Source      github.com/…/backends/python/fast-api ↗ │
│ │ ⚑ load-gen limit  ⚑ ±12%   note: …                                                       │
│ └──────────────────────────────────────────────────────────────────────────────────────────┘
│ [Sustainable 48.0K][Peak][p50][p99][CPU][Memory]   More metrics ▾
│ ┌ Sustainable load by scenario ┐   (moved up)
│ ┌ Throughput per step ┐ ┌ p99 per step ┐
│ ┌ Latency percentiles ┐
│ ┌ CPU over time ┐ ┌ Memory over time ┐
│ ┌ History ┐
```

Phone: finder full-width, prev/next below it, card facts stack as a 2-column label/value
list, charts stack.

### Compare

Unchanged layout; the side-by-side table gets a second section:

```
│ Side by side
│ Metric            ● express   ● go mux   ● django
│ Sustainable load  48.0K       40.0K      10.0K
│ …
│ ── Implementation ──
│ Server            node cluster  net/http   gunicorn
│ Concurrency       2 workers     goroutines 5×4 threads
│ DB access         pg            database/sql  Django ORM via PgBouncer
│ Pool              20            20          20 (+PgBouncer)
│ API               REST          REST        REST
│ Version           5.2.1         1.8.1       6.1.1
│ Source            ↗             ↗           ↗
```

Phone: table scrolls horizontally (as today).

### Method (new tab)

```
│ ┌ What is measured ┐  Sustainable load = highest rate with p99<100ms, errors<1%, ≥95% served. Peak = …
│ ┌ Scenarios ┐          No DB · DB read · DB write · DB mixed  (one line each, plain language)
│ ┌ Fairness rules ┐     2 pinned cores per app · Postgres on its own cores · ~20 DB connections ·
│                        production mode · seeded 10k rows · median of N reps · warmup discarded
│ ┌ This run ┐           machine, Docker, steps 250…64k × 30 s, warmup, SLO numbers, images, cpusets, git sha
│ ┌ Flags ┐              load-gen limit · ±N% · note · modified code · v1 method — what each means
│ ┌ Glossary ┐           p50/p90/p99/p99.9 · rps/core · rps/100MB · served vs requested …
```

Phone: same cards stacked. Legacy (v1) runs: "This run" shows the v1 Locust description.

## 6. Scope estimate

| Item | Files | Size |
|---|---|---|
| Manifest `implementation` block for 11 backends | `backends/*/*/backend.yaml`, `Contribution.md` | S |
| bench.py passes block through; report.py copies + manifest fallback + tests | `bench/bench.py`, `bench/report/report.py`, `bench/tests/test_report.py`, 3 workflows | M |
| Model + state: implementation, path, source URL, finder query, preset, rank summary | `models/results.dart`, `state/dashboard_state.dart` | S |
| Header: tab rename, Compare count, finder field | `widgets/app_header.dart` | S |
| Leaderboard: presets, one-liner, phone sort | `screens/overview_screen.dart` | M |
| Framework: finder, implementation card, rank line, reorder, better empty state | `screens/framework_screen.dart`, `widgets/implementation_card.dart` | M |
| Compare: implementation rows | `screens/compare_screen.dart` | S |
| Method tab | `screens/method_screen.dart` | M |
| Tests + tour | `test/dashboard_test.dart`, `test/tour/ui_tour_test.dart` | M |

Roughly 1.5–2 days of focused work. One new Dart dependency: `url_launcher` (its `Link`
widget renders a real anchor on the web, so source links open in a new tab and support
middle-click).

## 7. Open questions (resolved with the recommended answer)

| # | Question | Decision |
|---|---|---|
| Q1 | Method as a fifth tab or an expandable panel on Leaderboard? | **Fifth tab**, plus a one-line summary with a "How it's measured →" link on Leaderboard. A panel would re-create the wall of text. |
| Q2 | PyYAML in CI for the manifest fallback, or a hand-written mini parser? | **`pip install pyyaml`** in `deploy.yml` and `dashboard.yml` (validate already has it); `report.py` imports lazily and warns when missing. |
| Q3 | "Rank by" presets: should a preset also switch the scenario? | **No.** Presets only choose the sort metric; the scenario chips stay the single place that answers "DB-heavy or not". `Lowest p99` carries the caveat tooltip (each p99 is at its own load). |
| Q4 | Source link: `main` or the run's commit? | **`main`** as the primary link (what the user asked for; always resolves); when `git_sha` is known and the run is not dirty, a secondary "at run commit" link. |
| Q5 | Framework finder: command palette (⌘K) or a plain search field? | **Plain type-ahead fields**: a "Find a framework…" filter in the header (Leaderboard, Compare, History; Enter opens the best match) and the type-ahead picker with prev/next on the Framework tab. Works on phones; a palette does not. No `/` shortcut (it would fight the browser's find). |

## 8. As implemented (2026-10-04)

Delivered on `dashboard-ux`, matching the tables above with these details:

- `backend.yaml` → `implementation` block on all 11 backends; `bench.py` records it in
  `run.json`; `report.py` copies it and falls back to the current manifest for older runs
  and legacy keys (`implementation_from: manifest`), with `--backends` to point tests at
  a temp tree. PyYAML is installed in all three workflows; without it the report still
  builds (no fallback, no crash).
- Dashboard: tabs `Leaderboard · Framework · Compare (n) · History · Method`; header
  "Find a framework…" field; Leaderboard "Rank by" presets (`Most load`, `Cheapest per
  core`, `Least memory`, `Lowest p99` with caveat; `Most load (v1 avg)` on legacy runs),
  compact method note with "How it's measured →", implementation one-liner under each row
  (full facts in its tooltip; also the phone cards). Framework: type-ahead finder with
  prev/next, implementation card (facts, API, database, versions, source link on `main`
  and at the run commit when clean, notes, flags, rank line, "from current source"
  hint), "by scenario" moved under the tiles, "not measured in X" state with chips for
  the scenarios that exist. Compare: implementation section in the side-by-side table.
  Method: what is measured (from `run.params`), scenarios, fairness rules, this run
  (machine, Docker, images, commit), flags legend, glossary.
- Screenshot tour now covers 7 screens × 3 widths (`benchmark-app/screenshots/`).
- Not done (proposed, not asked): deep links / URL routing per framework.
