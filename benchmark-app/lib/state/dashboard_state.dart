import 'package:flutter/foundation.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../services/results_service.dart';

/// The home table, plus the pages opened from it. Every page except
/// [home] has a Back control that returns to the table.
enum DashboardPage { home, details, compare, history, method }

/// Where a backend stands among the backends of one scenario for one metric.
class Rank {
  final int position; // 1-based
  final int total;
  final double? value;
  final double? leader;

  /// How many backends share this value (1 = no tie). Tied backends share
  /// the same position ("competition" ranking: 1, 1, 1, 4, …).
  final int tied;

  const Rank(
    this.position,
    this.total,
    this.value,
    this.leader, {
    this.tied = 1,
  });

  /// value / leader for higher-is-better metrics, null when undefined.
  double? get shareOfLeader {
    final v = value, l = leader;
    if (v == null || l == null || l <= 0) return null;
    return v / l;
  }

  /// "#3 of 12", "tied #1 of 12".
  String get label => '${tied > 1 ? 'tied ' : ''}#$position of $total';
}

/// Everything the screens share: which run is loaded, how the home table is
/// sorted and filtered, which row is expanded, which page is open, which
/// scenario the chart pages show, and which frameworks are being compared.
class DashboardState extends ChangeNotifier {
  final ResultsService _service;

  DashboardState(this._service);

  static const maxCompare = 4;

  List<RunIndexEntry> index = const [];
  RunIndexEntry? entry;
  RunSummary? run;
  Object? error;
  bool loading = true;

  DashboardPage page = DashboardPage.home;

  /// Scenario the Details and Compare pages show charts for.
  String? scenario;

  /// Number shown in every cell of the home table.
  Metric metric = Metrics.sustainable;

  /// Scenario column the home table is sorted by.
  String? sortScenario;

  /// Free-text filter over the rows of the home table.
  String query = '';

  /// Row expanded in place on the home table.
  String? expandedKey;

  /// Framework open on the Details page.
  String? detailKey;
  final List<String> compareKeys = [];

