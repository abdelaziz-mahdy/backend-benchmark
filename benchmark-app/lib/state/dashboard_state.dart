import 'package:flutter/foundation.dart';

import '../models/metrics.dart';
import '../models/plain.dart';
import '../models/results.dart';
import '../services/results_service.dart';

/// The home page, and the two pages opened from its footer.
enum DashboardPage { home, history, method }

/// The view switch on the home page; each label names what the view shows.
enum HomeView {
  short("Who's fastest"),
  one('Find a framework'),
  all('All results'),
  compare('Compare');

  final String label;

  const HomeView(this.label);
}

/// Everything the screens share: which run is loaded, which page and view
/// are open, the framework looked up, the frameworks being compared, the
/// test the chart sections show, and how the Every number table is sorted.
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
  HomeView view = HomeView.short;

  /// Test the chart sections (and History) show.
  String? scenario;

  /// The test History shows. History offers the newest runs' tests even
  /// while an old run is loaded, so it keeps its own choice (and its own
  /// place in the URL) instead of changing [scenario].
  String? historyTest;

  /// Framework open in One framework.
  String? selectedKey;

  /// A framework that was looked up but is not in the loaded run. It comes
  /// back when a run that has it is loaded again (see [selectRun]).
  String? missingKey;

  final List<String> compareKeys = [];

  /// Picks hidden because the loaded run lacks them; they come back when a
  /// run that has them is loaded again (see [selectRun]).
  final List<String> parkedCompare = [];

  /// The set-aside picks that were set aside because a run lacked them:
  /// only these come back by themselves on a run change (as Compare
  /// promises). Picks set aside for lack of room wait for "Bring back", so
  /// switching runs never swaps a pick the visitor made for another.
  final Set<String> _awayForRun = {};

  /// Every number: what the cells show, which column sorts (a test, or
  /// [sortByName]), the direction, and whether run ranges are shown.
  Measure measure = Measure.load;
  String? sortTest;
  static const sortByName = '__name__';
  bool sortDesc = true;
  bool showRange = false;

  Future<void> load() async {
    try {
      index = await _service.loadIndex();
      if (index.isEmpty) {
        throw StateError('No benchmark runs found');
      }
      await selectRun(index.first, byRouter: true);
    } catch (e) {
      error = e;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectRun(RunIndexEntry next, {bool byRouter = false}) async {
    if (!byRouter) actions++;
    // The test (and sort column) chosen on a current-method run, kept for
    // the way back from an old-method run with other tests.
    final leaving = run;
    if (leaving != null && !leaving.isLegacy) {
      _currentMethodTest = scenario;
      _currentMethodSort = sortTest;
      _currentMethodSortDesc = sortDesc;
    }
    entry = next;
    loading = true;
    notifyListeners();
    try {
      var loaded = await _service.loadRun(next);
      if (entry != next) return; // a newer selection won
      if (loaded.isLegacy) loaded = _withCurrentNames(loaded);
      run = loaded;
      shownEntry = next;
      error = null;
      final tests = loaded.scenarios;
      // A test this run lacks becomes its closest match (an old-method run
      // has other tests), and the way back restores the test chosen before.
      String? fit(String? want, String? remembered) {
        if (want != null && tests.contains(want)) return want;
        // The test chosen before the old-method run, only while the old
        // run still shows its match (no newer choice made there).
        if (!loaded.isLegacy &&
            remembered != null &&
            tests.contains(remembered) &&
            want != null &&
            legacyScenario(remembered) == want) {
          return remembered;
        }
        if (want != null) {
          final near = loaded.isLegacy
              ? legacyScenario(want)
              : currentScenario(want);
          if (tests.contains(near)) return near;
        }
        return tests.firstOrNull;
      }

      scenario = fit(scenario, _currentMethodTest);
      if (sortTest == null) {
        sortTest = tests.firstOrNull ?? sortByName;
        sortDesc = measure == Measure.load;
      } else if (sortTest case final was?
          when was != sortByName && !tests.contains(was)) {
        final next = fit(was, _currentMethodSort);
        sortTest = next ?? sortByName;
        // The direction goes with the column: the one chosen before when
        // that column comes back, kept when the column carries across by
        // its closest match, the default only for a fallback.
        final back =
            !loaded.isLegacy &&
            next != null &&
            next == _currentMethodSort &&
            legacyScenario(next) == was;
        final near = loaded.isLegacy
            ? legacyScenario(was)
            : currentScenario(was);
        // A direction or measure changed on the old run clears the saved
        // direction: that newer choice is kept as it is.
        if (back && _currentMethodSortDesc != null) {
          sortDesc = _currentMethodSortDesc!;
        } else if (!back && next != near) {
          sortDesc = measure == Measure.load;
        }
      }
      final keys = loaded.backends.map((b) => b.key).toSet();
      // Picks the run lacks are parked, not dropped, and parked picks the
      // run has come back (while there is room).
      for (final k in compareKeys.where((k) => !keys.contains(k)).toList()) {
        compareKeys.remove(k);
        if (!parkedCompare.contains(k)) parkedCompare.add(k);
        _awayForRun.add(k);
      }
      for (final k
          in parkedCompare
              .where((k) => keys.contains(k) && _awayForRun.contains(k))
              .toList()) {
        if (compareKeys.length >= maxCompare) break;
        _awayForRun.remove(k);
        parkedCompare.remove(k);
        if (!compareKeys.contains(k)) compareKeys.add(k);
      }
      // The same for the framework looked up.
      final selected = selectedKey;
      if (selected != null && !keys.contains(selected)) {
        missingKey = selected;
        selectedKey = null;
      } else if (selected == null &&
          missingKey != null &&
          keys.contains(missingKey)) {
        selectedKey = missingKey;
        missingKey = null;
      }
    } catch (e) {
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  // ------------------------------------------------------------ navigation

  void setPage(DashboardPage next) {
    actions++;
    if (page == next) return;
    page = next;
    notifyListeners();
  }

  /// Back to the short answer (the site name and the logo do this).
  void goHome() {
    actions++;
    if (page == DashboardPage.home && view == HomeView.short) return;
    page = DashboardPage.home;
    view = HomeView.short;
    notifyListeners();
  }

  void setView(HomeView next) {
    actions++;
    if (page == DashboardPage.home && view == next) return;
    page = DashboardPage.home;
    view = next;
    notifyListeners();
  }

  /// Opens One framework on [key]; null shows the picker.
  void selectFramework(String? key) {
    actions++;
    final r = run;
    if (key != null && r?.backend(key) == null) return;
    selectedKey = key;
    missingKey = null;
    page = DashboardPage.home;
    view = HomeView.one;
    notifyListeners();
  }

  /// Only a test the loaded run has; anything else would leave the views
  /// showing "not measured" for a test that does not exist here.
  void setScenario(String next) {
    actions++;
    if (scenario == next) return;
    if (run != null && !run!.scenarios.contains(next)) return;
    scenario = next;
    notifyListeners();
  }

  void setHistoryTest(String next) {
    actions++;
    if (historyTest == next) return;
    historyTest = next;
    notifyListeners();
  }

  // ---------------------------------------------------------- every number

  void setMeasure(Measure next) {
    actions++;
    if (measure == next) return;
    measure = next;
    if (run?.isLegacy ?? false) _currentMethodSortDesc = null;
    // Best first: most requests a second, but the lowest reply time,
    // processor and memory.
    if (sortTest != sortByName) sortDesc = next == Measure.load;
    notifyListeners();
  }

  /// Sorts by [test] (or [sortByName]); the same column again flips the
  /// direction.
  void sortBy(String test) {
    actions++;
    if (run?.isLegacy ?? false) _currentMethodSortDesc = null;
    if (sortTest == test) {
      sortDesc = !sortDesc;
    } else {
      sortTest = test;
      // Best first: most requests a second, lowest of everything else.
      sortDesc = test == sortByName || measure == Measure.load;
    }
    notifyListeners();
  }

  void setShowRange(bool next) {
    if (showRange == next) return;
    showRange = next;
    notifyListeners();
  }

  // --------------------------------------------------------------- compare

  bool canAddCompare(String key) =>
      compareKeys.contains(key) || compareKeys.length < maxCompare;

  /// Adds [key] to the comparison, or removes it. Never drops a pick to
  /// make room: a full comparison ignores a new key.
  /// Adds or removes [key]. With [restore] (Compare's own remove, where the
  /// set-aside picks are explained), a freed place brings one back.
  void toggleCompare(String key, {bool restore = false}) {
    actions++;
    comparePicked = true;
    parkedCompare.remove(key);
    if (!compareKeys.remove(key)) {
      if (compareKeys.length >= maxCompare) return;
      compareKeys.add(key);
    } else if (restore) {
      final r = run;
      final back = parkedCompare
          .where((k) => r?.backend(k) != null)
          .firstOrNull;
      if (back != null) {
        parkedCompare.remove(back);
        compareKeys.add(back);
      }
    }
    notifyListeners();
  }

  /// Brings set-aside picks this run has back into Compare, while there is
  /// room.
  void restoreParked() {
    actions++;
    comparePicked = true;
    final r = run;
    for (final k
        in parkedCompare.where((k) => r?.backend(k) != null).toList()) {
      if (compareKeys.length >= maxCompare) break;
      parkedCompare.remove(k);
      compareKeys.add(k);
    }
    notifyListeners();
  }

  /// Puts back what "Clear all" took, set-aside picks included (Undo),
  /// with [away]: which of them came back by themselves on a run change.
  void restoreCompare(
    List<String> picks,
    List<String> parked, [
    Iterable<String> away = const [],
  ]) {
    compareKeys
      ..clear()
      ..addAll(picks);
    parkedCompare
      ..clear()
      ..addAll(parked);
    _awayForRun
      ..clear()
      ..addAll(away);
    notifyListeners();
  }

  /// Counts the visitor's own actions (taps, picks, run changes), so the
  /// router can tell that a Back still waiting for its run is stale: the
  /// newest thing the visitor did wins.
  int actions = 0;

  /// The run entry on screen (the loaded run), which lags [entry] while a
  /// run change loads; labels describe this one.
  RunIndexEntry? shownEntry;

  String? _currentMethodTest;
  String? _currentMethodSort;
  bool? _currentMethodSortDesc;

  /// The visitor has picked (or cleared) Compare frameworks in this visit.
  /// Until then, as after a reload, Back may bring back a history entry's
  /// saved picks: there is no choice of theirs to keep.
  bool comparePicked = false;

  /// The visitor's Undo of "Clear all": their own action, so it wins over
  /// a Back still waiting for its run.
  void undoClear(
    List<String> picks,
    List<String> parked,
    Iterable<String> away,
  ) {
    actions++;
    comparePicked = true;
    restoreCompare(picks, parked, away);
  }

  /// Which set-aside picks return by themselves on a run change.
  Set<String> get awayForRun => Set.unmodifiable(_awayForRun);

  /// What a URL does not hold but a history entry must: set-aside picks,
  /// which of them return on a run change, and a looked-up framework the
  /// run lacks. Saved with each entry so Back and Forward restore it.
  Map<String, Object?> get sideState => {
    'picks': [...compareKeys],
    'parked': [...parkedCompare],
    'away': [..._awayForRun],
    'missing': missingKey,
    'test': scenario,
    'historyTest': historyTest,
  };

  /// Restores [sideState] saved with a history entry (Back, Forward).
  ///
  /// Compare picks are a choice, not a place: with [restorePicks] false
  /// (Back or Forward on the same run) they and the set-aside picks stay as
  /// they are. With it (Back across a run change) the entry's picks come
  /// back, and every other pick in [keep] is set aside, never dropped. The
  /// test comes back when the entry's link did not hold one ([linkHasTest]).
  void restoreSide(
    Object? saved, {
    bool restorePicks = false,
    Iterable<String> keep = const [],
    bool linkHasTest = false,
  }) {
    if (saved is! Map) return;
    List<String> list(Object? v) => [
      if (v is List)
        for (final x in v)
          if (x is String) x,
    ];
    final r = run;
    final test = saved['test'];
    if (!linkHasTest &&
        test is String &&
        (r?.scenarios.contains(test) ?? false)) {
      scenario = test;
    }
    if (restorePicks) {
      compareKeys
        ..clear()
        ..addAll(
          list(
            saved['picks'],
          ).where((k) => r?.backend(k) != null).take(maxCompare),
        );
      parkedCompare
        ..clear()
        ..addAll(list(saved['parked']).where((k) => !compareKeys.contains(k)));
      _awayForRun
        ..clear()
        ..addAll(list(saved['away']));
      // Nothing is lost: another pick stays picked while there is room,
      // else it is set aside (and comes back by itself if this run lacks
      // it).
      for (final k in keep) {
        if (compareKeys.contains(k) || parkedCompare.contains(k)) continue;
        if (r?.backend(k) != null && compareKeys.length < maxCompare) {
          compareKeys.add(k);
          continue;
        }
        parkedCompare.add(k);
        if (r?.backend(k) == null) _awayForRun.add(k);
      }
    }
    // History's own test: as chosen, or none (it then follows the main
    // test), never taken from History's link alone.
    if (saved.containsKey('historyTest')) {
      final h = saved['historyTest'];
      historyTest = h is String ? h : null;
    }
    final missing = saved['missing'];
    missingKey = selectedKey == null && missing is String ? missing : null;
    notifyListeners();
  }

  void clearCompare() {
    actions++;
    comparePicked = true;
    compareKeys.clear();
    parkedCompare.clear();
    _awayForRun.clear();
    notifyListeners();
  }

  /// Shows what a link points at (see app_router.dart). Unknown frameworks
  /// and tests are ignored rather than shown empty.
  void applyRoute({
    required DashboardPage page,
    HomeView view = HomeView.short,
    String? selected,
    List<String>? compare,
    String? scenario,
  }) {
    final r = run;
    if (r == null) return;
    final keys = {for (final b in r.backends) b.key};
    // History's test is its own choice and never changes the main test.
    if (page != DashboardPage.history &&
        scenario != null &&
        r.scenarios.contains(scenario)) {
      this.scenario = scenario;
    }
    if (page == DashboardPage.history) historyTest = scenario;
    if (page == DashboardPage.home && view == HomeView.one) {
      selectedKey = selected != null && keys.contains(selected)
          ? selected
          : null;
      // Back or Forward to the picker keeps a framework the run lacks,
      // so changing run can still bring it back.
      if (selected != null) missingKey = null;
    }
    if (compare != null) {
      final picked = <String>[];
      for (final k in compare) {
        if (keys.contains(k) && !picked.contains(k)) picked.add(k);
      }
      compareKeys
        ..clear()
        ..addAll(picked.take(maxCompare));
      // Set-aside picks survive Back and Forward; only those now picked
      // leave the list.
      parkedCompare.removeWhere(compareKeys.contains);
    }
    this.page = page;
    this.view = view;
    notifyListeners();
  }

  /// v1 results named backends after their folders ("python fast api");
  /// show today's name for the same key so they can be matched, and keep
  /// the old one as [BackendResult.formerName]. Numbers are untouched.
  RunSummary _withCurrentNames(RunSummary legacy) {
    final current = index
        .where((e) => !e.isLegacy)
        .map((e) => e.names)
        .firstWhere((n) => n.isNotEmpty, orElse: () => const {});
    if (current.isEmpty) return legacy;
    return legacy.withBackends([
      for (final b in legacy.backends) b.renamed(current[b.key] ?? b.name),
    ]);
  }

  // ---------------------------------------------------------------- derived

  /// A framework's current name from the index, for keys the loaded run may
  /// not have (parked picks); the key when no run names it.
  String nameOf(String key) {
    for (final e in index) {
      final n = e.names[key];
      if (n != null) return n;
    }
    return run?.backend(key)?.name ?? key;
  }

  /// The number the loaded run ranks by.
  Metric get headline => run == null ? Metrics.sustainable : headlineOf(run!);

  BackendResult? get selectedBackend {
    final key = selectedKey;
    return key == null ? null : run?.backend(key);
  }

  /// Picked frameworks the loaded run has, in pick order.
  List<BackendResult> get compared => [
    for (final k in compareKeys) ?run?.backend(k),
  ];

  /// Backends of the run that have [s].
  List<BackendResult> backendsIn(String? s) {
    final r = run;
    if (r == null || s == null) return const [];
    return r.backends.where((b) => b.scenarios.containsKey(s)).toList();
  }

  ScenarioResult? resultOf(BackendResult b, [String? s]) {
    final sc = s ?? scenario;
    return sc == null ? null : b.scenarios[sc];
  }

  double? valueOf(BackendResult b, Metric metric, String? s) {
    final r = resultOf(b, s);
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
