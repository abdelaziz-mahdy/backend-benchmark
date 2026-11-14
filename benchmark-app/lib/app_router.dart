import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';
import 'state/dashboard_state.dart';

/// Location of what is on screen, for the URL (hash routing on the web, so
/// GitHub Pages needs no server rules):
///
///     /                         leaderboard
///     /f/KEY?s=SCENARIO         a framework's details
///     /compare/KEY1,KEY2?s=…    a comparison
///     /history?s=…              history
///     /method                   how it's measured
///
/// Search, metric and sort stay out of the URL, so typing does not flood
/// the browser history.
Uri locationOf(DashboardState s) {
  final scenario = s.scenario;
  Uri at(String path, {bool withScenario = true}) => Uri(
    path: path,
    queryParameters: withScenario && scenario != null ? {'s': scenario} : null,
  );
  return switch (s.page) {
    DashboardPage.home => Uri(path: '/'),
    DashboardPage.details => at('/f/${s.detailKey ?? ''}'),
    DashboardPage.compare => at('/compare/${s.compareKeys.join(',')}'),
    DashboardPage.history => at('/history'),
    DashboardPage.method => at('/method', withScenario: false),
  };
}

/// Shows [uri] in [state]; unknown paths go to the leaderboard.
void applyLocation(DashboardState state, Uri uri) {
  final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  final scenario = uri.queryParameters['s'];
  final first = parts.isEmpty ? '' : parts.first;
  final rest = parts.length > 1 ? parts[1] : null;
  switch (first) {
    case 'f':
      state.applyRoute(
        page: DashboardPage.details,
        detail: rest,
        scenario: scenario,
      );
    case 'compare':
      state.applyRoute(
        page: DashboardPage.compare,
        compare: rest == null ? const [] : rest.split(','),
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
  bool _applying = false;

  DashRouterDelegate(this.state) {
    state.addListener(_onState);
  }

  void _onState() {
    if (_applying || state.run == null) return;
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
    _applying = true;
    try {
      applyLocation(state, uri);
    } finally {
      _applying = false;
    }
    _last = locationOf(state);
    notifyListeners();
  }

  @override
  Uri? get currentConfiguration =>
      state.run == null || _pending != null ? null : locationOf(state);

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
    if (state.page == DashboardPage.home) return false;
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
