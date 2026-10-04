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

import 'support.dart';

Map<String, dynamic> stat(num v) => {'median': v, 'min': v, 'max': v};

Map<String, dynamic> backend(
  String key, {
  String language = 'go',
  num? sustainable,
  num? p99,
  num? dbCpu,
  String scenario = 'no_db',
}) => {
  'key': key,
  'name': key,
  'language': language,
  'status': 'ok',
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
      'params': {'reps': 3},
      'backends': e.value,
    }),
};

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
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('with-p99'), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
