import 'dart:convert';

import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/models/plain.dart';
import 'package:benchmark_app/models/results.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart' hide closeTo;
import 'package:material_ui/material_ui.dart';
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

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  // An opened row scrolls into view after its first frame, and a scroll
  // animation ignores taps until the frame after it ends.
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

/// Two runs of the realistic data; the second lacks foam3.
MapBundle twoRunBundle() {
  final first =
      jsonDecode(realisticBundle().files['assets/results/runs/r1.json']!)
          as Map<String, dynamic>;
  final second = Map<String, dynamic>.of(first)
    ..['id'] = 'r0'
    ..['date'] = '2026-09-01'
    ..['backends'] = (first['backends'] as List)
        .where((b) => (b as Map)['key'] != 'foam3')
        .toList();
  return MapBundle({
    'assets/results/index.json': jsonEncode({
      'runs': [indexEntry('r1'), indexEntry('r0', date: '2026-09-01')],
    }),
    'assets/results/runs/r1.json': jsonEncode(first),
    'assets/results/runs/r0.json': jsonEncode(second),
  });
}

BackendResult fakeBackend(String key) => BackendResult.fromJson({
  'key': key,
  'name': key,
  'language': 'go',
  'status': 'ok',
  'scenarios': {'db_mixed': scenarioJson(sustainable: 1)},
});

Result res(
  String key,
  double v, {
  double? low,
  double? high,
  bool capped = false,
}) => Result(
  backend: fakeBackend(key),
  value: v,
  low: low ?? v,
  high: high ?? v,
  capped: capped,
);

void main() {
  group('plain-language helpers', () {
    test('whole numbers use thousands separators', () {
      expect(whole(40000), '40,000');
      expect(whole(450), '450');
      expect(whole(1234567.4), '1,234,567');
    });

    test('runs whose ranges overlap are too close to call', () {
      final all = [
        res('a', 5000, low: 4000, high: 6000),
        res('b', 4500, low: 4400, high: 4600),
        res('c', 3000, low: 2900, high: 3100),
      ];
      expect(closeTo(all, all[0]).map((r) => r.key), ['b']);
      expect(closeTo(all, all[2]), isEmpty);
      expect(closeSentence(all, all[0]), contains('b'));
    });

    test('bands group by round numbers, highest first', () {
      final bands = bandsFor([
        res('fast', 32000),
        res('mid', 16000),
        res('slow', 8000),
        res('slower', 500),
      ]);
      expect(bands.map((b) => b.label), [
        '30,000 or more',
        '10,000 to 20,000',
        'Under 10,000',
      ]);
      expect(bands.last.members.map((r) => r.key), ['slow', 'slower']);
    });

    test('a capped band says the tool was the limit', () {
      final band = bandsFor([
        res('a', 48000, capped: true),
        res('b', 48000, capped: true),
      ]).single;
      expect(band.cappedNote, contains('could send'));
      expect(band.cappedNote, contains('cannot tell them apart'));
    });

    test('the answer names the leader from the data, not fixed text', () {
      final answer = answerFor([res('zeta', 9000), res('alpha', 3000)]);
      expect(answer, startsWith('Zeta handled the most'));
      expect(answer, contains('9,000'));
      expect(answerFor([]), contains('No framework'));
    });
  });

  group('home page', () {
    testWidgets('opens on the short answer with plain bands', (t) async {
      final state = await pumpApp(t, realisticBundle());
      expect(state.view, HomeView.short);
      expect(
        find.text('How much traffic can each backend framework handle?'),
        findsOneWidget,
      );
      expect(find.text('Show me'), findsOneWidget);
      expect(find.text('30,000 or more'), findsWidgets);
      expect(find.text('Under 10,000'), findsWidgets);
      // No internal test names anywhere on the page.
      expect(find.textContaining('db_mixed'), findsNothing);
      expect(find.textContaining('DB mixed'), findsNothing);
    });

    testWidgets('a name opens its number in place', (t) async {
      await pumpApp(t, realisticBundle());
      await t.tap(find.text('go-mux').first);
      await settle(t);
      expect(find.text('All results for go-mux'), findsOneWidget);
      expect(find.textContaining('16,000'), findsWidgets);
    });

    testWidgets('All results opens One framework on that name', (t) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(find.text('go-mux').first);
      await settle(t);
      await t.ensureVisible(find.text('All results for go-mux'));
      await t.tap(find.text('All results for go-mux'));
      await settle(t);
      expect(state.view, HomeView.one);
      expect(state.selectedKey, 'go-mux');
    });

    testWidgets('One framework shows the notes from the data', (t) async {
      final state = await pumpApp(t, realisticBundle());
      state.selectFramework('foam3');
      await settle(t);
      expect(find.text('Uses its own box RPC.'), findsWidgets);
      expect(find.textContaining('of the other'), findsWidgets);
    });

    testWidgets('the Show me switch changes the view', (t) async {
      final state = await pumpApp(t, realisticBundle());
      for (final v in HomeView.values) {
        await t.tap(find.text(v.label).first);
        await settle(t);
        expect(state.view, v);
      }
    });
  });

  group('every number', () {
    testWidgets('sorting the same column twice flips it', (t) async {
      final state = await pumpApp(t, realisticBundle());
      state.setView(HomeView.all);
      await settle(t);
      state.sortBy('db_read');
      expect((state.sortTest, state.sortDesc), ('db_read', true));
      state.sortBy('db_read');
      expect(state.sortDesc, isFalse);
      state.sortBy(DashboardState.sortByName);
      expect(state.sortTest, DashboardState.sortByName);
    });

    testWidgets('the measure can switch away from requests a second', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      state.setView(HomeView.all);
      for (final m in Measure.values) {
        state.setMeasure(m);
        await settle(t);
        expect(state.measure, m);
        expect(t.takeException(), isNull);
      }
    });
  });

  group('compare', () {
    testWidgets('holds at most four and never drops a pick', (t) async {
      final state = await pumpApp(t, realisticBundle());
      for (final k in ['rust-actix', 'go-mux', 'foam3', 'django-sync']) {
        state.toggleCompare(k);
      }
      expect(state.compareKeys.length, DashboardState.maxCompare);
      expect(state.canAddCompare('db-only'), isFalse);
      state.toggleCompare('db-only');
      expect(state.compareKeys, isNot(contains('db-only')));
      state.setView(HomeView.compare);
      await settle(t);
      expect(t.takeException(), isNull);
      state.clearCompare();
      expect(state.compareKeys, isEmpty);
    });
  });

  group('runs', () {
    testWidgets('a framework the other run lacks is parked, then restored', (
      t,
    ) async {
      final state = await pumpApp(t, twoRunBundle());
      state.selectFramework('foam3');
      state.toggleCompare('foam3');
      await t.runAsync(() => state.selectRun(state.index[1]));
      await settle(t);
      expect(state.selectedKey, isNull);
      expect(state.missingKey, 'foam3');
      expect(state.compareKeys, isNot(contains('foam3')));
      expect(state.parkedCompare, contains('foam3'));
      await t.runAsync(() => state.selectRun(state.index[0]));
      await settle(t);
      expect(state.selectedKey, 'foam3');
      expect(state.compareKeys, contains('foam3'));
    });
  });
}
