import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'models/tests.dart';
import 'screens/home_screen.dart';
import 'state/dashboard_state.dart';

/// Location of what is on screen, for the URL (hash routing on the web, so
/// GitHub Pages needs no server rules):
///
///     /                          the short answer
///     /one                       One framework, nothing chosen yet
///     /one/KEY?s=TEST            One framework, KEY's profile
///     /all                       Every number
///     /compare/KEY1,KEY2?s=TEST  Compare
///     /history?s=TEST            history
///     /method                    how it's measured
///
/// Any of these takes ?run=ID when the run shown is not the newest, so a
/// copied link opens the same numbers; no run means the newest.
///
/// Older links still land: /f/KEY (the details page) opens KEY in One
/// framework, and /compare/… opens Compare. The Every number sort and
/// measure stay out of the URL, so clicking around does not flood the
/// browser history.
Uri locationOf(DashboardState s) {
  final base = _place(s);
  // The run on screen: while another loads, links still mean this one.
  final entry = s.shownEntry ?? s.entry;
  if (entry == null || s.index.isEmpty || entry == s.index.first) return base;
  return base.replace(
    queryParameters: {...base.queryParameters, 'run': entry.id},
  );
}

Uri _place(DashboardState s) {
  final scenario = s.scenario;
  Uri at(String path, {bool withScenario = true}) => Uri(
    path: path,
    queryParameters: withScenario && scenario != null ? {'s': scenario} : null,
  );
  return switch (s.page) {
    // History lists the newest runs' tests: an old-method test is named
    // by its closest current one, the one History shows.
    DashboardPage.history => switch (s.historyTest ??
        (scenario == null ? null : currentScenario(scenario))) {
      null => Uri(path: '/history'),
      final test => Uri(path: '/history', queryParameters: {'s': test}),
    },
    DashboardPage.method => at('/method', withScenario: false),
    DashboardPage.home => switch (s.view) {
      HomeView.short => Uri(path: '/'),
      HomeView.one =>
        s.selectedKey == null ? Uri(path: '/one') : at('/one/${s.selectedKey}'),
      HomeView.all => Uri(path: '/all'),
      HomeView.compare =>
        s.compareKeys.isEmpty
            ? Uri(path: '/compare')
            : at('/compare/${s.compareKeys.join(',')}'),
    },
  };
}

/// Shows [uri] in [state]; unknown paths go to the short answer.
void applyLocation(DashboardState state, Uri uri) {
  final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  final scenario = uri.queryParameters['s'];
  final first = parts.isEmpty ? '' : parts.first;
  final rest = parts.length > 1 ? parts[1] : null;
  switch (first) {
    case 'one' || 'f':
      state.applyRoute(
        page: DashboardPage.home,
        view: HomeView.one,
        selected: rest,
        scenario: scenario,
      );
    case 'all':
      state.applyRoute(page: DashboardPage.home, view: HomeView.all);
    case 'compare':
      state.applyRoute(
        page: DashboardPage.home,
        view: HomeView.compare,
        // Plain /compare means no picks, so Back to it leaves Compare.
        compare: rest?.split(',') ?? const [],
        scenario: scenario,
      );
    // History and Method keep the results view underneath, so the header's
    // "Results" returns to it as it was left.
    case 'history':
      state.applyRoute(
        page: DashboardPage.history,
        view: state.view,
        scenario: scenario == null ? null : currentScenario(scenario),
      );
    case 'method':
      state.applyRoute(page: DashboardPage.method, view: state.view);
    default:
      state.applyRoute(page: DashboardPage.home, scenario: scenario);
  }
}

/// Hands the router whole history entries: the link, plus what a link does
/// not hold (set-aside picks and the like, saved per entry).
class DashRouteParser extends RouteInformationParser<RouteInformation> {
  const DashRouteParser();

  @override
  Future<RouteInformation> parseRouteInformation(
    RouteInformation routeInformation,
  ) async => routeInformation;

  @override
  RouteInformation? restoreRouteInformation(RouteInformation configuration) =>
      configuration;
}