  Future<void> load() async {
    try {
      index = await _service.loadIndex();
      if (index.isEmpty) {
        throw StateError('No benchmark runs found');
      }
      await selectRun(index.first);
    } catch (e) {
      error = e;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectRun(RunIndexEntry next) async {
    entry = next;
    loading = true;
    notifyListeners();
    try {
      final loaded = await _service.loadRun(next);
      if (entry != next) return; // a newer selection won
      run = loaded;
      error = null;
      final scenarios = loaded.scenarios;
      if (!scenarios.contains(scenario)) {
        scenario = scenarios.isEmpty ? null : scenarios.first;
      }
      if (!scenarios.contains(sortScenario)) {
        sortScenario = defaultSortScenario(scenarios);
      }
      final results = [for (final b in loaded.backends) ...b.scenarios.values];
      if (!Metrics.available(results, [metric]).contains(metric)) {
        metric = Metrics.headlineFor(results);
      }
      final keys = loaded.backends.map((b) => b.key).toSet();
      compareKeys.removeWhere((k) => !keys.contains(k));
      if (detailKey != null && !keys.contains(detailKey)) detailKey = null;
      if (expandedKey != null && !keys.contains(expandedKey)) {
        expandedKey = null;
      }
      if (page == DashboardPage.details && detailKey == null) {
        page = DashboardPage.home;
      }
    } catch (e) {
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// DB mixed is the closest to a real API and is never capped by the load
  /// generator; No DB ties most frameworks at the k6 limit.
  static String? defaultSortScenario(List<String> scenarios) {
    if (scenarios.contains('db_mixed')) return 'db_mixed';
    return scenarios.isEmpty ? null : scenarios.first;
  }

  void setPage(DashboardPage next) {
    if (page == next) return;
    page = next;
    notifyListeners();
  }

  void goHome() => setPage(DashboardPage.home);

  void setScenario(String next) {
    scenario = next;
    notifyListeners();
  }

  void setMetric(Metric next) {
    metric = next;
    notifyListeners();
  }

  void setSortScenario(String next) {
    sortScenario = next;
    notifyListeners();
  }

  void setQuery(String next) {
    if (query == next) return;
    query = next;
    notifyListeners();
  }

  /// Expands [key] in place, or collapses it when it is already open.
  void toggleExpanded(String key) {
    expandedKey = expandedKey == key ? null : key;
    notifyListeners();
  }

  /// Expands the first row that matches [text], if any.
  bool expandFirstMatch(String text) {
    final hit = sortedBackends.where((b) => b.matches(text)).firstOrNull;
    if (hit == null) return false;
    expandedKey = hit.key;
    notifyListeners();
    return true;
  }

  void openDetails(String key) {
    detailKey = key;
    page = DashboardPage.details;
    notifyListeners();
  }

  bool canAddCompare(String key) =>
      compareKeys.contains(key) || compareKeys.length < maxCompare;

  void toggleCompare(String key) {
    if (!compareKeys.remove(key)) {
      if (compareKeys.length >= maxCompare) return;
      compareKeys.add(key);
    }
    notifyListeners();
  }

  void clearCompare() {
    compareKeys.clear();
    notifyListeners();
  }

  /// Puts [key] and the best other frameworks of the sorted column into the
  /// tray (up to [maxCompare]) and opens the Compare page.
  void compareWithLeaders(String key) {
    if (!compareKeys.contains(key)) {
      if (compareKeys.length >= maxCompare) compareKeys.removeLast();
      compareKeys.insert(0, key);
    }
    for (final b in leaders) {
      if (compareKeys.length >= maxCompare) break;
      if (!compareKeys.contains(b.key)) compareKeys.add(b.key);
    }
    page = DashboardPage.compare;
    notifyListeners();
  }

  /// Opens the Compare page for whatever is in the tray.
  void openCompare() => setPage(DashboardPage.compare);

  // ---------------------------------------------------------------- derived

  /// Rows of the home table: every backend of the run that matches the
  /// query, best first in the sorted column, missing values last.
  List<BackendResult> get sortedBackends {
    final r = run;
    if (r == null) return const [];
    final rows = r.backends.where((b) => b.matches(query)).toList();
    return rank(rows, metric, sortScenario);
  }

  /// Every backend of the run, best first in the sorted column.
  List<BackendResult> get allRanked =>
      run == null ? const [] : rank(run!.backends, metric, sortScenario);

  /// The best frameworks of the sorted column, in order.
  List<BackendResult> get leaders =>
      allRanked.where((b) => valueOf(b, metric, sortScenario) != null).toList();

  /// Backends of the run that have [scenario].
  List<BackendResult> backendsIn(String? s) {
    final r = run;
    if (r == null || s == null) return const [];
    return r.backends.where((b) => b.scenarios.containsKey(s)).toList();
  }

  /// Backends in the tray that have a result for [scenario], tray order.
  List<BackendResult> compared(String? s) => [
    for (final k in compareKeys)
      ?backendsIn(s).where((b) => b.key == k).firstOrNull,
  ];

  /// [backend]'s place among every backend with [scenario] for [metric].
  /// The query never changes a rank.
  Rank? rankOf(BackendResult backend, Metric metric, String? scenario) {
    final s = scenario ?? this.scenario;
    final ranked = rank(backendsIn(s), metric, s);
    final i = ranked.indexWhere((b) => b.key == backend.key);
    if (i < 0) return null;
    final value = valueOf(backend, metric, s);
    if (value == null) return null;
    final same = ranked.where((b) => valueOf(b, metric, s) == value).length;
    final first = ranked.indexWhere((b) => valueOf(b, metric, s) == value);
    return Rank(
      first + 1,
      ranked.length,
      value,
      valueOf(ranked.first, metric, s),
      tied: same,
    );
  }

  ScenarioResult? resultOf(BackendResult b, [String? s]) {
    final sc = s ?? scenario;
    return sc == null ? null : b.scenarios[sc];
  }

  double? valueOf(BackendResult b, Metric metric, String? s) {
    final r = resultOf(b, s);
    return r == null ? null : metric.value(r);
  }

  /// Metrics with at least one value in the run, in table order.
  List<Metric> get availableMetrics {
    final r = run;
    if (r == null) return const [];
    return Metrics.available([
      for (final b in r.backends) ...b.scenarios.values,
    ], Metrics.table);
  }

  /// The headline metric of the selected scenario: sustainable (v2) or
  /// average (v1).
  Metric get headline => Metrics.headlineFor(
    backendsIn(scenario).map((b) => resultOf(b)).whereType<ScenarioResult>(),
  );

  BackendResult? get detailBackend {
    final r = run;
    final key = detailKey;
    if (r == null || key == null) return null;
    return r.backend(key);
  }

  /// Backends sorted by [metric] in [scenario], best first; missing values
  /// last, alphabetical among equals so ties have a stable order.
  List<BackendResult> rank(
    List<BackendResult> backends,
    Metric metric, [
    String? scenario,
  ]) {
    final s = scenario ?? this.scenario;
    final sorted = [...backends];
    sorted.sort((a, b) {
      final va = valueOf(a, metric, s);
      final vb = valueOf(b, metric, s);
      if (va == null && vb == null) return a.name.compareTo(b.name);
      if (va == null) return 1;
      if (vb == null) return -1;
      final c = metric.higherIsBetter ? vb.compareTo(va) : va.compareTo(vb);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return sorted;
  }

  /// Index entries comparable with the selected run, oldest first, excluding
  /// combined "latest" views.
  List<RunIndexEntry> historyFor(String groupKey) =>
      index
          .where((e) => e.kind != RunKind.latest && e.groupKey == groupKey)
          .toList()
        ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));

  /// Machine/methodology groups that have more than nothing, newest first.
  List<String> get historyGroups {
    final seen = <String>[];
    for (final e in index) {
      if (e.kind == RunKind.latest) continue;
      if (!seen.contains(e.groupKey)) seen.add(e.groupKey);
    }
    return seen;
  }
}
