import 'package:material_ui/material_ui.dart';

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
  final entry = s.entry;
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
    DashboardPage.history => Uri(
      path: '/history',
      queryParameters: (s.historyTest ?? scenario) == null
          ? null
          : {'s': s.historyTest ?? scenario!},
    ),
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
    case 'history':
      state.applyRoute(page: DashboardPage.history, scenario: scenario);
    case 'method':
      state.applyRoute(page: DashboardPage.method);
    default:
      state.applyRoute(page: DashboardPage.home, scenario: scenario);
  }
}

class DashRouteParser extends RouteInformationParser<Uri> {
  const DashRouteParser();

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) async =>
      routeInformation.uri;

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

/// Keeps the URL and [DashboardState] in step: state changes become browser
/// history entries, and Back, Forward or a pasted link set the state.
class DashRouterDelegate extends RouterDelegate<Uri> with ChangeNotifier {
  final DashboardState state;

  /// A link that arrived before the data did.
  Uri? _pending;
  Uri? _last;

  /// The link last opened (pasted, Back, Forward) and the location it
  /// came to mean. While the state still matches, that link is reported
  /// as it was, so the app's tidier form of it never becomes a new history
  /// entry that Back would only land on and rewrite again.
  Uri? _openedAs;
  Uri? _openedFor;
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
      _apply(pending);
    }
    final now = locationOf(state);
    if (now != _last) {
      _last = now;
      notifyListeners();
    }
  }

  void _apply(Uri uri) {
    // The run first: load it, and apply the rest once it is in.
    final want = uri.queryParameters['run'];
    final target = want == null
        ? state.index.firstOrNull
        : state.index.where((e) => e.id == want).firstOrNull;
    if (target != null && target != state.entry) {
      _pending = uri;
      state.selectRun(target);
      return;
    }
    _applying = true;
    try {
      applyLocation(state, uri);
    } finally {
      _applying = false;
    }
    _last = locationOf(state);
    _openedAs = uri;
    _openedFor = _last;
    notifyListeners();
  }

  @override
  Uri? get currentConfiguration {
    if (state.run == null || _pending != null) return null;
    final now = locationOf(state);
    return _openedAs != null && now == _openedFor ? _openedAs : now;
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    if (state.run == null) {
      _pending = configuration;
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
  Widget build(BuildContext context) => Navigator(
    pages: const [MaterialPage<void>(child: HomeScreen())],
    onDidRemovePage: (_) {},
  );

  @override
  void dispose() {
    state.removeListener(_onState);
    super.dispose();
  }
}
