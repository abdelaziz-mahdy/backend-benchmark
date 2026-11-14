import 'dart:convert';
import 'dart:math' as math;

import 'package:benchmark_app/app_router.dart';
import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/models/metrics.dart';
import 'package:benchmark_app/models/results.dart';
import 'package:benchmark_app/screens/history_screen.dart';
import 'package:benchmark_app/screens/leaderboard_screen.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:benchmark_app/utils/formatters.dart';
import 'package:benchmark_app/utils/theme_constants.dart';
import 'package:benchmark_app/widgets/common.dart';
import 'package:benchmark_app/widgets/compare_tray.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support.dart';

Map<String, dynamic> stat(num v) => {'median': v, 'min': v, 'max': v};

Map<String, dynamic> scenarioJson({
  num? sustainable,
  num? p99,
  num? dbCpu,
  num cpu = 150,
  num mem = 100,
  bool loadgenBound = false,
  List<Map<String, dynamic>> steps = const [],
}) => {
  'reps': 3,
  'sustainable_rps': ?(sustainable == null ? null : stat(sustainable)),
  'peak_rps': stat((sustainable ?? 0) * 1.2),
  'p99_ms': ?(p99 == null ? null : stat(p99)),
  'app_cpu': stat(cpu),
  'app_mem_mb': stat(mem),
  'db_cpu': ?(dbCpu == null ? null : stat(dbCpu)),
  'loadgen_bound': loadgenBound,
  'steps': steps,
  'timeseries': {},
};

/// One recorded load step.
Map<String, dynamic> step(
  num target, {
  num? served,
  num p99 = 10,
  bool pass = true,
  bool k6 = false,
  bool refine = false,
}) => {
  'target_rps': target,
  'achieved_rps': served ?? target,
  'error_rate': 0,
  'p50_ms': p99 / 4,
  'p90_ms': p99 / 2,
  'p99_ms': p99,
  'p999_ms': p99 * 1.5,
  'app_cpu': 50,
  'app_mem_mb': 100,
  'pass': pass,
  'k6_bound': k6,
  'refine': refine,
};

/// A backend with recorded steps in one scenario.
Map<String, dynamic> steppedBackend(
  String key,
  num sustainable,
  List<Map<String, dynamic>> steps, {
  String scenario = 'db_mixed',
  bool loadgenBound = false,
}) => {
  'key': key,
  'name': key,
  'language': 'go',
  'status': 'ok',
  'scenarios': {
    scenario: scenarioJson(
      sustainable: sustainable,
      p99: 20,
      loadgenBound: loadgenBound,
      steps: steps,
    ),
  },
};

/// A backend with one scenario (the old shape most tests use).
Map<String, dynamic> backend(
  String key, {
  String language = 'go',
  num? sustainable,
  num? p99,
  num? dbCpu,
  String scenario = 'no_db',
  String? path,
  Map<String, String>? implementation,
  String? implementationFrom,
  String? notes,
}) => {
  'key': key,
  'name': key,
  'language': language,
  'status': 'ok',
  'path': ?path,
  'notes': ?notes,
  'implementation': ?implementation,
  'implementation_from': ?implementationFrom,
  'scenarios': {
    scenario: scenarioJson(sustainable: sustainable, p99: p99, dbCpu: dbCpu),
  },
};

/// A backend measured in all four scenarios.
Map<String, dynamic> fullBackend(
  String key, {
  required String language,
  required Map<String, num> sustainable,
  num p99 = 20,
  Set<String> loadgenBound = const {},
  String? path,
  Map<String, String>? implementation,
  String? notes,
}) => {
  'key': key,
  'name': key,
  'language': language,
  'status': 'ok',
  'path': ?path,
  'notes': ?notes,
  'implementation': ?implementation,
  'scenarios': {
    for (final e in sustainable.entries)
      e.key: scenarioJson(
        sustainable: e.value,
        p99: p99,
        loadgenBound: loadgenBound.contains(e.key),
      ),
  },
};

const kScenarios = ['no_db', 'db_read', 'db_write', 'db_mixed'];

Map<String, dynamic> indexEntry(
  String id, {
  String kind = 'run',
  String date = '2026-10-04',
  String machine = 'm2pro-10c-32g',
  String methodology = 'v2',
  Map<String, dynamic> headline = const {},
}) => {
  'id': id,
  'kind': kind,
  'date': date,
  'machine': {
    'slug': machine,
    'cpu': 'CPU $machine',
    'cores': 10,
    'ram_gb': 32,
  },
  'methodology': methodology,
  'backends': headline.keys.toList(),
  'scenarios': ['no_db'],
  'headline': headline,
  'file': 'runs/$id.json',
};

Map<String, String> files(
  List<Map<String, dynamic>> index,
  Map<String, List<Map<String, dynamic>>> runs,
) => {
  'assets/results/index.json': jsonEncode({'runs': index}),
  for (final e in runs.entries)
    'assets/results/runs/${e.key}.json': jsonEncode({
      'id': e.key,
      'kind': 'run',
      'date': '2026-10-04',
      'machine': {
        'slug': 'm2pro-10c-32g',
        'cpu': 'Apple M2 Pro',
        'cores': 10,
        'ram_gb': 32,
      },
      'methodology': 'v2',
      'git_sha': 'abc1234',
      'params': {
        'reps': 3,
        'steps': [250, 500, 1000],
        'cpusets': {'app': '0-1'},
      },
      'backends': e.value,
    }),
};

