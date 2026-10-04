import 'dart:convert';

import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/models/metrics.dart';
import 'package:benchmark_app/models/results.dart';
import 'package:benchmark_app/screens/history_screen.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:benchmark_app/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support.dart';

Map<String, dynamic> stat(num v) => {'median': v, 'min': v, 'max': v};

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
}) => {
  'key': key,
  'name': key,
  'language': language,
  'status': 'ok',
  'path': ?path,
  'implementation': ?implementation,
  'implementation_from': ?implementationFrom,
  'scenarios': {
    scenario: {
      'reps': 3,
      'sustainable_rps': ?(sustainable == null ? null : stat(sustainable)),
      'peak_rps': stat((sustainable ?? 0) * 1.2),
      'p99_ms': ?(p99 == null ? null : stat(p99)),
      'app_cpu': stat(150),
      'app_mem_mb': stat(100),
      'db_cpu': ?(dbCpu == null ? null : stat(dbCpu)),
      'steps': [],
      'timeseries': {},
    },
  },
};

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
      'params': {'reps': 3},
      'backends': e.value,
    }),
};

const goImpl = {
  'server': 'net/http with gorilla/mux',
  'concurrency': 'goroutine per request',
  'db_access': 'database/sql with lib/pq',
  'pool': '20 (SetMaxOpenConns)',
};

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
      expect(b.implementation!.summary, contains(' · '));
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
      final ranked = state.rank(state.visibleBackends, Metrics.sustainable);
      expect(ranked.map((b) => b.key), ['b', 'e', 'c', 'a', 'd']);
      final byP99 = state.rank(state.visibleBackends, Metrics.p99);
      expect(byP99.map((b) => b.key).take(3), ['d', 'a', 'b']);
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

    test('language filter narrows visible backends', () {
      state.toggleLanguage('rust');
      expect(state.visibleBackends.map((b) => b.key), ['c']);
      state.clearLanguages();
      expect(state.visibleBackends, hasLength(5));
    });

    test('query filters, Enter opens the best match, and ranks ignore it', () {
      state.setQuery('rust');
      expect(state.visibleBackends.map((b) => b.key), ['c']);
      expect(state.filtersActive, isTrue);
      // c is 3rd of 5 by sustainable load whatever the filter says.
      final rank = state.rankOf(state.run!.backend('c')!, Metrics.sustainable)!;
      expect((rank.position, rank.total), (3, 5));
      expect(rank.shareOfLeader, 0.5);
      expect(state.openBestMatch('nothing-here'), isFalse);
      expect(state.openBestMatch('go'), isTrue); // best-ranked go backend
      expect(state.detailKey, 'b');
      expect(state.tab, DashboardTab.framework);
    });

    test('prev/next walk every backend by name', () {
      state.setDetail('a');
      state.stepDetail(1);
      expect(state.detailKey, 'b');
      state.stepDetail(-2);
      expect(state.detailKey, 'e'); // wraps
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

  testWidgets('overview shows a dash for a missing value', (t) async {
    final bundle = MapBundle(
      files(
        [indexEntry('r1')],
        {
          'r1': [
            backend('with-p99', sustainable: 2000, p99: 12),
            backend('no-p99', sustainable: 1000),
          ],
        },
      ),
    );
    await pumpApp(t, bundle);
    expect(find.text('Leaderboard'), findsWidgets);
    expect(find.text('with-p99'), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  group('framework tab', () {
    late MapBundle bundle;

    setUp(() {
      bundle = MapBundle(
        files(
          [indexEntry('r1')],
          {
            'r1': [
              backend(
                'go-mux',
                sustainable: 4000,
                path: 'go/mux',
                implementation: goImpl,
                implementationFrom: 'manifest',
              ),
              backend(
                'rust-actix',
                language: 'rust',
                sustainable: 8000,
                path: 'rust/actix-web',
              ),
              backend('db-only', sustainable: 500, scenario: 'db_mixed'),
            ],
          },
        ),
      );
    });

    testWidgets('implementation card shows facts, rank and source', (t) async {
      final state = await pumpApp(t, bundle);
      state.openFramework('go-mux');
      await t.pump();
      for (final v in goImpl.values) {
        expect(find.text(v), findsOneWidget);
      }
      expect(find.text('backends/go/mux'), findsOneWidget);
      expect(find.text('at run commit abc1234'), findsOneWidget);
      expect(
        find.textContaining('#2 of 2 by sustainable load in No DB'),
        findsOneWidget,
      );
      expect(find.textContaining('50% of the leader'), findsOneWidget);
      expect(
        find.textContaining('come from the current source'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('missing implementation has a fallback, not a crash', (
      t,
    ) async {
      final state = await pumpApp(t, bundle);
      state.openFramework('rust-actix');
      await t.pump();
      expect(find.textContaining('No implementation details'), findsOneWidget);
      expect(find.text('backends/rust/actix-web'), findsOneWidget);
      expect(find.textContaining('the leader'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('finder opens the typed framework; prev/next walk', (t) async {
      final state = await pumpApp(t, bundle);
      state.setTab(DashboardTab.framework);
      await t.pump();
      final field = find.byType(TextField).last;
      await t.tap(field);
      await t.pump();
      await t.enterText(field, 'rust');
      await t.pump();
      expect(find.text('rust-actix'), findsWidgets); // in the options list
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(state.detailKey, 'rust-actix');
      await t.tap(find.byTooltip('Next framework'));
      await t.pump();
      expect(state.detailKey, 'db-only');
      expect(t.takeException(), isNull);
    });

    testWidgets('no result in this scenario offers the ones it has', (t) async {
      final state = await pumpApp(t, bundle);
      state.openFramework('db-only');
      await t.pump();
      expect(find.textContaining('was not measured in No DB'), findsOneWidget);
      await t.tap(find.widgetWithText(ActionChip, 'DB mixed'));
      await t.pump();
      expect(state.scenario, 'db_mixed');
      expect(find.text('500 rps'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('header find field filters the leaderboard', (t) async {
      final state = await pumpApp(t, bundle);
      await t.enterText(find.byType(TextField).first, 'zzz');
      await t.pump();
      expect(find.textContaining('No framework matches "zzz"'), findsOneWidget);
      await t.tap(find.byTooltip('Clear'));
      await t.pump();
      expect(state.query, '');
      expect(find.text('go-mux'), findsWidgets);
    });

    testWidgets('compare table has implementation rows', (t) async {
      final state = await pumpApp(t, bundle);
      state.toggleCompare('go-mux');
      state.toggleCompare('rust-actix');
      state.setTab(DashboardTab.compare);
      await t.pump();
      expect(find.text('Compare (2)'), findsOneWidget);
      expect(find.text('Implementation'), findsOneWidget);
      expect(find.text(goImpl['server']!), findsOneWidget);
      expect(find.text('backends/rust/actix-web'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('method tab explains the run', (t) async {
      final state = await pumpApp(t, bundle);
      await t.tap(find.text("How it's measured"));
      await t.pump();
      expect(state.tab, DashboardTab.method);
      expect(find.text('What is measured'), findsOneWidget);
      expect(find.text('r1'), findsOneWidget);
      expect(find.text('commit abc1234'), findsOneWidget);
      expect(find.textContaining('repeated 3 times'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('selection survives a run switch', (t) async {
      final state = await pumpApp(t, bundle);
      state.openFramework('rust-actix');
      state.setQuery('go');
      await t.runAsync(() => state.selectRun(state.index.first));
      await t.pump();
      expect(state.detailKey, 'rust-actix');
      expect(state.visibleBackends.map((b) => b.key), ['go-mux']);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('leader strip reports ties instead of picking a winner', (
    t,
  ) async {
    final bundle = MapBundle(
      files(
        [indexEntry('r1')],
        {
          'r1': [
            backend('alpha', sustainable: 48000, p99: 60),
            backend('beta', sustainable: 48000, p99: 59),
            backend('gamma', sustainable: 12000, p99: 9),
          ],
        },
      ),
    );
    t.view.physicalSize = const Size(1400, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() async {
      await t.pumpWidget(BenchmarkApp(service: ResultsService(bundle)));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await t.pump();
      }
    });
    expect(find.text('2 tied'), findsWidgets); // load and rps/core both tie
    expect(t.takeException(), isNull);
  });
}
