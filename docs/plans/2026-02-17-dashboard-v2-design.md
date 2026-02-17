# Benchmark Dashboard v2 Design

## Goal

Transform the single-screen chart dashboard into a multi-tab benchmark analysis tool that serves both quick-answer seekers ("which framework should I pick?") and deep-dive analysts.

## Navigation

4-tab top navigation below the header:

| Tab | Purpose |
|-----|---------|
| **Rankings** (default) | Leaderboard with bar charts and sortable table |
| **Detail** | Single framework deep-dive — all metrics in one view |
| **Compare** | 2-4 framework head-to-head with radar + grouped bars |
| **Time Series** | Existing multi-line chart dashboard |

Header keeps: title + global test type filter (DB / No-DB / All).

## Tab 1: Rankings

**Winner Cards** (top row, 4 cards):
- Fastest (req/s), Lowest Latency, Most CPU Efficient, Most Memory Efficient
- Each shows: framework name, value, colored icon

**Horizontal Bar Charts** (middle):
- Requests/s, Avg Response Time, P99 Response Time
- Sorted best-to-worst, color-coded by framework, value labels at bar end

**Sortable Data Table** (bottom):
- Columns: Framework, Req/s, Avg Response, P50, P99, Failures/s, CPU%, Memory MB
- Click column to sort, best value highlighted green, worst muted
- Click framework name → navigates to Detail tab

## Tab 2: Detail

**Framework selector**: Dropdown at top (or arrive via click from Rankings/Compare)

**Summary stat cards**: Big numbers — Req/s, Avg Response, P50, P99, Failures/s, Avg CPU%, Avg Memory

**Time series charts** (small multiples grid):
- Requests/s, Response Time, CPU Usage, Memory Usage over time

**Percentile distribution**: Bar chart — P50/P66/P75/P80/P90/P95/P98/P99/P99.9

## Tab 3: Compare

**Framework chips**: Select 2-4 frameworks (defaults to top 3 performers)

**Radar/Spider chart**: Normalized axes — Req/s, Response Time (inverted), CPU (inverted), Memory (inverted), Failure Rate (inverted)

**Grouped bar charts**: Raw values side by side per metric

**Mini comparison table**: Selected frameworks as columns, metrics as rows

## Tab 4: Time Series

Existing dashboard — line charts + sidebar filters. No changes except wired into tab system.

## Cleanup: Remove Graph Generation

- Delete all `graph.png` from `backends/*/*/tests/results/*/`
- Delete `comparison_graph_*.png` from repo root
- Simplify `graph_generator.py` to only produce `data.json`
- Remove graph generation call from `start_tests.sh`
- Update `README_template.md` to remove image references

## Data Flow

All data already exists in `data.json`:
- `summary` → Rankings winner cards, Detail stat cards, Compare table
- `data[]` time series → Detail charts, Time Series tab
- Percentiles from summary → Detail percentile bar chart
- CPU/Memory from `data[]` → Detail resource charts, Compare radar

## Tech

- fl_chart: LineChart, BarChart, RadarChart
- Provider for state management (extend BenchmarkProvider)
- TabController for navigation (no router needed)
- Dark GitHub theme (unchanged)
