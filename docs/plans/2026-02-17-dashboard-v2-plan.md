# Dashboard v2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the single-screen benchmark dashboard into a 4-tab app (Rankings, Detail, Compare, Time Series) with graph cleanup.

**Architecture:** Add TabController-based navigation to main.dart. Each tab is a new screen widget. Provider gains new state (selectedDetailService, compareServices, activeTab). Existing Time Series tab reuses current code. Graph generation pipeline simplified to JSON-only.

**Tech Stack:** Flutter, fl_chart (LineChart, BarChart, RadarChart), Provider

---

### Task 1: Graph Cleanup — Remove PNGs and Simplify Pipeline

**Files:**
- Delete: `comparison_graph_db_test.png`, `comparison_graph_no_db_test.png`
- Delete: All `backends/*/*/tests/results/*/graph.png` files
- Modify: `scripts/graphs/graph_generator.py` — remove all matplotlib graph generation, keep only `data_json()`
- Modify: `scripts/start_tests.sh:125` — the `bash create_graphs.sh` call stays (it still generates data.json)
- Modify: `scripts/graphs/create_graphs.sh` — remove matplotlib from Docker image if desired (optional, low priority)

**Step 1: Delete all generated PNG files**

```bash
rm -f comparison_graph_db_test.png comparison_graph_no_db_test.png
find backends -name "graph.png" -delete
```

**Step 2: Simplify graph_generator.py**

Remove all matplotlib imports and graph-plotting functions. Keep: `process_file()`, `process_cpu_file()`, `get_adjusted_file_name()`, `merge_data_and_cpu()` / `merge_data_and_cpu_old()`, `data_json()`, and the data loading loop. Remove: `generate_graphs()`, `generate_comparison_graphs()`, the `update_image_urls()` function, and the README template copy. Remove `import matplotlib` and related.

**Step 3: Add graph.png to .gitignore**

```
# Generated graphs (app handles visualization now)
comparison_graph_*.png
**/graph.png
```

**Step 4: Commit**

```bash
git add -A
git commit -m "Remove generated graph PNGs, simplify pipeline to JSON-only"
```

---

### Task 2: Provider State — Add Navigation and Detail/Compare State

**Files:**
- Modify: `benchmark-app/lib/providers/benchmark_provider.dart`

**Step 1: Add new state fields and methods**

Add these fields and methods to `BenchmarkProvider`:

```dart
// Navigation
int activeTab = 0;

// Detail tab
String? selectedDetailService;

// Compare tab
Set<String> compareServices = {};

void setActiveTab(int tab) {
  activeTab = tab;
  notifyListeners();
}

void selectDetailService(String service) {
  selectedDetailService = service;
  activeTab = 1; // Switch to Detail tab
  notifyListeners();
}

void toggleCompareService(String service) {
  if (compareServices.contains(service)) {
    compareServices.remove(service);
  } else if (compareServices.length < 4) {
    compareServices.add(service);
  }
  notifyListeners();
}

void setCompareServices(Set<String> services) {
  compareServices = services;
  notifyListeners();
}

/// Get ranked services for a given metric, filtered by current test type.
/// Returns list of (serviceName, value) sorted descending (or ascending for response time).
List<MapEntry<String, double>> getRankedServices(String metricKey, {bool ascending = false}) {
  if (data == null) return [];
  final entries = <MapEntry<String, double>>[];
  final services = testTypeFilter == TestTypeFilter.all
      ? data!.keys.toList()
      : testTypeFilter == TestTypeFilter.db
          ? dbServices
          : noDbServices;
  for (final name in services) {
    final value = data![name]?.summary[metricKey];
    if (value != null && value > 0) {
      entries.add(MapEntry(name, value));
    }
  }
  entries.sort((a, b) => ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
  return entries;
}
```

**Step 2: Initialize compareServices with top 3 after data loads**

In `loadData()`, after `selectedServices = data!.keys.toSet();`, add:

```dart
// Default compare to top 3 by req/s for db_test
final ranked = getRankedServices('Average Requests/s');
compareServices = ranked.take(3).map((e) => e.key).toSet();
// Default detail to the top performer
if (ranked.isNotEmpty) {
  selectedDetailService = ranked.first.key;
}
```

**Step 3: Commit**