const goImpl = {
  'server': 'net/http with gorilla/mux',
  'concurrency': 'goroutine per request',
  'db_access': 'database/sql with lib/pq',
  'pool': '20 (SetMaxOpenConns)',
};

/// A realistic small run: one fast, one middling and one slow framework,
/// all measured in four scenarios, plus one measured in a single scenario.
MapBundle realisticBundle() => MapBundle(
  files(
    [indexEntry('r1')],
    {
      'r1': [
        fullBackend(
          'rust-actix',
          language: 'rust',
          sustainable: {
            'no_db': 48000,
            'db_read': 32000,
            'db_write': 16000,
            'db_mixed': 32000,
          },
          loadgenBound: {'no_db'},
          path: 'rust/actix-web',
        ),
        fullBackend(
          'go-mux',
          language: 'go',
          sustainable: {
            'no_db': 48000,
            'db_read': 24000,
            'db_write': 16000,
            'db_mixed': 16000,
          },
          loadgenBound: {'no_db'},
          path: 'go/mux',
          implementation: goImpl,
        ),
        fullBackend(
          'foam3',
          language: 'java',
          sustainable: {
            'no_db': 8000,
            'db_read': 8000,
            'db_write': 8000,
            'db_mixed': 8000,
          },
          notes: 'Uses its own box RPC.',
        ),
        fullBackend(
          'django-sync',
          language: 'python',
          sustainable: {
            'no_db': 12000,
            'db_read': 4000,
            'db_write': 4000,
            'db_mixed': 4000,
          },
        ),
        backend('db-only', sustainable: 500, scenario: 'db_mixed'),
      ],
    },
  ),
);

/// Pumps the app with [bundle] at [size] and waits for the data to load.
Future<DashboardState> pumpApp(
  WidgetTester t,
  MapBundle bundle, {
  Size size = const Size(1400, 1200),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.runAsync(() async {
    await t.pumpWidget(BenchmarkApp(service: ResultsService(bundle)));
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await t.pump();
    }
  });
  return Provider.of<DashboardState>(
    t.element(find.byType(Scaffold).first),
    listen: false,
  );
}

/// [text] inside the timing sheet (the same name can be on the podium).
Finder inSheet(String text) =>
    find.descendant(of: find.byKey(kTimingSheetKey), matching: find.text(text));

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  // An opened row scrolls into view after its first frame, and a scroll
  // animation ignores taps until the frame after it ends.
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

