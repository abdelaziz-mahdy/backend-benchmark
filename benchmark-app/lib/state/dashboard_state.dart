import 'package:flutter/foundation.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../services/results_service.dart';

enum DashboardTab { overview, framework, compare, history, method }

/// Where a backend stands among the visible ones for one metric.
class Rank {
  final int position; // 1-based
  final int total;
  final double? value;
  final double? leader;

  const Rank(this.position, this.total, this.value, this.leader);

  /// value / leader for higher-is-better metrics, null when undefined.
  double? get shareOfLeader {
    final v = value, l = leader;
    if (v == null || l == null || l <= 0) return null;
    return v / l;
  }
}

/// Everything the screens share: which run, scenario and languages are
/// selected, which framework is open, and which are being compared.
class DashboardState extends ChangeNotifier {
  final ResultsService _service;

  DashboardState(this._service);

  static const maxCompare = 4;

  List<RunIndexEntry> index = const [];
  RunIndexEntry? entry;
  RunSummary? run;
  Object? error;
  bool loading = true;

  DashboardTab tab = DashboardTab.overview;
  String? scenario;
  final Set<String> languages = {};

  /// Free-text filter from the header's "Find" field.
  String query = '';
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
      final keys = loaded.backends.map((b) => b.key).toSet();
      compareKeys.removeWhere((k) => !keys.contains(k));
      if (detailKey != null && !keys.contains(detailKey)) detailKey = null;
      languages.removeWhere(
        (l) => !loaded.backends.any((b) => b.language == l),
      );
    } catch (e) {
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  void setTab(DashboardTab next) {
    if (tab == next) return;
    tab = next;
    notifyListeners();
  }

  void setScenario(String next) {
    scenario = next;
    notifyListeners();
  }

  void toggleLanguage(String language) {
    if (!languages.remove(language)) languages.add(language);
    notifyListeners();
  }

  void clearLanguages() {
    languages.clear();
    notifyListeners();
  }

  void setQuery(String next) {
    if (query == next) return;
    query = next;
    notifyListeners();
  }

  /// Opens the framework that best matches [text] (first by rank), if any.
  bool openBestMatch(String text) {
    final r = run;
    if (r == null) return false;
    final hits = rank(
      r.backends.where((b) => b.matches(text)).toList(),
      headline,
    );
    if (hits.isEmpty) return false;
    openFramework(hits.first.key);
    return true;
  }

  /// All backends of the run, by name, for the finder and prev/next.
  List<BackendResult> get allBackends =>
      [...?run?.backends]..sort((a, b) => a.name.compareTo(b.name));

  /// Moves the Framework tab to the previous (-1) or next (+1) backend.
  void stepDetail(int delta) {
    final all = allBackends;
    final current = detailBackend;
    if (all.isEmpty || current == null) return;
    final i = all.indexWhere((b) => b.key == current.key);
    detailKey = all[(i + delta) % all.length].key;
    notifyListeners();
  }

  void openFramework(String key) {
    detailKey = key;
    tab = DashboardTab.framework;
    notifyListeners();
  }

  void setDetail(String key) {
    detailKey = key;
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

  // ---------------------------------------------------------------- derived

  List<String> get allLanguages {
    final langs = {...?run?.backends.map((b) => b.language)}.toList()..sort();
    return langs;
  }

  /// Backends of the selected run that have the selected scenario and match
  /// the language filter.
  List<BackendResult> get visibleBackends {
    final r = run;
    if (r == null || scenario == null) return const [];
    return r.backends
        .where((b) => b.scenarios.containsKey(scenario))
        .where((b) => languages.isEmpty || languages.contains(b.language))
        .where((b) => b.matches(query))
        .toList();
  }

  /// True when the language filter or the query hides something.
  bool get filtersActive => languages.isNotEmpty || query.trim().isNotEmpty;

  /// Backends of the run that have the selected scenario, ignoring filters.
  List<BackendResult> get scenarioBackends {
    final r = run;
    if (r == null || scenario == null) return const [];
    return r.backends.where((b) => b.scenarios.containsKey(scenario)).toList();
  }

  /// [backend]'s place among every backend with this scenario (filters do
  /// not change a rank).
  Rank? rankOf(BackendResult backend, Metric metric) {
    final ranked = rank(scenarioBackends, metric);
    final i = ranked.indexWhere((b) => b.key == backend.key);
    if (i < 0) return null;
    return Rank(
      i + 1,
      ranked.length,
      _value(backend, metric),
      _value(ranked.first, metric),
    );
  }

  ScenarioResult? resultOf(BackendResult b) =>
      scenario == null ? null : b.scenarios[scenario];

  Metric get headline =>
      Metrics.headlineFor(visibleBackends.map(resultOf).whereType());

  BackendResult? get detailBackend {
    final r = run;
    if (r == null) return null;
    final visible = visibleBackends;
    final key = detailKey;
    if (key != null) {
      final b = r.backend(key);
      if (b != null) return b;
    }
    if (visible.isEmpty) return null;
    return rank(visible, headline).first;
  }

  /// Backends sorted by [metric], best first; missing values last.
  List<BackendResult> rank(List<BackendResult> backends, Metric metric) {
    final sorted = [...backends];
    sorted.sort((a, b) {
      final va = _value(a, metric);
      final vb = _value(b, metric);
      if (va == null && vb == null) return a.name.compareTo(b.name);
      if (va == null) return 1;
      if (vb == null) return -1;
      return metric.higherIsBetter ? vb.compareTo(va) : va.compareTo(vb);
    });
    return sorted;
  }

  double? _value(BackendResult b, Metric metric) {
    final r = resultOf(b);
    return r == null ? null : metric.value(r);
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
