# Dashboard simplification — "my framework vs the rest"

Date: 2026-10-05 · Status: approved in advance · Branch: `dashboard-simplify`
Supersedes the interaction model of `2026-10-04-dashboard-ux-proposal.md` (data layer, Method
content, History, charts and implementation facts are kept).

User feedback (verbatim): "its becoming too complex too much buttons and choices that now i
dont know where to click and was looking for examlpe to find foam3 and got lost where to find
it, and wehn i found it i cant get the numbers in easy manner and compare it with others".
Clarification: foam3 is only an example. The typical visitor arrives with **one framework in
mind** (the one they use or evaluate), wants to find it at once, read its numbers across every
scenario, see where it stands, and compare it with a few alternatives.

## 1. Problems in the current UI (from `screenshots/*.png` before this change)

| # | Problem | Evidence |
|---|---|---|
| P1 | **Too many controls before any data.** At 1440 px the first screen has 33 controls above the table (run picker, 5 tabs, 4 scenario chips, 7 language chips, find field, "How it's measured", 4 rank-by presets, 3 leader tiles, 7 sortable headers) plus 2 per row. | `1440-1-overview.png` |
| P2 | **On a phone the first screen shows zero frameworks.** At 400 px the chrome (title, run picker, scrolling tabs, two rows of scenario chips, two rows of language chips, search, method note, rank-by, three leader tiles, card title) pushes the first row to y ≈ 820 px, below the fold. | `400-1-overview.png` |
| P3 | **Finding a framework needs a decision first.** It is unclear whether to scroll, type in "Find a framework…", open the Framework tab, or use its finder; the two search fields do different things (filter vs open). | `1440-1-overview.png`, `1440-2-framework.png` |
| P4 | **One scenario at a time.** Every number on the home page is for the selected scenario chip. The only all-scenario view is the "by scenario" card in the middle of the Framework page, and it shows one metric. Reading p99/CPU/memory for the other three scenarios means three more chip clicks. | `1440-2-framework.png` |
| P5 | **Compare lives on another tab.** From a framework you go back to the Leaderboard, tick boxes, then open Compare, or open Compare and re-pick chips. Nothing says "compare *this one* with others". | `1440-3-compare.png` |
| P6 | **Primary numbers in hover-only places.** Flags (`load-gen limit`, `±33%`, `note`) and implementation facts explain themselves only in tooltips; phones have no hover. | `400-1-overview.png` |
| P7 | **Card header flush with the border.** The Leaderboard card used `padding: (0,14,0,6)` so rows can be edge to edge, but `SectionCard` applied it to the title too. | `1440-1-overview.png` |
| P8 | **Memory axes in "K MB".** Time-series charts formatted memory with their own `'${formatNumber(v)} MB'`, giving "2.0K MB" where tiles say "1.9 GB". | foam3 memory chart (user report) |
| P9 | Text is not selectable, so numbers and implementation facts cannot be copied. | user request |
| P10 | **Compare "Side by side" is a condensed wall of identical rows**: ties painted as wins (8.0K green for one of two equal values), a value green against "—", no sense of magnitude, an ⓘ icon on every row, left-aligned numbers. | `1440-3-compare.png` bottom; user screenshot of foam3 embedded vs postgres |
| P11 | **Compare tab had ~30 controls above the first number**: run picker, 5 tabs, 4 scenario chips, 7 language chips, find field, 12 framework chips + Clear. | user screenshot of the Compare tab |
| P12 | **Method page is long bullet paragraphs in big cards**, no way to jump to a section; the "stops at the first failing step and then tests the midpoint" sentence is hard-coded. | user screenshot of the Method tab |

## 2. Tasks: clicks and decisions, before and after

Clicks = taps on a control; decisions = places where the visitor has to choose between
controls that look equally plausible. Measured at 1440 px, framework "foam3 (postgres)" (rank
10 of 12); the same path holds for any framework.