/// Keeps the URL and [DashboardState] in step: state changes become browser
/// history entries, and Back, Forward or a pasted link set the state.
class DashRouterDelegate extends RouterDelegate<RouteInformation>
    with ChangeNotifier {
  final DashboardState state;

  /// An entry that arrived before the data (or its run) did, and the
  /// visitor's action count then: any action since makes it stale.
  RouteInformation? _pending;
  int _pendingActions = 0;
  Uri? _last;

  /// The link last opened (pasted, Back, Forward) and the location it
  /// came to mean. While the state still matches, that link is reported
  /// as it was, so the app's tidier form of it never becomes a new history
  /// entry that Back would only land on and rewrite again.
  Uri? _openedAs;
  Uri? _openedFor;

  /// The side state last reported, to notice changes the link misses.
  String? _lastSide;

  /// The next report replaces the current entry (a cancelled Back's).
  bool _replaceNext = false;

  /// The entry being applied needed a run change first, and the picks and
  /// set-aside picks before that change (none of them may be lost).
  bool _crossedRun = false;
  List<String> _beforeCross = const [];

  /// Under the Router, for reporting a change as a replace of the current
  /// history entry instead of a new one.
  BuildContext? _context;

  /// Notifies the Router; with [replace], the browser replaces the current
  /// entry instead of adding one.
  void _report({bool replace = false}) {
    final c = _context;
    if (replace && c != null && c.mounted) {
      Router.neglect(c, notifyListeners);
    } else {
      notifyListeners();
    }
  }

  bool _applying = false;

  DashRouterDelegate(this.state) {
    state.addListener(_onState);
  }

  void _onState() {
    // While a run loads, the old one is still on screen: a link waiting for
    // the new run must not be applied to the old one.
    if (_applying || state.run == null || state.loading) return;
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      // Its run could not be loaded (and is not retried in a loop).
      final want = pending.uri.queryParameters['run'];
      final failedHere =
          state.failedRun != null &&
          state.failedRun ==
              (want == null
                  ? state.index.firstOrNull
                  : state.index.where((e) => e.id == want).firstOrNull);
      if (state.actions == _pendingActions && !failedHere) {
        _apply(pending);
      } else if (state.actions == _pendingActions) {
        // The rest of the entry (page, view, picks, test) still applies, to
        // the run on screen, with its test mapped to that run's closest. A
        // Back's entry then holds what is shown, so Back from the next page
        // returns here; a pasted link stays in the address bar, so a reload
        // tries its run again.
        _crossedRun = false;
        _beforeCross = const [];
        final shown = state.shownEntry ?? state.entry;
        final query = {...pending.uri.queryParameters}..remove('run');
        if (shown != null && shown != state.index.firstOrNull) {
          query['run'] = shown.id;
        }
        final test = query['s'];
        if (test != null) {
          query['s'] = state.run?.isLegacy ?? false
              ? legacyScenario(test)
              : currentScenario(test);
        }
        final here = Uri(
          path: pending.uri.path,
          queryParameters: query.isEmpty ? null : query,
        );
        _apply(
          RouteInformation(uri: here, state: pending.state),
          openedAs: pending.state == null ? pending.uri : null,
          replace: pending.state != null,
        );
      } else {
        // The visitor acted while it waited: their action wins. The waiting
        // entry was never shown, so it is replaced by what is.
        _crossedRun = false;
        _beforeCross = const [];
        _last = null;
        _lastSide = null;
        _replaceNext = true;
      }
    }
    final now = locationOf(state);
    // Once the visitor moves on, the opened link is no longer what is
    // shown, and must not come back into the address bar later.
    if (now != _openedFor) _openedAs = null;
    // A change the link does not show (Clear all of set-aside picks, say)
    // still updates the entry: same link, so the browser replaces it.
    final side = jsonEncode(state.sideState);
    if (now != _last || side != _lastSide) {
      // Choices on a page (Compare picks, or the test on any view) replace
      // the entry; only moving to another page or run adds one, so Back
      // always moves between pages.
      final last = _last;
      final sameRun =
          last != null &&
          last.queryParameters['run'] == now.queryParameters['run'];
      final picksOnly =
          sameRun &&
          ((last.pathSegments.firstOrNull == 'compare' &&
                  now.pathSegments.firstOrNull == 'compare') ||
              last.path == now.path);
      _last = now;
      _lastSide = side;
      final replace = picksOnly || _replaceNext;
      _replaceNext = false;
      _report(replace: replace);
    }
  }

  void _apply(RouteInformation info, {Uri? openedAs, bool replace = false}) {
    final uri = info.uri;
    // The run first: load it, and apply the rest once it is in.
    final want = uri.queryParameters['run'];
    final target = want == null
        ? state.index.firstOrNull
        : state.index.where((e) => e.id == want).firstOrNull;
    // That run is still loading (a Back moments ago started it): this newer
    // entry waits in place of the older one, and is applied once it is in.
    if (target != null && target == state.entry && state.loading) {
      _pending = info;
      _pendingActions = state.actions;
      // Still a run change if it leaves the run on screen (the visitor
      // chose this run moments ago): its picks come back as for any other.
      final crossing = target != state.shownEntry;
      _crossedRun = crossing;
      _beforeCross = crossing
          ? [...state.compareKeys, ...state.parkedCompare]
          : const [];
      return;
    }
    if (target != null && target != state.entry) {
      _pending = info;
      _pendingActions = state.actions;
      // A run change only counts as crossing if it leaves the run on screen
      // (a second quick Back can land on the run still showing).
      final crossing = target != (state.shownEntry ?? state.entry);
      _crossedRun = crossing;
      _beforeCross = crossing
          ? [...state.compareKeys, ...state.parkedCompare]
          : const [];
      state.selectRun(target, byRouter: true);
      return;
    }
    final crossed = _crossedRun;
    final before = _beforeCross;
    _crossedRun = false;
    _beforeCross = const [];
    final fromHistory = info.state != null;
    // Compare picks are a choice, not a place: Back and Forward on one run
    // keep them as they are, whatever the entry's link says.
    final picks = [...state.compareKeys];
    final parked = [...state.parkedCompare];
    final away = state.awayForRun;
    _applying = true;
    try {
      applyLocation(state, uri);
      if (fromHistory) {
        // Before any pick in this visit (a reload), the entry's picks are
        // the only ones there are: bring them back.
        final fresh = !state.comparePicked;
        if (!crossed && !fresh) state.restoreCompare(picks, parked, away);
        state.restoreSide(
          info.state,
          restorePicks: crossed || fresh,
          keep: before,
          // On History and Method the results underneath, test included,
          // stay as the visitor left them, run change or not (the run
          // change itself carries the test across).
          linkHasTest:
              uri.queryParameters.containsKey('s') ||
              const {
                'history',
                'method',
              }.contains(uri.pathSegments.firstOrNull),
        );
        // Picks Back put on screen are the visitor's from now on, so a
        // later Forward to an entry saved without them keeps them.
        if (fresh && state.compareKeys.isNotEmpty) state.comparePicked = true;
      }
    } finally {
      _applying = false;
    }
    _last = locationOf(state);
    _lastSide = jsonEncode(state.sideState);
    if (fromHistory) {
      // Shown as it is now; if that differs from the entry's link, the
      // entry is replaced, never followed by a new one.
      _openedAs = null;
      _openedFor = null;
      _report(replace: replace || _last != uri);
    } else {
      _openedAs = openedAs ?? uri;
      _openedFor = _last;
      notifyListeners();
    }
  }

  @override
  RouteInformation? get currentConfiguration {
    if (state.run == null || _pending != null) return null;
    final now = locationOf(state);
    return RouteInformation(
      uri: _openedAs != null && now == _openedFor ? _openedAs! : now,
      state: state.sideState,
    );
  }

  @override
  Future<void> setNewRoutePath(RouteInformation configuration) async {
    if (state.run == null) {
      _pending = configuration;
      _pendingActions = state.actions;
      return;
    }
    _apply(configuration);
  }

  @override
  Future<bool> popRoute() async {
    if (state.page == DashboardPage.home && state.view == HomeView.short) {
      return false;
    }
    state.goHome();
    return true;
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) {
      _context = context;
      return Navigator(
        pages: const [MaterialPage<void>(child: HomeScreen())],
        onDidRemovePage: (_) {},
      );
    },
  );

  @override
  void dispose() {
    state.removeListener(_onState);
    super.dispose();
  }
}