```bash
git add benchmark-app/lib/providers/benchmark_provider.dart
git commit -m "Add navigation, detail, and compare state to provider"
```

---

### Task 3: Tab Navigation — Restructure main.dart and Header

**Files:**
- Modify: `benchmark-app/lib/main.dart` — replace `home: DashboardScreen()` with a new `HomeScreen` that has TabController
- Create: `benchmark-app/lib/screens/home_screen.dart` — TabController + tab bar + tab views
- Modify: `benchmark-app/lib/widgets/header_widget.dart` — add tab bar below title row

**Step 1: Create home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/benchmark_provider.dart';
import '../widgets/header_widget.dart';
import '../widgets/loading_widget.dart';
import 'dashboard_screen.dart';
import 'rankings_screen.dart';
import 'detail_screen.dart';
import 'compare_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<BenchmarkProvider>().setActiveTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        // Sync tab controller with provider state
        if (_tabController.index != provider.activeTab) {
          _tabController.animateTo(provider.activeTab);
        }

        if (provider.isLoading || provider.data == null) {
          return Scaffold(
            body: LoadingWidget(progress: provider.progress),
          );
        }

        return Scaffold(
          appBar: HeaderWidget(tabController: _tabController),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              RankingsScreen(),
              DetailScreen(),
              CompareScreen(),
              DashboardScreen(),
            ],
          ),
        );
      },
    );
  }
}
```

**Step 2: Update HeaderWidget to accept TabController and show tabs**

Replace the current `HeaderWidget` to include a tab bar row below the title:

```dart
class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final TabController? tabController;
  const HeaderWidget({super.key, this.tabController});

  @override
  Size get preferredSize => const Size.fromHeight(92); // 56 + 36

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        return AppBar(
          backgroundColor: const Color(0xFF161B22),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 56,
          title: Row(
            children: [
              const Icon(Icons.speed, color: Color(0xFF58A6FF), size: 22),
              const SizedBox(width: 10),
              const Text(
                'Backend Benchmarks',
                style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 24),
              _TestTypeToggle(provider: provider),
            ],
          ),
          actions: [
            if (provider.activeTab == 3) // Only show sidebar toggle on Time Series
              IconButton(
                icon: Icon(
                  provider.sidebarExpanded ? Icons.menu_open : Icons.tune,
                  color: const Color(0xFF8B949E),
                  size: 20,
                ),
                onPressed: provider.toggleSidebar,
                tooltip: 'Toggle sidebar',
              ),
            const SizedBox(width: 4),
          ],
          bottom: tabController != null ? PreferredSize(
            preferredSize: const Size.fromHeight(36),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF30363D), width: 1),
                ),
              ),
              child: TabBar(
                controller: tabController,
                labelColor: const Color(0xFFE6EDF3),
                unselectedLabelColor: const Color(0xFF8B949E),
                indicatorColor: const Color(0xFFF78166),
                indicatorWeight: 2,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Rankings', height: 36),
                  Tab(text: 'Detail', height: 36),
                  Tab(text: 'Compare', height: 36),
                  Tab(text: 'Time Series', height: 36),
                ],
              ),
            ),
          ) : null,
        );
      },
    );
  }
}
```

**Step 3: Update main.dart to use HomeScreen**

```dart
home: const HomeScreen(),
```

And add import for `home_screen.dart`.

**Step 4: Update DashboardScreen to not include its own AppBar**

Remove the `Scaffold(appBar:...)` wrapper in `dashboard_screen.dart`. The screen should just return the body content (LayoutBuilder with sidebar + chart grid) since the Scaffold is now in HomeScreen.

**Step 5: Commit**

```bash
git add benchmark-app/lib/
git commit -m "Add tab navigation with HomeScreen and updated header"
```

---

### Task 4: Rankings Screen — Winner Cards + Bar Charts + Data Table

**Files:**
- Create: `benchmark-app/lib/screens/rankings_screen.dart`
- Create: `benchmark-app/lib/widgets/winner_card.dart`
- Create: `benchmark-app/lib/widgets/ranking_bar_chart.dart`
- Create: `benchmark-app/lib/widgets/ranking_table.dart`

**Step 1: Create winner_card.dart**

A stat card showing category winner:

```dart
import 'package:flutter/material.dart';
import '../utils/colors.dart';

class WinnerCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String frameworkName;
  final String value;
  final Color color;

  const WinnerCard({
    super.key,
    required this.title,
    required this.icon,
    required this.frameworkName,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(frameworkName, style: const TextStyle(fontSize: 13, color: Color(0xFFC9D1D9))),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Create ranking_bar_chart.dart**

Horizontal bar chart showing all frameworks ranked for a metric:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';

class RankingBarChart extends StatelessWidget {
  final String title;
  final List<MapEntry<String, double>> rankedData;
  final String Function(double) formatValue;

  const RankingBarChart({
    super.key,
    required this.title,
    required this.rankedData,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    // Build horizontal bar chart using fl_chart BarChart
    // with rotated axis (horizontal: true)
    // Each bar = one framework, sorted by value
    // Color from ServiceColors, label at end of bar
    // ... (full implementation)
  }
}
```

Uses `BarChart` with `BarChartGroupData` for each framework. `BarTouchData` for tooltips. Framework names as left Y-axis labels. Values as right-side labels.

**Step 3: Create ranking_table.dart**

Sortable data table:

```dart
import 'package:flutter/material.dart';
import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';

class RankingTable extends StatefulWidget {
  final Map<String, BenchmarkService> data;
  final List<String> services;
  final void Function(String) onServiceTap;

  // ... sort state, build DataTable with sortable columns
  // Highlight best (green) and worst (muted) per column
}
```

**Step 4: Create rankings_screen.dart**

Assembles winner cards + bar charts + table:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/benchmark_provider.dart';
import '../widgets/winner_card.dart';
import '../widgets/ranking_bar_chart.dart';
import '../widgets/ranking_table.dart';

class RankingsScreen extends StatelessWidget {
  const RankingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        // Get ranked data for each metric
        final reqsRanked = provider.getRankedServices('Average Requests/s');
        final latencyRanked = provider.getRankedServices('Average Response Time (ms)', ascending: true);
        final cpuRanked = provider.getRankedServices('Average Server CPU Usage', ascending: true);
        // ... build scrollable column: winner cards row, bar charts, table
      },
    );
  }
}
```

**Step 5: Commit**

```bash
git add benchmark-app/lib/
git commit -m "Add Rankings screen with winner cards, bar charts, and sortable table"
```

---

### Task 5: Detail Screen — Single Framework Deep-Dive

**Files:**
- Create: `benchmark-app/lib/screens/detail_screen.dart`
- Create: `benchmark-app/lib/widgets/stat_card.dart`
- Create: `benchmark-app/lib/widgets/percentile_chart.dart`

**Step 1: Create stat_card.dart**

Simple big-number card for a single metric:

```dart
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  // ... minimal card with large value text
}
```

**Step 2: Create percentile_chart.dart**

Vertical bar chart showing P50 through P99.9 response times:

```dart
class PercentileChart extends StatelessWidget {
  final Map<String, double> summary;
  // Uses BarChart with bars for each percentile bucket
  // X-axis: P50, P75, P99, P99.9
  // Y-axis: response time in ms
}
```

**Step 3: Create detail_screen.dart**

```dart
class DetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        final service = provider.selectedDetailService;
        if (service == null) return _emptyState();
        final benchmarkService = provider.data![service];
        if (benchmarkService == null) return _emptyState();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Framework selector dropdown
              _FrameworkDropdown(provider: provider),
              const SizedBox(height: 16),
              // Summary stat cards row (wrap for responsive)
              _StatCardsRow(summary: benchmarkService.summary),
              const SizedBox(height: 16),
              // Time series charts (2x2 grid): Req/s, Response Time, CPU, Memory
              _TimeSeriesGrid(service: benchmarkService),
              const SizedBox(height: 16),
              // Percentile distribution bar chart
              PercentileChart(summary: benchmarkService.summary),
            ],
          ),
        );
      },
    );
  }
}
```

The time series grid reuses the same chart-building logic from `ChartCard` but for a single service with 4 fixed metrics.

**Step 4: Commit**

```bash
git add benchmark-app/lib/
git commit -m "Add Detail screen with stat cards, time series, and percentile chart"
```

---

### Task 6: Compare Screen — Radar Chart + Grouped Bars + Table

**Files:**
- Create: `benchmark-app/lib/screens/compare_screen.dart`
- Create: `benchmark-app/lib/widgets/radar_chart_widget.dart`
- Create: `benchmark-app/lib/widgets/grouped_bar_chart.dart`
- Create: `benchmark-app/lib/widgets/compare_table.dart`

**Step 1: Create radar_chart_widget.dart**

```dart
import 'package:fl_chart/fl_chart.dart';

class RadarChartWidget extends StatelessWidget {
  final List<String> services; // 2-4 service names
  final Map<String, BenchmarkService> data;
  // 5 axes: Req/s, Response Time (inverted), CPU (inverted), Memory (inverted), Failure Rate (inverted)
  // Normalize each axis 0-1 relative to max value among selected services
  // Uses fl_chart RadarChart with RadarChartData, RadarDataSet per service
}
```

**Step 2: Create grouped_bar_chart.dart**

```dart
class GroupedBarChart extends StatelessWidget {
  final List<String> services;
  final Map<String, BenchmarkService> data;
  // Groups: Req/s, Avg Response, P99, CPU, Memory
  // Each group has 2-4 bars (one per selected service)
  // Uses BarChart with grouped BarChartGroupData
}
```

**Step 3: Create compare_table.dart**

```dart
class CompareTable extends StatelessWidget {
  final List<String> services;
  final Map<String, BenchmarkService> data;
  // Rows = metrics, Columns = selected frameworks
  // Highlight best value per row
}
```

**Step 4: Create compare_screen.dart**

```dart
class CompareScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Framework selector chips (select 2-4)
              _FrameworkChips(provider: provider),
              const SizedBox(height: 16),
              // Radar chart
              RadarChartWidget(services: provider.compareServices.toList(), data: provider.data!),
              const SizedBox(height: 16),
              // Grouped bar charts
              GroupedBarChart(services: provider.compareServices.toList(), data: provider.data!),
              const SizedBox(height: 16),
              // Comparison table
              CompareTable(services: provider.compareServices.toList(), data: provider.data!),
            ],
          ),
        );
      },
    );
  }
}
```

**Step 5: Commit**

```bash
git add benchmark-app/lib/
git commit -m "Add Compare screen with radar chart, grouped bars, and comparison table"
```

---

### Task 7: Cross-Tab Navigation — Click Framework to Navigate

**Files:**
- Modify: `benchmark-app/lib/widgets/ranking_table.dart` — add onTap to framework name cells
- Modify: `benchmark-app/lib/widgets/ranking_bar_chart.dart` — add onTap to bar labels
- Modify: `benchmark-app/lib/screens/compare_screen.dart` — add "View Detail" button per framework

**Step 1: Wire up framework name clicks**

In `RankingTable`, when a framework name cell is tapped:
```dart
onTap: () => provider.selectDetailService(serviceName),
```

This updates `selectedDetailService` and sets `activeTab = 1`, which the `HomeScreen` TabController listens to.

Similarly in bar chart labels and compare screen chips.

**Step 2: Commit**

```bash
git add benchmark-app/lib/
git commit -m "Add cross-tab navigation: click framework to view detail"
```

---

### Task 8: Final Polish and README Update

**Files:**
- Modify: `README.md` — remove graph image references, add link to live dashboard
- Modify: `README_template.md` (if exists) — same cleanup

**Step 1: Update README to remove image sections**

Remove all `![...graph.png...]` lines and the comparison graph sections. Replace with a link to the GitHub Pages dashboard.

**Step 2: Build and verify**

```bash
cd benchmark-app
flutter build web --base-href /backend-benchmark/
```

**Step 3: Commit**

```bash
git add -A
git commit -m "Update README, remove graph references, add dashboard link"
```

---

## Task Dependency Order

```
Task 1 (Graph Cleanup)     ─── independent
Task 2 (Provider State)    ─── independent
Task 3 (Tab Navigation)    ─── depends on Task 2
Task 4 (Rankings Screen)   ─── depends on Task 2, 3
Task 5 (Detail Screen)     ─── depends on Task 2, 3
Task 6 (Compare Screen)    ─── depends on Task 2, 3
Task 7 (Cross-Tab Nav)     ─── depends on Tasks 4, 5, 6
Task 8 (Polish + README)   ─── depends on all above
```

Tasks 1 and 2 can run in parallel. Tasks 4, 5, 6 can run in parallel once Task 3 is done.