| Task | Current UI | New UI |
|---|---|---|
| T1 Find "foam3" | 0–2 clicks, **3 decisions** (which tab? filter or scroll? which of the two search fields?). The row is at y ≈ 1250 px, below the fold; on a phone it is ~2,000 px down. | **0 clicks, 0 decisions**: every framework is a row on the first screen (12 rows ≈ 560 px, no filters). On a phone the search box sits directly above the rows; typing "fo" leaves one row. |
| T2 Key numbers across all four scenarios + implementation | **4 clicks**: row → Framework page (sustainable per scenario only, mid-page) → 3 scenario chips for the rest. | **1 click**: the row expands in place with a scenario × metric grid (sustainable, peak, p99, CPU, memory, rps/core, errors, rank "#n of 12"), the flags written out, and the implementation facts. |
| T3 Compare with others | **5 clicks**: Leaderboard tab → tick it → tick 2 others → Compare tab (plus the chips again if the scenario changed). | **1 click** "Compare with the leaders" in the expanded row (this one + the two best of the current sort), or "+ Compare" on any rows and "Compare" in the tray (3 clicks for a hand-picked trio). The tray persists across scenarios, pages and run switches. |
| Visible controls on the first screen (1440) | **33** + 2 per row (45 with 12 rows: 12 row taps + 12 checkboxes) | **8** + 2 per row ("Data: …" link, "History", "How it's measured", search, "Showing" number picker, 4 sortable scenario headers; per row: tap to expand, "+ Compare") |
| Visible controls on the Compare view above the first number (1440) | **~30** (run picker, 5 tabs, 4 scenario chips, 7 language chips, find field, 12 framework chips, Clear) | **8** (3 header links, Back, 3 framework chips with ×, "Add from the list"); the scenario chips (4) come *after* the all-scenario numbers |
| Frameworks visible in the first 812 px at 400 px | **0** | 4 (search box and "Showing" sit directly above them) |

## 3. Keep / merge / move / drop — every current affordance

