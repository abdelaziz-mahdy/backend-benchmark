import 'dart:convert';

import 'package:benchmark_app/app_router.dart';
import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/models/plain.dart';
import 'package:benchmark_app/models/results.dart';
import 'package:benchmark_app/screens/views/short_answer.dart';
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

    test('about the same only when each middle is in the other range', () {
      final all = [
        res('a', 5000, low: 4000, high: 6000),
        res('b', 4800, low: 4600, high: 5100),
        res('c', 3000, low: 2900, high: 3100),
      ];
      expect(closeTo(all, all[0]).map((r) => r.key), ['b']);
      expect(closeTo(all, all[2]), isEmpty);
      expect(closeSentence(all, all[0]), contains('b'));
      // One wide range is not enough: serverpod (1,900 to 5,750) is not
      // "about the same" as fastapi at 2,900 with tight tries.
      final wide = res('serverpod', 4250, low: 1900, high: 5750);
      final tight = res('fastapi', 2900, low: 2800, high: 3000);
      expect(wide.overlaps(tight), isFalse);
      expect(answerFor([wide, tight]), startsWith('Serverpod is the fastest'));
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
      expect(band.cappedNote, contains("our testing tool's limit"));
      expect(band.cappedNote, contains("can't tell which is fastest"));
    });

    test('the answer names the leader in words, without numbers', () {
      final answer = answerFor([res('zeta', 9000), res('alpha', 3000)]);
      expect(
        answer,
        'Zeta is the fastest. Next is alpha, about a third as fast.',
      );
      expect(answer, isNot(contains('9,000')));
      expect(answerFor([]), contains('No framework'));
    });

    test('how it is built drops setting names a reader cannot use', () {
      final b = BackendResult.fromJson({
        'key': 'x',
        'name': 'x',
        'language': 'go',
        'status': 'ok',
        'implementation': {
          'server': 'Express 5 on Bun (NODE_ENV=production)',
          'concurrency': 'uvicorn, one worker per core (2)',
          'pool':
              'one persistent connection per thread (CONN_MAX_AGE 60); '
              'PgBouncer transaction mode, 50 server connections',
        },
        'scenarios': {'db_mixed': scenarioJson(sustainable: 1)},
      });
      final facts = {for (final (k, v) in b.builtFacts) k: v};
      expect(facts['Web server'], 'Express 5 on Bun');
      expect(facts['How it handles many requests'], contains('(2)'));
      expect(
        facts['Database connections'],
        'one persistent connection per thread; PgBouncer transaction mode, '
        '50 server connections',
      );
    });

    test('Compare names the size and kind of a tie at the top', () {
      final verdict = compareVerdict({
        'db_mixed': [res('a', 900), res('b', 300), res('c', 100)],
        'no_db': [
          res('a', 48000, capped: true),
          res('b', 48000, capped: true),
          res('c', 47000, capped: true),
        ],
      });
      expect(
        verdict,
        contains("In one test, the top three tie at our testing tool's limit."),
      );
      expect(
        placeSentence([res('a', 9), res('b', 5), res('c', 1)], res('b', 5)),
        'One of the other 2 was faster.',
      );
    });

    test('a leader at the tool limit carries the caveat; ties are counted', () {
      expect(
        answerFor([res('a', 40000, capped: true), res('b', 30000)]),
        'A is the fastest. Next is b, about three-quarters as fast. '
        "A hit our testing tool's limit, so it may be faster.",
      );
      expect(
        placeSentence([
          res('a', 9),
          res('b', 5),
          res('c', 5),
          res('d', 1),
        ], res('b', 5)),
        'One of the other 3 was faster, and one was about the same.',
      );
    });

    test('one tie rule for the answer, a bar box and Compare', () {
      final rust = res('rust', 32000, low: 24000, high: 32000, capped: true);
      final bun = res('bun', 24000, low: 24000, high: 32000);
      final node = res('node', 24000, low: 16000, high: 24000);
      final all = [rust, bun, node];
      // The answer tells rust apart, so bun's box does not call them the
      // same; bun and node, on the same side, still are.
      expect(closeTo(all, bun).map((r) => r.key), ['node']);
      // Compare with only rust and bun picked follows the whole test.
      expect(
        compareTestSentence([rust, bun], all: all),
        startsWith('Rust is the fastest.'),
      );
    });

    test('a close call is never counted as faster', () {
      final all = [
        res('top', 40000),
        res('foam', 16000, low: 7750, high: 16000),
        res('spring', 15500, low: 15500, high: 22000),
      ];
      expect(
        placeSentence(all, all[2]),
        'One of the other 2 was faster, and one was about the same.',
      );
    });

    test('about-the-same followers share one speed word', () {
      expect(
        answerFor([
          res('rust', 29000),
          res('spring', 18000, low: 15500, high: 18000),
          res('asp', 17000, low: 17000, high: 19000),
        ]),
        'Rust is the fastest. Next are spring and asp, about two-thirds as fast.',
      );
    });

    test('the same speed word is said once; two tests are "both"', () {
      expect(
        compareTestSentence([
          res('a', 46000),
          res('b', 25000),
          res('c', 21000),
        ]),
        'A is the fastest. Next are b and c, about half as fast.',
      );
      expect(
        compareVerdict({
          'db_test': [res('a', 900), res('b', 300)],
          'no_db_test': [res('a', 900), res('b', 300)],
        }),
        startsWith('A was fastest in both tests.'),
      );
    });

    test("a bar's box never names one the sentence grouped elsewhere", () {
      final all = [
        res('bun', 24000),
        res('asp', 16000, low: 12000, high: 16000),
        res('go', 16000, low: 16000, high: 16000),
        res('node', 12000, low: 12000, high: 16000),
      ];
      // The sentence puts asp and go together and node after them, so
      // asp's box does not call node about the same.
      expect(closeTo(all, all[1]).map((r) => r.key), ['go']);
      expect(closeTo(all, all[3]), isEmpty);
      // Compare with a few picks keeps the same groups.
      expect(
        compareTestSentence([all[0], all[1], all[3]], all: all),
        contains('Then node'),
      );
    });

    test('a chain of close calls never stretches one speed word', () {
      final blocks = followerBlocks([
        res('bun', 24000),
        res('go', 16000, low: 16000, high: 16000),
        res('asp', 16000, low: 12000, high: 16000),
        res('node', 12000, low: 12000, high: 16000),
      ]);
      // node is about the same as asp but not go, so it starts its own.
      expect(blocks.map((b) => b.map((r) => r.key).toList()), [
        ['asp', 'go'],
        ['node'],
      ]);
    });

    test('every capped framework in a tie gets the limit caveat', () {
      final answer = answerFor([
        res('bun', 24000, low: 24000, high: 32000),
        res('rust', 32000, low: 24000, high: 32000, capped: true),
        res('go', 8000),
      ]);
      expect(answer, contains("Rust hit our testing tool's limit"));
    });

    test('frameworks with the same number are named together', () {
      expect(
        answerFor([res('a', 40000), res('b', 30000), res('c', 30000)]),
        'A is the fastest. Next are b and c, about three-quarters as fast.',
      );
    });

    test('equal numbers join the top together or not at all', () {
      // express (bun) overlaps the leader, express (node) has the same
      // number but does not: neither is called "about the same".
      final top = topGroup([
        res('rust', 32000, low: 24000, high: 32000, capped: true),
        res('bun', 24000, low: 24000, high: 32000),
        res('node', 24000, low: 16000, high: 24000),
      ]);
      expect(top.map((r) => r.key), ['rust']);
    });

    test('everyone at the tool limit ties, and a fifth is a fifth', () {
      final answer = answerFor([
        res('a', 48000, capped: true),
        res('b', 48000, capped: true),
        res('c', 46000, capped: true),
        res('d', 20000),
      ]);
      expect(answer, startsWith("A, b and c tie for fastest at our testing"));
      expect(answer, contains('Next is d,'));
      expect(asFast(0.19), 'about a fifth as fast');
      expect(asFast(0.25), 'about a quarter as fast');
    });

    test('runs that overlap at the top are about the same, as in Compare', () {
      final answer = answerFor([
        res('zeta', 9000, low: 8000, high: 9500),
        res('alpha', 8800, low: 8600, high: 9100),
        res('beta', 3000),
      ]);
      expect(
        answer,
        'Zeta and alpha are about the same, the fastest. '
        'Next is beta, about a third as fast.',
      );
      final compare = compareTestSentence([res('a', 900), res('b', 450)]);
      expect(compare, 'A is the fastest. Next is b, about half as fast.');
      expect(compare, isNot(contains('900')));
    });
  });

  group('home page', () {
    testWidgets('opens on who is fastest, as bars without numbers', (t) async {
      final state = await pumpApp(t, realisticBundle());
      expect(state.view, HomeView.short);
      expect(
        find.text('How much traffic can each backend framework handle?'),
        findsOneWidget,
      );
      // One bar per framework in the main test, and no numbers until a bar
      // is tapped.
      expect(find.byKey(const ValueKey('bar-db_mixed-rust-actix')), findsOne);
      expect(find.byKey(const ValueKey('bar-db_mixed-db-only')), findsOne);
      expect(find.textContaining('32,000'), findsNothing);
      expect(find.textContaining('about half as fast'), findsWidgets);
      // No internal test names anywhere on the page.
      expect(find.textContaining('db_mixed'), findsNothing);
      expect(find.textContaining('DB mixed'), findsNothing);
    });

    testWidgets('a bar opens its number in place', (t) async {
      await pumpApp(t, realisticBundle());
      await t.tap(find.byKey(const ValueKey('bar-db_mixed-go-mux')));
      await settle(t);
      expect(find.text('More about go-mux'), findsOneWidget);
      expect(find.textContaining('16,000'), findsWidgets);
      // It opens right under the tapped bar, before the bars below it.
      final tapped = t.getRect(
        find.byKey(const ValueKey('bar-db_mixed-go-mux')),
      );
      final reveal = t.getRect(find.byType(Reveal));
      expect(reveal.top, greaterThanOrEqualTo(tapped.bottom));
      expect(reveal.top - tapped.bottom, lessThan(20));
      final below = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('bar-db_mixed-'),
      );
      var after = 0;
      for (final e in below.evaluate()) {
        final r = t.getRect(find.byWidget(e.widget));
        if (r.top > tapped.top) {
          after++;
          expect(r.top, greaterThanOrEqualTo(reveal.bottom));
        }
      }
      expect(after, greaterThan(0), reason: 'go-mux should not be last');
    });

    testWidgets('the box under a bar opens One framework', (t) async {
      final state = await pumpApp(t, realisticBundle());
      await t.tap(find.text('go-mux').first);
      await settle(t);
      await t.ensureVisible(find.text('More about go-mux'));
      await t.tap(find.text('More about go-mux'));
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

    testWidgets('lower-is-better measures sort best first', (t) async {
      final state = await pumpApp(t, realisticBundle());
      state.sortBy('db_read');
      state.setMeasure(Measure.typical);
      expect(state.sortDesc, isFalse);
      // A new column keeps best first too.
      state.sortBy('db_write');
      expect(state.sortDesc, isFalse);
      state.setMeasure(Measure.load);
      expect(state.sortDesc, isTrue);
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

    testWidgets('a test the loaded run lacks is never set', (t) async {
      final state = await pumpApp(t, realisticBundle());
      final before = state.scenario;
      state.setScenario('no_such_test');
      expect(state.scenario, before);
      // History keeps its own test, in its own URL.
      state.setPage(DashboardPage.history);
      state.setHistoryTest('db_write');
      expect(locationOf(state).queryParameters['s'], 'db_write');
      expect(state.scenario, before);
    });

    testWidgets('a freed Compare place brings back a set-aside pick', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      final keys = [for (final b in state.run!.backends) b.key];
      for (final k in keys.take(4)) {
        state.toggleCompare(k);
      }
      state.parkedCompare.add(keys[4]);
      // Elsewhere a remove only removes.
      state.toggleCompare(keys[0]);
      expect(state.compareKeys, isNot(contains(keys[4])));
      // Compare's own remove brings the set-aside pick back.
      state.toggleCompare(keys[0]);
      state.toggleCompare(keys[0], restore: true);
      expect(state.compareKeys, contains(keys[4]));
      expect(state.parkedCompare, isEmpty);
      // With room free, one tap brings set-aside picks back.
      state.toggleCompare(keys[1]);
      state.parkedCompare.add(keys[1]);
      state.restoreParked();
      expect(state.compareKeys, contains(keys[1]));
      expect(state.parkedCompare, isEmpty);
      // Clear all, then Undo, puts back picks and set-aside picks.
      final picks = [...state.compareKeys];
      state.parkedCompare.add('gone-framework');
      state.clearCompare();
      state.restoreCompare(picks, ['gone-framework'], {'gone-framework'});
      expect(state.awayForRun, {'gone-framework'});
      expect(state.compareKeys, picks);
      expect(state.parkedCompare, ['gone-framework']);
    });

    testWidgets('Back keeps set-aside picks and a missing framework', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      final keys = [for (final b in state.run!.backends) b.key];
      state.parkedCompare.add('gone-framework');
      state.missingKey = 'gone-framework';
      state.applyRoute(
        page: DashboardPage.home,
        view: HomeView.compare,
        compare: keys.take(2).toList(),
      );
      expect(state.parkedCompare, ['gone-framework']);
      state.applyRoute(page: DashboardPage.home, view: HomeView.one);
      expect(state.missingKey, 'gone-framework');
    });

    testWidgets('Back never gets stuck on a rewritten link or Compare', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      final router = DashRouterDelegate(state);
      final key = state.run!.backends.first.key;
      // An old-style link is reported as it was opened, so it adds no
      // new history entry for Back to land on.
      final old = Uri.parse('/f/$key');
      await router.setNewRoutePath(RouteInformation(uri: old));
      expect(router.currentConfiguration?.uri, old);
      // A change the visitor makes is reported as itself.
      state.setView(HomeView.all);
      expect(router.currentConfiguration?.uri, Uri(path: '/all'));
      // Back to plain /compare means no picks, so it can leave Compare.
      state.toggleCompare(key);
      await router.setNewRoutePath(
        RouteInformation(uri: Uri.parse('/compare')),
      );
      expect(state.compareKeys, isEmpty);
      router.dispose();
    });

    testWidgets('Back and Forward bring back what an entry held', (t) async {
      final state = await pumpApp(t, realisticBundle());
      final router = DashRouterDelegate(state);
      final keys = [for (final b in state.run!.backends) b.key];
      // A Compare entry saved with a set-aside pick.
      state.setView(HomeView.compare);
      for (final k in keys.take(2)) {
        state.toggleCompare(k);
      }
      state.parkedCompare.add('gone-framework');
      final saved = router.currentConfiguration!;
      expect(saved.state, isA<Map<String, Object?>>());
      // The visitor moves on; the set-aside pick is lost here...
      state.clearCompare();
      expect(state.parkedCompare, isEmpty);
      // ...and Back to the saved entry restores it.
      await router.setNewRoutePath(saved);
      expect(state.parkedCompare, ['gone-framework']);
      expect(state.compareKeys, keys.take(2).toList());
      router.dispose();
    });

    testWidgets('Back restores the test but never undoes a pick on one run', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      final router = DashRouterDelegate(state);
      final keys = [for (final b in state.run!.backends) b.key];
      for (final k in keys.take(3)) {
        state.toggleCompare(k);
      }
      state.setView(HomeView.all);
      final saved = router.currentConfiguration!;
      // Elsewhere the picks change and a test is chosen...
      state.toggleCompare(keys.first);
      final test = state.scenario;
      state.setScenario(state.run!.scenarios.last);
      // ...and Back to the /all entry brings back its test, but on the same
      // run never undoes a Compare change made since.
      final now = [...state.compareKeys];
      await router.setNewRoutePath(saved);
      expect(state.compareKeys, now);
      expect(state.scenario, test);
      router.dispose();
    });

    testWidgets('Back across a run change brings back its picks', (t) async {
      final state = await pumpApp(t, twoRunBundle());
      final router = DashRouterDelegate(state);
      final keys = [for (final b in state.run!.backends) b.key];
      for (final k in keys.take(2)) {
        state.toggleCompare(k);
      }
      state.setView(HomeView.all);
      final saved = router.currentConfiguration!;
      await t.runAsync(() => state.selectRun(state.index[1]));
      await settle(t);
      state.compareKeys.clear();
      await t.runAsync(() async {
        await router.setNewRoutePath(saved);
        await Future<void>.delayed(Duration.zero);
      });
      await settle(t);
      expect(state.entry, state.index.first);
      expect(state.compareKeys, keys.take(2).toList());
      router.dispose();
    });

    testWidgets('a change the link does not show still updates the entry', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      final router = DashRouterDelegate(state);
      var reports = 0;
      router.addListener(() => reports++);
      state.setView(HomeView.compare);
      state.restoreCompare([], ['gone-framework']);
      final before = reports;
      state.clearCompare();
      // Same link (/compare), but the entry must be updated.
      expect(reports, greaterThan(before));
      expect((router.currentConfiguration!.state! as Map)['parked'], isEmpty);
      router.dispose();
    });

    testWidgets('an opened old link never comes back after moving on', (
      t,
    ) async {
      final state = await pumpApp(t, realisticBundle());
      final router = DashRouterDelegate(state);
      final key = state.run!.backends.first.key;
      await router.setNewRoutePath(RouteInformation(uri: Uri.parse('/f/$key')));
      final tidy = locationOf(state);
      final other = state.run!.scenarios.last;
      state.setScenario(other);
      state.setScenario(tidy.queryParameters['s']!);
      // Back at the same view, it shows its own tidy link, not the old one.
      expect(router.currentConfiguration?.uri, tidy);
      router.dispose();
    });

    testWidgets('a run change never swaps a pick for one set aside for room', (
      t,
    ) async {
      final state = await pumpApp(t, twoRunBundle());
      final keys = [for (final b in state.run!.backends) b.key];
      // foam3 is missing from the other run; the rest fit.
      state.toggleCompare('foam3');
      state.parkedCompare.add(keys.firstWhere((k) => k != 'foam3'));
      await t.runAsync(() => state.selectRun(state.index[1]));
      await settle(t);
      // The pick set aside for room did not fill foam3's place.
      expect(state.compareKeys, isEmpty);
      await t.runAsync(() => state.selectRun(state.index[0]));
      await settle(t);
      expect(state.compareKeys, ['foam3']);
    });

    testWidgets('a copied link keeps an older run', (t) async {
      final state = await pumpApp(t, twoRunBundle());
      expect(locationOf(state).queryParameters, isNot(contains('run')));
      await t.runAsync(() => state.selectRun(state.index[1]));
      await settle(t);
      expect(locationOf(state).queryParameters['run'], state.index[1].id);
    });

    testWidgets('opening a link with a run loads that run first', (t) async {
      final state = await pumpApp(t, twoRunBundle());
      final router = DashRouterDelegate(state);
      final old = state.index[1].id;
      await t.runAsync(
        () => router.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/all?run=$old')),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(t);
      expect(state.entry?.id, old);
      expect(state.view, HomeView.all);
      router.dispose();
    });
  });
}