void main() {
  group('models', () {
    test('restarts parse and default to zero', () {
      expect(ScenarioResult.fromJson({'restarts': 2}).restarts, 2);
      expect(ScenarioResult.fromJson({}).restarts, 0);
    });

    test('missing fields parse as null, not crash', () {
      final r = ScenarioResult.fromJson({'reps': 1});
      expect(r.stats, isEmpty);
      expect(Metrics.sustainable.value(r), isNull);
      expect(Metrics.rpsPerCore.value(r), isNull);
      expect(formatMetric(Metrics.p99, null), '—');
      final b = BackendResult.fromJson({'key': 'x'});
      expect(b.name, 'x');
      expect(b.scenarios, isEmpty);
      expect(b.implementation, isNull);
      expect(b.sourceUrl, isNull);
      expect(b.apiLabel, 'REST (JSON over HTTP)');
    });

    test('implementation block and links', () {
      final b = BackendResult.fromJson({
        'key': 'go-mux',
        'name': 'go mux',
        'language': 'go',
        'framework': 'gorilla/mux',
        'runtime': 'go 1.27',
        'path': 'go/mux',
        'api_style': 'foam_rpc',
        'db': 'postgres',
        'pgbouncer': true,
        'implementation': {...goImpl, 'pool': ''},
        'implementation_from': 'manifest',
      });
      expect(b.implementation!.facts.map((f) => f.$1), [
        'Server',
        'Concurrency',
        'DB access',
      ]);
      expect(b.sourceUrl, endsWith('/tree/main/backends/go/mux'));
      expect(b.sourceUrlAt('abc'), endsWith('/tree/abc/backends/go/mux'));
      expect(b.sourceUrlAt(null), isNull);
      expect(b.apiLabel, 'FOAM box RPC');
      expect(b.storageLabel, 'Postgres via PgBouncer');
      expect(Implementation.fromJson({'server': ' '}), isNull);
      expect(b.matches('go MUX'), isTrue);
      expect(b.matches('gorilla 1.27'), isTrue);
      expect(b.matches('rust'), isFalse);
    });

    test('v1 results fall back to average throughput', () {
      final r = ScenarioResult.fromJson({
        'avg_rps': stat(500),
        'app_cpu': stat(50),
      });
      expect(Metrics.headlineFor([r]), Metrics.avgRps);
      expect(Metrics.rpsPerCore.value(r), 1000);
    });

    test('formatting', () {
      expect(formatMetric(Metrics.sustainable, 40000), '40.0K req/s');
      expect(Metrics.sustainable.labelWithUnit, 'Sustainable load (req/s)');
      expect(Metrics.p99.labelWithUnit, 'p99 latency');
      expect(formatMetric(Metrics.p99, 0.85), '0.85 ms');
      expect(formatMetric(Metrics.p99, 1500), '1.5 s');
      expect(formatMetric(Metrics.errors, 0.0004), '0.04%');
      expect(formatMetric(Metrics.cpu, 151.4), '151%');
      expect(formatMetric(Metrics.memory, 1900), '1.9 GB');
    });

    test('memory axis uses one unit per chart', () {
      final gb = memoryAxisFormatter(2000);
      expect(gb(1500), '1.5 GB');
      expect(gb(512), '0.5 GB');
      expect(gb(0), '0.0 GB');
      final mb = memoryAxisFormatter(500);
      expect(mb(150), '150 MB');
      expect(mb(0), '0 MB');
      expect(gb(2000), isNot(contains('K')));
    });
  });

  group('state', () {
    late DashboardState state;

    setUp(() async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1')],
          {
            'r1': [
              backend('a', sustainable: 1000, p99: 20),
              backend('b', sustainable: 4000, p99: 50),
              backend('c', language: 'rust', sustainable: 2000),
              backend('d', sustainable: null, p99: 5),
              backend('e', sustainable: 3000),
            ],
          },
        ),
      );
      state = DashboardState(ResultsService(bundle));
      await state.load();
    });

    test('ranks best first and puts missing values last', () {
      final ranked = state.rank(state.sortedBackends, Metrics.sustainable);
      expect(ranked.map((b) => b.key), ['b', 'e', 'c', 'a', 'd']);
      final byP99 = state.rank(state.sortedBackends, Metrics.p99);
      expect(byP99.map((b) => b.key).take(3), ['d', 'a', 'b']);
      expect(state.sortScenario, 'no_db'); // the only one
    });

    test('compare holds at most four', () {
      for (final k in ['a', 'b', 'c', 'd', 'e']) {
        state.toggleCompare(k);
      }
      expect(state.compareKeys, ['a', 'b', 'c', 'd']);
      expect(state.canAddCompare('e'), isFalse);
      expect(state.canAddCompare('a'), isTrue);
      state.toggleCompare('a');
      expect(state.canAddCompare('e'), isTrue);
    });

    test('query filters rows by language, ranks ignore it', () {
      state.setQuery('rust');
      expect(state.sortedBackends.map((b) => b.key), ['c']);
      final rank = state.rankOf(
        state.run!.backend('c')!,
        Metrics.sustainable,
        'no_db',
      )!;
      expect((rank.position, rank.total), (3, 5));
      expect(rank.shareOfLeader, 0.5);
      expect(rank.label, 'P3 of 5');
      expect(state.expandFirstMatch('nothing-here'), isFalse);
      expect(state.expandFirstMatch('rust'), isTrue);
      expect(state.expandedKey, 'c');
    });

    test('compare with the leaders fills the tray and opens Compare', () {
      state.compareWithLeaders('a');
      expect(state.compareKeys, ['a', 'b', 'e', 'c']);
      expect(state.page, DashboardPage.compare);
    });

    test('default sort column is DB mixed when present', () {
      expect(
        DashboardState.defaultSortScenario(['no_db', 'db_mixed']),
        'db_mixed',
      );
      expect(DashboardState.defaultSortScenario(['no_db']), 'no_db');
      expect(DashboardState.defaultSortScenario([]), isNull);
    });
  });

  test('history never joins machines or methods', () async {
    Map<String, dynamic> h(num v) => {
      'go-mux': {
        'no_db': {'sustainable_rps': v},
        'no_db_test': {'avg_rps': v},
      },
    };
    final bundle = MapBundle(
      files(
        [
          indexEntry('latest', kind: 'latest', headline: h(9)),
          indexEntry('m1-a', date: '2026-10-01', headline: h(1)),
          indexEntry('m1-b', date: '2026-10-05', headline: h(2)),
          indexEntry('m2-a', machine: 'other', headline: h(3)),
          indexEntry(
            'legacy-v1',
            kind: 'legacy',
            methodology: 'v1',
            date: '2026-02-16',
            headline: h(4),
          ),
        ],
        {
          'latest': [backend('go-mux', sustainable: 9)],
        },
      ),
    );
    final state = DashboardState(ResultsService(bundle));
    await state.load();
    final groups = {
      for (final g in state.historyGroups)
        g: HistoryGroup.build(
          state: state,
          groupKey: g,
          scenario: 'no_db',
          metric: Metrics.sustainable,
          names: const {},
        ),
    };
    expect(
      groups.keys,
      unorderedEquals(['m2pro-10c-32g|v2', 'other|v2', 'm2pro-10c-32g|v1']),
    );
    expect(groups['m2pro-10c-32g|v2']!.runs.map((r) => r.id), ['m1-a', 'm1-b']);
    expect(groups['m2pro-10c-32g|v2']!.lines.single.$3, [1, 2]);
    expect(groups['other|v2']!.lines.single.$3, [3]);
    final legacy = groups['m2pro-10c-32g|v1']!;
    expect(legacy.scenario, 'no_db_test');
    expect(legacy.metric, Metrics.avgRps);
    expect(legacy.lines.single.$3, [4]);
  });

  group('T1 find', () {
    testWidgets('every framework is on the first screen, no filter', (t) async {
      await pumpApp(t, realisticBundle());
      for (final k in ['rust-actix', 'go-mux', 'foam3', 'django-sync']) {
        expect(inSheet(k), findsOneWidget, reason: k);
      }
      expect(inSheet('db-only'), findsOneWidget); // single-scenario too
      // Sorted by DB mixed, best first; 48.0K no_db ties are not the order.
      final rows = ['rust-actix', 'go-mux', 'foam3', 'django-sync', 'db-only'];
      final ys = [for (final k in rows) t.getTopLeft(inSheet(k)).dy];
      expect(ys, [...ys]..sort());
      expect(t.takeException(), isNull);
    });

    testWidgets('search narrows to the typed framework or language', (t) async {
      final state = await pumpApp(t, realisticBundle());
      await t.enterText(find.byType(TextField), 'foam');
      await settle(t);
      expect(inSheet('foam3'), findsOneWidget);
      expect(inSheet('go-mux'), findsNothing);
      await t.enterText(find.byType(TextField), 'python');
      await settle(t);
      expect(inSheet('django-sync'), findsOneWidget);
      expect(inSheet('foam3'), findsNothing);
      await t.enterText(find.byType(TextField), 'zzz');
      await settle(t);
      expect(find.textContaining('No framework matches "zzz"'), findsOneWidget);
      await t.tap(find.byTooltip('Clear search'));
      await settle(t);
      expect(state.query, '');
      expect(inSheet('foam3'), findsOneWidget);
      // The hint comes back once the field is empty again.
      expect(
        t.widget<InputDecorator>(find.byType(InputDecorator)).isEmpty,
        isTrue,
      );
      // Also when the query is cleared from outside the field.
      state.setQuery('go');
      await settle(t);
      state.setQuery('');
      await settle(t);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
      expect(
        t.widget<InputDecorator>(find.byType(InputDecorator)).isEmpty,
        isTrue,
      );
      final hint = find.textContaining('Search name, language');
      expect(hint, findsOneWidget);
      for (final e
          in find
              .ancestor(of: hint, matching: find.byType(FadeTransition))
              .evaluate()) {
        expect((e.widget as FadeTransition).opacity.value, 1.0);
      }
      for (final e
          in find
              .ancestor(of: hint, matching: find.byType(Opacity))
              .evaluate()) {
        expect((e.widget as Opacity).opacity, 1.0);
      }
    });

    testWidgets('Enter expands the first match', (t) async {
      final state = await pumpApp(t, realisticBundle());
      await t.enterText(find.byType(TextField), 'django');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      expect(state.expandedKey, 'django-sync');
    });
  });

  group('T2 numbers at a glance', () {
    testWidgets('one tap shows every scenario, rank and implementation', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(inSheet('go-mux'));
      await settle(t);
      expect(state.expandedKey, 'go-mux');
      // The grid has a column per scenario and the metric rows.
      for (final s in ['No DB', 'DB read', 'DB write', 'DB mixed']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Peak throughput (req/s)'), findsOneWidget);
      expect(find.text('App memory'), findsOneWidget);
      expect(find.textContaining('Rank by'), findsOneWidget);
      // go-mux: tied P1 of 4 in No DB, P2 of 4 in DB read, P2 of 5 in mixed.
      expect(find.text('tied P1 of 4'), findsWidgets);
      expect(find.text('P2 of 4'), findsWidgets);
      expect(find.text('P2 of 5'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget); // 16K of 32K in DB mixed
      // Flags are written out, not hidden in tooltips.
      expect(find.textContaining('load generator was the limit'), findsWidgets);
      for (final v in goImpl.values) {
        expect(find.text(v), findsOneWidget);
      }
      expect(find.text('Source on GitHub'), findsOneWidget);
      // Tapping again collapses.
      await t.tap(inSheet('go-mux'));
      await settle(t);
      expect(state.expandedKey, isNull);
      expect(t.takeException(), isNull);
    });

    testWidgets('a backend missing scenarios shows dashes, not a crash', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(inSheet('db-only'));
      await settle(t);
      expect(state.expandedKey, 'db-only');
      expect(find.text('—'), findsWidgets);
      expect(find.text('P5 of 5'), findsOneWidget);
      expect(find.textContaining('No implementation details'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('notes are printed in full', (t) async {
      await pumpApp(t, realisticBundle());
      await t.tap(inSheet('foam3'));
      await settle(t);
      expect(find.text('Note: Uses its own box RPC.'), findsOneWidget);
    });

    testWidgets('Showing picker switches the number in every cell', (t) async {
      final state = await pumpApp(t, realisticBundle());
      state.setMetric(Metrics.memory);
      await settle(t);
      expect(find.text('100 MB'), findsWidgets);
      expect(find.textContaining('App memory:'), findsOneWidget); // footnote
      expect(t.takeException(), isNull);
    });
  });

  group('T3 compare', () {
    testWidgets('one tap from the open row compares with the leaders', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(inSheet('foam3'));
      await settle(t);
      await t.tap(find.text('Compare with the DB mixed leaders'));
      await settle(t);
      expect(state.page, DashboardPage.compare);
      expect(state.compareKeys, [
        'foam3',
        'rust-actix',
        'go-mux',
        'django-sync',
      ]);
      expect(
        find.text('foam3 vs rust-actix vs go-mux vs django-sync'),
        findsOneWidget,
      );
      expect(
        find.text('Sustainable load (req/s) in every scenario'),
        findsOneWidget,
      );
      expect(find.textContaining('Side by side'), findsOneWidget);
      expect(find.text('IMPLEMENTATION'), findsOneWidget);
      expect(find.text(goImpl['server']!), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('+ Compare on rows fills the tray; the tray opens Compare', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      expect(find.byType(CompareTray), findsOneWidget);
      expect(find.text('Comparing'), findsNothing);
      await t.tap(find.byTooltip('Add rust-actix to compare'));
      await settle(t);
      expect(find.text('Add one more to compare'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      await t.tap(find.byTooltip('Add go-mux to compare'));
      await settle(t);
      expect(state.compareKeys, ['rust-actix', 'go-mux']);
      // The dock chip removes, the row toggle adds back.
      await t.tap(find.byTooltip('Remove go-mux'));
      await settle(t);
      expect(state.compareKeys, ['rust-actix']);
      await t.tap(find.byTooltip('Add go-mux to compare'));
      await settle(t);
      expect(state.compareKeys, hasLength(2));
      expect(find.text('Comparing'), findsOneWidget);
      await t.tap(find.text('Compare 2'));
      await settle(t);
      expect(state.page, DashboardPage.compare);
      // Back returns home with the tray intact.
      await t.tap(find.widgetWithText(TextButton, 'Leaderboard'));
      await settle(t);
      expect(state.page, DashboardPage.home);
      expect(state.compareKeys, hasLength(2));
      expect(find.text('Comparing'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('ties are not painted as wins; missing never loses', (t) async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1')],
          {
            'r1': [
              backend('alpha', sustainable: 8000, p99: 10, dbCpu: 29),
              backend('beta', sustainable: 8000, p99: 20),
            ],
          },
        ),
      );
      final state = await pumpApp(t, bundle);
      state.toggleCompare('alpha');
      state.toggleCompare('beta');
      state.openCompare();
      await settle(t);
      // Sustainable load ties at 8.0K: two '=' markers, no green.
      final tied = find.text('8.0K');
      expect(tied, findsNWidgets(4)); // all-scenario card + table
      for (final e in tied.evaluate()) {
        expect((e.widget as Text).style!.color, isNot(kSignal));
      }
      expect(find.text('='), findsAtLeastNWidgets(4)); // other rows tie too
      // p99 at each one's own load is context: shown, never crowned.
      final p99 = t.widget<Text>(find.text('10.0 ms'));
      expect(p99.style!.color, isNot(kSignal));
      expect(find.text('2.0× slower'), findsNothing);
      // DB CPU exists only for alpha: not green, no delta, after "More rows".
      await t.ensureVisible(find.text('More rows'));
      await settle(t);
      await t.tap(find.text('More rows'));
      await settle(t);
      expect(find.text('Database CPU'), findsOneWidget);
      final dbCpu = t.widget<Text>(find.text('29%'));
      expect(dbCpu.style!.color, isNot(kSignal));
      expect(t.takeException(), isNull);
    });
  });

  group('stale state', () {
    testWidgets('tray and expanded row survive scenario and run switches', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      state.toggleCompare('foam3');
      state.toggleCompare('go-mux');
      state.toggleExpanded('foam3');
      state.setScenario('db_write');
      state.setSortScenario('no_db');
      await settle(t);
      expect(state.compareKeys, ['foam3', 'go-mux']);
      expect(state.expandedKey, 'foam3');
      await t.runAsync(() => state.selectRun(state.index.first));
      await settle(t);
      expect(state.compareKeys, ['foam3', 'go-mux']);
      expect(state.expandedKey, 'foam3');
      expect(state.sortScenario, 'no_db');
      expect(t.takeException(), isNull);
    });

    test('keys the new run lacks are pruned', () async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1'), indexEntry('r2')],
          {
            'r1': [backend('a', sustainable: 1), backend('b', sustainable: 2)],
            'r2': [backend('b', sustainable: 2)],
          },
        ),
      );
      final state = DashboardState(ResultsService(bundle));
      await state.load();
      state.toggleCompare('a');
      state.toggleCompare('b');
      state.toggleExpanded('a');
      state.openDetails('a');
      await state.selectRun(state.index[1]);
      expect(state.compareKeys, ['b']);
      expect(state.expandedKey, isNull);
      expect(state.detailKey, isNull);
      expect(state.page, DashboardPage.home); // details of a vanished key
    });
  });

  group('pages', () {
    testWidgets('details page shows rank, charts section and implementation', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(inSheet('go-mux'));
      await settle(t);
      await t.tap(find.text('Full details and charts'));
      await settle(t);
      expect(state.page, DashboardPage.details);
      expect(state.scenario, 'no_db');
      // Tied for first in No DB: said, not a rank sentence.
      expect(find.text('Tied for P1 with one other'), findsOneWidget);
      expect(find.text('TIED FOR P1'), findsOneWidget);
      expect(find.text('How go-mux is implemented'), findsOneWidget);
      expect(find.text('backends/go/mux'), findsOneWidget);
      expect(find.text('at run commit abc1234'), findsOneWidget);
      // Scenario tabs switch the numbers.
      await t.tap(
        find.descendant(
          of: find.byType(ScenarioTabs),
          matching: find.text('DB mixed'),
        ),
      );
      await settle(t);
      // P2 in DB mixed: who is ahead and behind, and the gap tile.
      expect(find.text('Behind '), findsOneWidget);
      // 2.00× behind rust-actix (32K / 16K) and ahead of foam3 (16K / 8K).
      expect(find.text(' by 2.00×'), findsNWidgets(2));
      expect(find.text('GAP TO P1'), findsOneWidget);
      expect(find.text('Compare with rust-actix'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('details of a backend without the scenario offers others', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      state.openDetails('db-only');
      await settle(t);
      expect(find.textContaining('was not measured in No DB'), findsOneWidget);
      await t.tap(find.widgetWithText(ActionChip, 'DB mixed'));
      await settle(t);
      expect(state.scenario, 'db_mixed');
      expect(find.text('500'), findsWidgets); // the headline, counted up
      expect(t.takeException(), isNull);
    });

    testWidgets('method page: key facts up front, details on demand', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(find.text("How it's measured"));
      await settle(t);
      expect(state.page, DashboardPage.method);
      expect(find.text('CONTENTS'), findsOneWidget);
      // Each section is in the contents rail and has its own card.
      expect(find.text('How load is applied'), findsNWidgets(2));
      expect(find.text('Known limitations'), findsNWidgets(2));
      expect(find.text('08'), findsNWidgets(2));
      // The definition and the scenarios start open.
      expect(find.text('fewer than 1% of requests'), findsOneWidget);
      // Key facts are visible without opening anything.
      expect(find.text('median of 3'), findsOneWidget);
      expect(find.text('250 to 1k req/s'), findsOneWidget);
      // Details stay closed until asked for.
      expect(find.textContaining('tests the midpoint'), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);
      // A contents entry (the rail, last in the tree) opens its section.
      await t.tap(find.text('How load is applied').last);
      await settle(t);
      expect(find.textContaining('tests the midpoint'), findsOneWidget);
      // So does tapping the section header.
      await t.ensureVisible(find.text('Hardware and this run').first);
      await settle(t);
      await t.tap(find.text('Hardware and this run').first);
      await settle(t);
      expect(find.text('commit abc1234'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget); // run picker
      await t.tap(find.text('Known limitations').last);
      await settle(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('header "Data" pill lists runs and links to the method', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      expect(find.text('Data: 2026-10-04 · CPU m2pro-10c-32g'), findsOneWidget);
      await t.tap(find.textContaining('Data:'));
      await settle(t);
      expect(find.text('SHOW RESULTS FROM'), findsOneWidget);
      await t.tap(find.text('About this run and how it was measured'));
      await settle(t);
      expect(state.page, DashboardPage.method);
    });

    testWidgets('header "Data" pill switches the run in place', (t) async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1'), indexEntry('r2', date: '2026-10-05')],
          {
            'r1': [backend('a', sustainable: 1)],
            'r2': [backend('a', sustainable: 2)],
          },
        ),
      );
      final state = await pumpApp(t, bundle);
      expect(state.entry!.id, 'r1');
      await t.tap(find.textContaining('Data:'));
      await settle(t);
      await t.runAsync(() async {
        await t.tap(find.textContaining('2026-10-05 ·').last);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await t.pump();
        }
      });
      await settle(t);
      expect(state.entry!.id, 'r2');
      expect(state.page, DashboardPage.home);
    });
  });

  group('selectable text', () {
    testWidgets('texts are inside a SelectionArea and taps still work', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      expect(
        find.ancestor(
          of: inSheet('foam3'),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
      await t.tap(inSheet('foam3'));
      await settle(t);
      expect(state.expandedKey, 'foam3');
      expect(
        find.ancestor(
          of: find.text('Note: Uses its own box RPC.'),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
    });
  });

  group('narrow width', () {
    testWidgets('400 px: find, expand and compare without overflow', (t) async {
      final state = await pumpApp(
        t,
        realisticBundle(),
        size: const Size(400, 1600),
      );
      expect(inSheet('foam3'), findsOneWidget);
      await t.tap(inSheet('foam3'));
      await settle(t);
      expect(state.expandedKey, 'foam3');
      expect(find.text('Peak throughput (req/s)'), findsOneWidget);
      await t.ensureVisible(find.text('Compare with the DB mixed leaders'));
      await settle(t);
      await t.tap(find.text('Compare with the DB mixed leaders'));
      await settle(t);
      expect(state.page, DashboardPage.compare);
      expect(find.textContaining('Side by side'), findsOneWidget);
      expect(find.text('IMPLEMENTATION'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('400 px: the scenario can be ranked without the table', (
      t,
    ) async {
      final state = await pumpApp(
        t,
        realisticBundle(),
        size: const Size(400, 1600),
      );
      expect(state.sortScenario, 'db_mixed');
      expect(find.text('RANK BY'), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(ScenarioTabs),
          matching: find.text('DB read'),
        ),
      );
      await settle(t);
      expect(state.sortScenario, 'db_read');
      expect(t.takeException(), isNull);
    });
  });

  group('round 1 additions', () {
    testWidgets('the podium names each scenario winner and ranks on tap', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      // Two frameworks tie at the load generator's limit in No DB: said as
      // such, not as a single winner.
      final photo = find.text('2-way photo finish');
      expect(photo, findsOneWidget);
      // (DB write has a plain two-way tie too.)
      expect(find.text('2-way tie'), findsOneWidget);
      // The headline answers: rust-actix leads DB read and DB mixed alone.
      expect(find.text('rust-actix leads 2 of 4 scenarios'), findsOneWidget);
      expect(
        find.text('DB read and DB mixed: 1.33× to 2.00× ahead of go-mux.'),
        findsOneWidget,
      );
      expect(find.textContaining('No DB is a 2-way photo finish'), findsOne);
      // DB mixed: rust-actix 32K leads go-mux 16K by 2×.
      expect(find.text('2.00× ahead of go-mux'), findsOneWidget);
      await t.tap(photo);
      await settle(t);
      expect(state.sortScenario, 'no_db');
      expect(t.takeException(), isNull);
    });

    testWidgets('rows are reachable and expandable with the keyboard', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      Focus.of(t.element(inSheet('go-mux'))).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(t);
      expect(state.expandedKey, 'go-mux');
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(t);
      expect(state.expandedKey, isNull);
    });

    testWidgets('"/" focuses the search field', (t) async {
      await pumpApp(t, realisticBundle());
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isFalse);
      await t.sendKeyEvent(LogicalKeyboardKey.slash);
      await settle(t);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.controller!.text, ''); // the slash is not typed in
    });

    testWidgets('lower-is-better metrics keep "longer bar is better"', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      expect(find.text('HIGHER IS BETTER'), findsOneWidget);
      state.setMetric(Metrics.p99);
      await settle(t);
      expect(find.text('LOWER IS BETTER'), findsOneWidget);
      // Latency is context, not a race: the headline says so, and no P1
      // is crowned in lime.
      expect(
        find.text('Lowest p99 latency, each at its own sustainable load'),
        findsOneWidget,
      );
      expect(find.text('P99 LATENCY · CONTEXT, NOT A RACE'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('links round-trip through the state', () async {
      final state = DashboardState(ResultsService(realisticBundle()));
      await state.load();
      applyLocation(state, Uri.parse('/compare/go-mux,foam3,nope?s=db_read'));
      expect(state.page, DashboardPage.compare);
      expect(state.compareKeys, ['go-mux', 'foam3']);
      expect(state.scenario, 'db_read');
      expect(locationOf(state).toString(), '/compare/go-mux,foam3?s=db_read');
      applyLocation(state, Uri.parse('/f/rust-actix?s=db_write'));
      expect(
        (state.page, state.detailKey),
        (DashboardPage.details, 'rust-actix'),
      );
      expect(locationOf(state).toString(), '/f/rust-actix?s=db_write');
      applyLocation(state, Uri.parse('/f/vanished'));
      expect(state.page, DashboardPage.home);
      applyLocation(state, Uri.parse('/method'));
      expect(state.page, DashboardPage.method);
      applyLocation(state, Uri.parse('/nowhere'));
      expect(state.page, DashboardPage.home);
      expect(locationOf(state).toString(), '/');
    });

    test('text colours meet WCAG AA on cards', () {
      double lum(Color c) {
        double ch(double v) => v <= 0.03928
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
      }

      double contrast(Color a, Color b) {
        final x = lum(a), y = lum(b);
        return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
      }

      for (final c in [kTextPrimary, kTextSecondary, kTextMuted, kTextDim]) {
        expect(contrast(c, kCardBg), greaterThanOrEqualTo(4.5));
        expect(contrast(c, kCardBgRaised), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('round 2', () {
    test('numbers are honest: whole req/s, no "-100%", longer is better', () {
      expect(formatMetric(Metrics.sustainable, 258), '258 req/s');
      expect(formatMetricShort(Metrics.avgRps, 47.2), '47');
      expect(formatMetricShort(Metrics.p99, 47.2), '47.2 ms');
      // 258 vs 55.1K is 99.5% behind: a ratio, not a rounded "−100%".
      expect(gapToLeader(Metrics.sustainable, 258, 55100), '214× behind');
      expect(gapToLeader(Metrics.sustainable, 30000, 40000), '−25%');
      expect(barShare(Metrics.p99, 20, 10), 0.5);
      expect(barShare(Metrics.sustainable, 20, 40), 0.5);
      expect(
        shortRunId('2026-10-04_m2pro-10c-32g_3ae75a8_cea6'),
        '2026-10-04 · 3ae75a8',
      );
    });

    test('a full tray is never emptied behind the user\'s back', () async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1')],
          {
            'r1': [
              for (final (k, v) in [
                ('a', 1),
                ('b', 2),
                ('c', 3),
                ('d', 4),
                ('e', 5),
              ])
                backend(k, sustainable: v),
            ],
          },
        ),
      );
      final state = DashboardState(ResultsService(bundle));
      await state.load();
      for (final k in ['a', 'b', 'c', 'd']) {
        state.toggleCompare(k);
      }
      expect(state.compareWithLeaders('e'), isFalse);
      expect(state.compareKeys, ['a', 'b', 'c', 'd']);
      expect(state.page, DashboardPage.home);
      expect(state.comparePair('e', 'a'), isFalse);
      state.toggleCompare('d');
      expect(state.comparePair('e', 'a'), isTrue);
      expect(state.compareKeys, ['a', 'b', 'c', 'e']);
      expect(state.page, DashboardPage.compare);
    });

    test('picks a run lacks are parked and come back', () async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1'), indexEntry('r2')],
          {
            'r1': [backend('a', sustainable: 1), backend('b', sustainable: 2)],
            'r2': [backend('b', sustainable: 2)],
          },
        ),
      );
      final state = DashboardState(ResultsService(bundle));
      await state.load();
      state.toggleCompare('a');
      state.toggleCompare('b');
      await state.selectRun(state.index[1]);
      expect(state.compareKeys, ['b']);
      expect(state.parkedCompare, ['a']);
      await state.selectRun(state.index[0]);
      expect(state.compareKeys, ['b', 'a']);
      expect(state.parkedCompare, isEmpty);
    });

    test('v1 results show today\'s names and keep the old one', () async {
      final legacyRun = {
        'id': 'legacy-v1',
        'kind': 'legacy',
        'methodology': 'v1',
        'machine': {'slug': 'm', 'cpu': 'CPU', 'cores': 1, 'ram_gb': 1},
        'params': {},
        'backends': [
          {
            'key': 'go-mux',
            'name': 'golang mux',
            'language': 'go',
            'scenarios': {
              'no_db_test': {'avg_rps': stat(700)},
            },
          },
        ],
      };
      final bundle = MapBundle({
        'assets/results/index.json': jsonEncode({
          'runs': [
            {
              ...indexEntry('r1'),
              'names': {'go-mux': 'go mux'},
            },
            {
              ...indexEntry('legacy-v1', kind: 'legacy', methodology: 'v1'),
              'names': {'go-mux': 'golang mux'},
            },
          ],
        }),
        'assets/results/runs/r1.json': files(
          [indexEntry('r1')],
          {
            'r1': [backend('go-mux', sustainable: 1)],
          },
        )['assets/results/runs/r1.json']!,
        'assets/results/runs/legacy-v1.json': jsonEncode(legacyRun),
      });
      final state = DashboardState(ResultsService(bundle));
      await state.load();
      await state.selectRun(state.index[1]);
      final b = state.run!.backend('go-mux')!;
      expect(b.name, 'go mux');
      expect(b.subtitle, contains('v1 name: golang mux'));
      expect(Metrics.avgRps.value(b.scenarios['no_db_test']!), 700);
    });

    testWidgets('compare adds a like-for-like row and replays the steps', (
      t,
    ) async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1')],
          {
            'r1': [
              steppedBackend('alpha', 1000, [
                step(250, p99: 5),
                step(500, p99: 8),
                step(1000, p99: 12),
              ]),
              steppedBackend('beta', 500, [
                step(250, p99: 9),
                step(500, p99: 30),
                step(1000, served: 900, p99: 150, pass: false),
              ]),
            ],
          },
        ),
      );
      final state = await pumpApp(t, bundle, size: const Size(1400, 2400));
      state.toggleCompare('alpha');
      state.toggleCompare('beta');
      state.setScenario('db_mixed');
      state.openCompare();
      await settle(t);
      expect(find.textContaining('alpha wins all 1'), findsOneWidget);
      // Both held 500 req/s: p99 there is like for like, best in lime.
      expect(find.text('AT A SHARED LOAD · 500 REQ/S'), findsOneWidget);
      final shared = t.widget<Text>(find.text('8.00 ms'));
      expect(shared.style!.color, kSignal);
      expect(find.text('3.8× slower'), findsNWidgets(2)); // p99 and median
      // The replay ends on the last recorded step.
      expect(find.text('Watch the load climb'), findsOneWidget);
      expect(
        find.textContaining('out at 1.0K: p99 150 ms, served 90%'),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('Replay the race'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('250 req/s'), findsOneWidget); // back at the start
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    });

    testWidgets('the method example skips a result the load generator capped', (
      t,
    ) async {
      final bundle = MapBundle(
        files(
          [indexEntry('r1')],
          {
            'r1': [
              steppedBackend('capped', 2000, [
                step(1000),
                step(2000),
                step(4000, served: 2100, p99: 300, pass: false, k6: true),
              ], loadgenBound: true),
              steppedBackend('free', 1000, [
                step(500),
                step(1000, p99: 60),
                step(2000, served: 1500, p99: 250, pass: false),
              ]),
            ],
          },
        ),
      );
      final state = await pumpApp(t, bundle);
      state.setPage(DashboardPage.method);
      await settle(t);
      expect(
        find.textContaining(
          'free (the best framework the load generator did not cap)',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('First failure at 2k: p99 250 ms, served 75%'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('400 px: "Showing" is one menu with every metric', (t) async {
      final state = await pumpApp(
        t,
        realisticBundle(),
        size: const Size(400, 1600),
      );
      await t.tap(find.byTooltip('Choose the number shown'));
      await settle(t);
      await t.tap(find.text('p99 latency').last);
      await settle(t);
      expect(state.metric, Metrics.p99);
      // Context metric: no lime leader, said as the lowest.
      expect(find.text('TIED LOWEST'), findsWidgets);
      expect(find.text('LEADER'), findsNothing);
      expect(t.takeException(), isNull);
    });

    test('text on the strongest heat cell stays readable', () {
      double lum(Color c) {
        double ch(double v) => v <= 0.03928
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
      }

      // The full-share tint (lime at 33%) over a raised card.
      final bg = Color.alphaBlend(
        kSignal.withValues(alpha: 0.33),
        kCardBgRaised,
      );
      final a = lum(kTextPrimary), b = lum(bg);
      expect(
        (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05),
        greaterThan(4.5),
      );
    });
  });
}