| Affordance | Decision | Reason / where |
|---|---|---|
| Title | keep | header |
| Run picker (+ "modified code" flag) | **move** | out of the header into Method → "Hardware and this run"; the header shows a quiet "Data: latest · Apple M2 Pro" link that opens that page (yellow icon when the run is legacy or from modified code) |
| Tabs Leaderboard / Framework / Compare / History / Method | **drop** as tabs | replaced by one home page + pages opened from it with a Back button (details, compare) and two header links (History, How it's measured) |
| Scenario chips (header, global) | **move** | the home table has all four scenarios as columns; chips remain only inside Details and Compare where charts need one scenario |
| Language chips + Clear | **merge** into search | `matches()` already matches language ("python" leaves the three Python rows); the chips cost 8 controls for the same effect |
| Find field (header) and Framework finder (type-ahead, prev/next) | **merge** into one search box above the rows | one field, one behaviour: filters rows as you type; Enter expands the first match. Prev/next dropped: the table is the navigation |
| Method note (blue box) | **move** | one-line footnote under the table ("highest load with p99 < 100 ms and < 1% errors, 2 cores, median of 3") + "How it's measured" link in the header; everything else is on the Method page |
| Rank-by presets | **merge** into the "Showing" picker | the table shows one number per scenario; "Showing: Sustainable load / Peak / p99 / CPU / Memory / rps/core" sorts by it when a header is tapped. Same questions, one control |
| Leader strip (3 tiles) | **drop** | the sorted table's first row *is* the leader; ties show as equal ranks ("1, 1, 1, 4"). Lowest-memory and rps/core leaders are one header tap away via "Showing" |
| Sortable columns, inline bars, rank numbers | keep | scenario columns sort; bars scaled per column |
| Flags `load-gen limit` / `±N%` / `note` | keep, spelled out | a † marker in the cell; the expanded row prints the full sentence; footnote explains †. No tooltip-only information |
| Compare checkbox per row | **merge** into "+ Compare" button + tray | same action, but visible wording and a persistent tray that leads to the comparison |
| Framework page: implementation card, tiles, "More metrics", step charts, percentiles, over-time charts, by-scenario card, history card | keep as **Details** page | opened from the expanded row ("Full details"); scenario chips at its top; by-scenario card dropped (the expanded row and the Details rank line cover it) |
| Rank line "#2 of 6 · 83% of the leader" | keep, extended | a "Rank" row per scenario in the expanded grid and in Details |
| Compare chooser chips, Top 3, Clear, max 4 | **merge** into the tray | tray chips (×) + Clear; "Top 3" becomes "Compare with the leaders" in the row |
| Compare six bar cards | **merge** into the side-by-side table | the same bars repeated per card; the table now carries a thin magnitude bar and a delta per cell |
| Compare side-by-side table with implementation rows | keep, **redesigned** | grouped rows (Throughput / Latency and errors / Resources / Efficiency / Implementation) with a one-line explanation per group; secondary rows (p90, p99.9, DB CPU, rps/100 MB) behind "More rows"; right-aligned tabular numbers; green only for a clear best among ≥ 2 values, "=" for ties; "−42%" / "2.3× slower" / "1.8× more" deltas; phone: one card per framework with the same groups |
| Compare step charts, over-time toggle | keep | Compare page, below the table; new first card "Sustainable load in every scenario" (scenarios × frameworks) so the comparison is also all-scenario |
| History metric picker, per-group charts | keep | History page via header link |
| Method page (what is measured, scenarios, fairness, this run, flags, glossary) | keep, **restructured** | via "How it's measured": nine short sections (Overview → How load is applied → What "sustainable load" means → Scenarios → Fairness rules → Hardware and this run (+ run picker) → Flags and marks → Glossary → Known limitations), small label/value tables instead of bullet paragraphs, a table of contents (side column on desktop, collapsible at the top on phone) whose entries scroll to the section; the stop rule is phrased from `params.refine_steps` |
| Empty states | keep | no match → "No framework matches…"; missing scenario → "—" in the cell and "not measured" in the grid; < 2 to compare → tray says "add one more" |
| Metric tooltips | keep + | help text also appears as the glossary on Method; primary numbers never depend on them |

## 4. Design

Patterns: single scannable comparison table as the home (every row = one framework, every
column = one scenario); **inline expandable rows** (accordion) for details without leaving the
list; **persistent selection tray** for compare (shopping-cart pattern); defaults instead of
choices (number shown = sustainable load, sort = DB mixed, best first); progressive
disclosure for charts, method and history; plain-language labels.

### Home (≥ 760 px)

```
┌ Backend Benchmarks         Latest results · Apple M2 Pro ▾   History   How it's measured ┐
│ [🔍 Find your framework (name, language)…]              Showing: Sustainable load ▾     │
│ #  Framework              No DB        DB read      DB write     DB mixed ▾         │
│ 1  rust actix-web  rust   48.0K † ▬▬▬  32.0K † ▬▬  16.0K ▬▬     32.0K ▬▬▬▬  [+ Compare]│
│ 2  express (bun)   js     48.0K † ▬▬▬  32.0K ▬▬▬   24.0K ▬▬▬    24.0K ▬▬▬   [+ Compare]│
│ …                                                                                   │
│ 7  foam3 (postgres) java   8.0K ▬       8.0K ▬       8.0K ▬       8.0K ▬     [✓ Added] │
│ ┌──────────────────────────────────────────────────────────────────────────────────┐ │
│ │ foam3 (postgres)  va0e878e · java 25        [Compare with the leaders] [Full details] │
│ │                      No DB     DB read   DB write  DB mixed                       │ │
│ │ Sustainable load     8.0K      8.0K      8.0K      8.0K                           │ │
│ │ Rank                 #7 of 12  #7 of 12  #7 of 12  #7 of 12  (17% of the best)    │ │
│ │ Peak / p99 / CPU / Memory / rps/core / Errors …                                   │ │
│ │ Server: FOAM3 Jetty HttpServer … · DB access: … · Pool: … · API: FOAM box RPC      │ │
│ │ note: … (author's remark, in full)                                                │ │
│ └──────────────────────────────────────────────────────────────────────────────────┘ │
│ 12 django (async) …                                                                 │
│ † load generator was the limit; the real number may be higher. Numbers: highest     │
│ request rate held with p99 < 100 ms and < 1% errors, 2 cores per app, median of 3.  │
└──────────────────────────────────────────────────────────────────────────────────────┘
┌ Comparing: [foam3 (postgres) ×] [rust actix-web ×]  Add one more or  [Compare →] Clear ┐
```

### Home (400 px)

```
┌ Backend Benchmarks           ┐
│ Latest results · M2 Pro ▾     │
│ History · How it's measured   │
│ [🔍 Find your framework…]     │
│ Showing: Sustainable load ▾   │
│ 1 ● rust actix-web   [+]      │
│   No DB  DB read  DB wr  DB mx│
│   48.0K† 32.0K†  16.0K  32.0K │
│ 2 ● express (bun)    [+]      │
│   …                           │
│ (tap a card → same grid as    │
│  desktop, stacked, 4 columns) │
└───────────────────────────────┘
│ tray: foam3 ×  actix ×  Compare→│
```

### Details page
Back · name · scenario chips (No DB / DB read / DB write / DB mixed) · rank line ·
implementation card · tiles · charts · history. Unchanged content, minus the finder and the
by-scenario card.

### Compare page

```
← All frameworks   foam3 (postgres) vs django (sync) vs rust actix-web
[● foam3 (postgres) ×] [● django (sync) ×] [● rust actix-web ×] [+ Add from the list]
┌ Sustainable load in every scenario ────────────────────────────────────┐
│            foam3 (postgres)      django (sync)       rust actix-web     │
│ No DB      −83%  8.0K ▬▬         −75% 12.0K ▬▬▬      48.0K ▬▬▬▬▬▬ (green)│
│ DB mixed   −75%  8.0K ▬▬         −88%  4.0K ▬         32.0K ▬▬▬▬▬▬       │
└────────────────────────────────────────────────────────────────────────┘
Scenario (No DB)(DB read)(DB write)(DB mixed)
┌ Side by side · No DB                                        [More rows ▾]┐
│ Throughput        Higher is better…                                      │
│ Sustainable load  −83% 8.0K ▬▬     −75% 12.0K ▬▬▬     48.0K ▬▬▬▬▬ (green) │
│ Latency and errors  At each framework's own sustainable load…            │
│ p99 latency       1.1× slower 10.4 ms   9.74 ms (green)   6.2× slower …  │
│ Error rate        = 0%            = 0%            = 0%                   │
│ Resources / Efficiency / Implementation (Server, Concurrency, …, Source) │
└──────────────────────────────────────────────────────────────────────────┘
┌ Throughput per load step ┐ ┌ p99 per load step ┐   ┌ Over time [CPU|Memory|DB CPU] ┐
```

Phone: the same, with the side-by-side table as one card per framework (same groups).

### Decisions
- Default sort column: `db_mixed` when the run has it (closest to a real API; no_db ties six
  frameworks at the load-generator limit), otherwise the first scenario. Tap any scenario
  header to sort by it.
- Ranks are competition ranks (1, 1, 1, 4) so ties never look like an order.
- "Compare with the leaders" = this framework + the two best others in the sorted column
  (4 max, as before). If the tray already has entries, the leaders are appended until full.
- Compare tray and expanded row survive scenario, page and run switches; keys that the new
  run does not have are pruned.
- Legacy (v1) runs use the same table with their two scenarios and a yellow banner.
- The whole app is wrapped in a `SelectionArea` (`MaterialApp.builder`) so every number,
  name and fact can be selected and copied. Selection starts on drag/long-press; single taps
  still expand rows, press buttons and chips, and focus the search field.
- `SectionCard` gets a `fullBleed` body option; the header always keeps its 16 px inset (P7).
- Winner rules in Compare: a value is "best" only when at least two frameworks have a value
  and the best is unique after display rounding; otherwise nobody is green and equal values
  show "=". A missing value ("—") never makes another value the best (P10).
- Flags in the table are text marks, not icons, so they can be selected and copied:
  "†" load-generator limit, "±" spread > 10%; the footnote under the table spells them out
  and the expanded row prints the full sentence per scenario.
- Button and dropdown text styles derive from the theme's label style (`labelStyle()`): a bare
  `TextStyle` in a `ButtonStyle` drops the font family, which the golden tour showed as boxes.
- All memory values go through `formatMb`; chart axes use one unit per chart chosen from the
  axis maximum (`memoryAxisFormatter`).
- Not done, proposed: a `#framework=key` URL hash for shareable selection (needs a web-only
  import); a "pin my framework to the top" toggle (the expanded row already stays highlighted).
