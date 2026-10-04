import 'dart:convert';

import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/models/metrics.dart';
import 'package:benchmark_app/models/results.dart';
import 'package:benchmark_app/screens/history_screen.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:benchmark_app/utils/formatters.dart';
import 'package:benchmark_app/widgets/compare_tray.dart';
import 'package:flutter/material.dart';
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
}) => {
  'reps': 3,
  'sustainable_rps': ?(sustainable == null ? null : stat(sustainable)),
  'peak_rps': stat((sustainable ?? 0) * 1.2),
  'p99_ms': ?(p99 == null ? null : stat(p99)),
  'app_cpu': stat(cpu),
  'app_mem_mb': stat(mem),
  'db_cpu': ?(dbCpu == null ? null : stat(dbCpu)),
  'loadgen_bound': loadgenBound,
  'steps': [],
  'timeseries': {},
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

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  group('models', () {
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
      expect(formatMetric(Metrics.sustainable, 40000), '40.0K rps');
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
      expect(rank.label, '#3 of 5');
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
        expect(find.text(k), findsOneWidget, reason: k);
      }
      expect(find.text('db-only'), findsOneWidget); // single-scenario too
      // Sorted by DB mixed, best first; 48.0K no_db ties are not the order.
      final rows = ['rust-actix', 'go-mux', 'foam3', 'django-sync', 'db-only'];
      final ys = [for (final k in rows) t.getTopLeft(find.text(k)).dy];
      expect(ys, [...ys]..sort());
      expect(t.takeException(), isNull);
    });

    testWidgets('search narrows to the typed framework or language', (t) async {
      final state = await pumpApp(t, realisticBundle());
      await t.enterText(find.byType(TextField), 'foam');
      await settle(t);
      expect(find.text('foam3'), findsOneWidget);
      expect(find.text('go-mux'), findsNothing);
      await t.enterText(find.byType(TextField), 'python');
      await settle(t);
      expect(find.text('django-sync'), findsOneWidget);
      expect(find.text('foam3'), findsNothing);
      await t.enterText(find.byType(TextField), 'zzz');
      await settle(t);
      expect(find.textContaining('No framework matches "zzz"'), findsOneWidget);
      await t.tap(find.byTooltip('Clear search'));
      await settle(t);
      expect(state.query, '');
      expect(find.text('foam3'), findsOneWidget);
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
      final hint = find.textContaining('Find your framework');
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
      await t.tap(find.text('go-mux'));
      await settle(t);
      expect(state.expandedKey, 'go-mux');
      // The grid has a column per scenario and the metric rows.
      for (final s in ['No DB', 'DB read', 'DB write', 'DB mixed']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Peak throughput'), findsOneWidget);
      expect(find.text('App memory'), findsOneWidget);
      expect(find.textContaining('Rank by'), findsOneWidget);
      // go-mux: tied #1 of 4 in No DB, #2 of 4 in DB read, #2 of 5 in mixed.
      expect(find.text('tied #1 of 4'), findsWidgets);
      expect(find.text('#2 of 4'), findsWidgets);
      expect(find.text('#2 of 5'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget); // 16K of 32K in DB mixed
      // Flags are written out, not hidden in tooltips.
      expect(find.textContaining('load generator was the limit'), findsWidgets);
      for (final v in goImpl.values) {
        expect(find.text(v), findsOneWidget);
      }
      expect(find.text('Source on GitHub'), findsOneWidget);
      // Tapping again collapses.
      await t.tap(find.text('go-mux'));
      await settle(t);
      expect(state.expandedKey, isNull);
      expect(t.takeException(), isNull);
    });

    testWidgets('a backend missing scenarios shows dashes, not a crash', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(find.text('db-only'));
      await settle(t);
      expect(state.expandedKey, 'db-only');
      expect(find.text('—'), findsWidgets);
      expect(find.text('#5 of 5'), findsOneWidget);
      expect(find.textContaining('No implementation details'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('notes are printed in full', (t) async {
      await pumpApp(t, realisticBundle());
      await t.tap(find.text('foam3'));
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
      await t.tap(find.text('foam3'));
      await settle(t);
      await t.tap(find.text('Compare with the leaders'));
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
      expect(find.text('Sustainable load in every scenario'), findsOneWidget);
      expect(find.textContaining('Side by side'), findsOneWidget);
      expect(find.text('Implementation'), findsOneWidget);
      expect(find.text(goImpl['server']!), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('+ Compare on rows fills the tray; the tray opens Compare', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      expect(find.byType(CompareTray), findsOneWidget);
      expect(find.text('Comparing'), findsNothing);
      final buttons = find.widgetWithText(OutlinedButton, 'Compare');
      await t.tap(buttons.first);
      await settle(t);
      expect(find.text('Add one more to compare'), findsOneWidget);
      await t.tap(find.widgetWithText(OutlinedButton, 'Compare').first);
      await settle(t);
      expect(state.compareKeys, hasLength(2));
      expect(find.text('Comparing'), findsOneWidget);
      await t.tap(find.text('Compare 2'));
      await settle(t);
      expect(state.page, DashboardPage.compare);
      // Back returns home with the tray intact.
      await t.tap(find.text('All frameworks').first);
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
        expect((e.widget as Text).style!.color, isNot(const Color(0xFF3FB950)));
      }
      expect(find.text('='), findsAtLeastNWidgets(4)); // other rows tie too
      // p99: alpha wins (10 ms), beta is 2.0× slower.
      final p99 = t.widget<Text>(find.text('10.0 ms'));
      expect(p99.style!.color, const Color(0xFF3FB950));
      expect(find.text('2.0× slower'), findsOneWidget);
      // DB CPU exists only for alpha: not green, no delta, after "More rows".
      await t.tap(find.text('More rows'));
      await settle(t);
      expect(find.text('Database CPU'), findsOneWidget);
      final dbCpu = t.widget<Text>(find.text('29%'));
      expect(dbCpu.style!.color, isNot(const Color(0xFF3FB950)));
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
      await t.tap(find.text('go-mux'));
      await settle(t);
      await t.tap(find.text('Full details and charts'));
      await settle(t);
      expect(state.page, DashboardPage.details);
      expect(state.scenario, 'no_db');
      expect(
        find.textContaining('tied #1 of 4 by sustainable load in No DB'),
        findsOneWidget,
      );
      expect(find.text('How go-mux is implemented'), findsOneWidget);
      expect(find.text('backends/go/mux'), findsOneWidget);
      expect(find.text('at run commit abc1234'), findsOneWidget);
      // Scenario chips switch the numbers.
      await t.tap(find.widgetWithText(ChoiceChip, 'DB mixed'));
      await settle(t);
      expect(
        find.textContaining('#2 of 5 by sustainable load in DB mixed'),
        findsOneWidget,
      );
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
      expect(find.text('500 rps'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('method page has contents, run picker and params', (t) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(find.text("How it's measured"));
      await settle(t);
      expect(state.page, DashboardPage.method);
      expect(find.text('Contents'), findsOneWidget);
      expect(find.text('1. Overview'), findsOneWidget);
      expect(find.text('9. Known limitations'), findsOneWidget);
      expect(
        find.textContaining('3 steps, 250 to 1,000 req/s'),
        findsOneWidget,
      );
      expect(find.textContaining('tests the midpoint'), findsOneWidget);
      expect(find.text('commit abc1234'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget); // run picker
      await t.tap(find.text('9. Known limitations'));
      await settle(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('header "Data" link opens the Method page', (t) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(find.textContaining('Data:'));
      await settle(t);
      expect(state.page, DashboardPage.method);
    });
  });

  group('selectable text', () {
    testWidgets('texts are inside a SelectionArea and taps still work', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      expect(
        find.ancestor(
          of: find.text('foam3'),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
      await t.tap(find.text('foam3'));
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
      expect(find.text('foam3'), findsOneWidget);
      await t.tap(find.text('foam3'));
      await settle(t);
      expect(state.expandedKey, 'foam3');
      expect(find.text('Peak throughput'), findsOneWidget);
      await t.tap(find.text('Compare with the leaders'));
      await settle(t);
      expect(state.page, DashboardPage.compare);
      expect(find.textContaining('Side by side'), findsOneWidget);
      expect(find.text('Implementation'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  });
}
