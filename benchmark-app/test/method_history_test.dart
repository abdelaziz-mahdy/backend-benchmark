// The Method and History pages on the real data in assets/results/: every
// section opens without overflow, the words are plain, and switching the
// test, the number or the run never leaves stale state behind.

import 'dart:convert';

import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:benchmark_app/widgets/calm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support.dart';

/// Words the two pages must not use (the home page's plain vocabulary).
final _jargon = <Pattern>[
  'req/s',
  RegExp(r'\brps\b', caseSensitive: false),
  RegExp(r'\bp(50|90|99)\b'),
  // k6 and vegeta are allowed: runs name the tool that sent the load, since
  // method v3 switched from k6 to vegeta and mixing them unnamed misleads.
  RegExp('load generator', caseSensitive: false),
  RegExp('scenario', caseSensitive: false),
  RegExp('sustainable', caseSensitive: false),
  RegExp('log scale', caseSensitive: false),
  RegExp(r'\bprobe', caseSensitive: false),
  RegExp('monolith', caseSensitive: false),
  RegExp(r'\bORM\b'),
  // "Median reply time" is the user's chosen name (feedback round 2).
  // Commit hashes.
  RegExp(r'\b[0-9a-f]{7}\b'),
  // Compact numbers such as "30.0K".
  RegExp(r'\d(\.\d)?K\b'),
];

Map<String, dynamic> _entry(String id, String machine, String date) => {
  'id': id,
  'kind': 'run',
  'date': date,
  'machine': {
    'slug': machine,
    'cpu': 'CPU $machine',
    'cores': 10,
    'ram_gb': 32,
  },
  'methodology': 'v2',
  'backends': ['go-mux', if (machine == 'mA') 'java-foam3'],
  'scenarios': ['db_mixed', 'no_db'],
  'names': {'go-mux': 'go mux', 'java-foam3': 'foam3'},
  'headline': {
    'go-mux': {
      'db_mixed': {'sustainable_rps': 1000.0 + date.hashCode % 7},
      'no_db': {'sustainable_rps': 9000.0 + date.hashCode % 5},
    },
    if (machine == 'mA')
      'java-foam3': {
        'db_mixed': {'sustainable_rps': 500.0 + date.hashCode % 3},
        'no_db': {'sustainable_rps': 800.0 + date.hashCode % 3},
      },
  },
  'file': 'runs/$id.json',
};

MapBundle _twoGroups() {
  Map<String, dynamic> backend(String key, String lang) => {
    'key': key,
    'name': key,
    'language': lang,
    'status': 'ok',
    'scenarios': {
      for (final s in ['db_mixed', 'no_db'])
        s: {
          'reps': 3,
          'sustainable_rps': {'median': 1000, 'min': 1000, 'max': 1000},
          'steps': [],
          'timeseries': {},
        },
    },
  };
  return MapBundle({
    'assets/results/index.json': jsonEncode({
      'runs': [
        _entry('a2', 'mA', '2026-10-05'),
        _entry('a1', 'mA', '2026-10-04'),
        _entry('b2', 'mB', '2026-10-05'),
        _entry('b1', 'mB', '2026-10-04'),
      ],
    }),
    'assets/results/runs/a2.json': jsonEncode({
      'id': 'a2',
      'kind': 'run',
      'date': '2026-10-05',
      'machine': {'slug': 'mA', 'cpu': 'CPU mA', 'cores': 10, 'ram_gb': 32},
      'methodology': 'v2',
      'params': {'reps': 3},
      'backends': [backend('go-mux', 'go'), backend('java-foam3', 'java')],
    }),
  });
}

Future<DashboardState> _pump(
  WidgetTester t,
  Size size, {
  AssetBundle? bundle,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.runAsync(() async {
    await t.pumpWidget(
      BenchmarkApp(service: ResultsService(bundle ?? DirectoryBundle('.'))),
    );
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await t.pump();
    }
  });
  return Provider.of<DashboardState>(
    t.element(find.byType(Scaffold).first),
    listen: false,
  );
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

/// Every closed section (and the phone's contents list), opened.
Future<void> _openAll(WidgetTester t) async {
  final closed = find.byWidgetPredicate(
    (w) => w is Pressable && w.expanded == false,
  );
  for (var guard = 0; guard < 20 && closed.evaluate().isNotEmpty; guard++) {
    await t.ensureVisible(closed.first);
    await t.pump();
    await t.tap(closed.first, warnIfMissed: false);
    await _settle(t);
  }
  expect(closed, findsNothing);
}

/// Every piece of text on screen, joined.
String _allText(WidgetTester t) => [
  for (final e in find.byType(RichText).evaluate())
    (e.widget as RichText).text.toPlainText(),
].join('\n');

void _expectPlain(WidgetTester t, String where) {
  final text = _allText(t);
  // The scan sees the page's real text.
  expect(text.toLowerCase(), contains('replies a second'));
  for (final p in _jargon) {
    final m = p.allMatches(text).firstOrNull;
    if (m == null) continue;
    final from = (m.start - 40).clamp(0, text.length);
    final to = (m.end + 40).clamp(0, text.length);
    fail('$where uses "${m[0]}": …${text.substring(from, to)}…');
  }
}

Future<void> _selectRun(WidgetTester t, DashboardState state, bool legacy) =>
    t.runAsync(() async {
      await state.selectRun(
        state.index.firstWhere((e) => e.isLegacy == legacy),
      );
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await t.pump();
      }
    });

void main() {
  setUpAll(loadRealFonts);

  for (final size in const [Size(400, 1600), Size(1440, 1400)]) {
    final w = size.width.toInt();

    testWidgets('Method at $w: every section opens, in plain words', (t) async {
      final state = await _pump(t, size);
      state.setPage(DashboardPage.method);
      await _settle(t);
      await _openAll(t);
      _expectPlain(t, 'Method');
      expect(find.text('Pick which run the site shows:'), findsOneWidget);
      expect(find.text('How to read it'), findsOneWidget);

      // The old run has other sections; switching keeps the page working
      // and the open sections open.
      await _selectRun(t, state, true);
      await _settle(t);
      expect(find.text('1. Overview'), findsWidgets);
      await _openAll(t);
      expect(t.takeException(), isNull);
      await _selectRun(t, state, false);
      await _settle(t);
      expect(find.text('1. How the traffic is sent'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('History at $w: every test and number, in plain words', (
      t,
    ) async {
      final state = await _pump(t, size);
      state.setPage(DashboardPage.history);
      await _settle(t);
      for (final test in state.run!.scenarios) {
        state.setScenario(test);
        await _settle(t);
        for (final name in const [
          'Replies a second, 99% within 100 ms',
          'Most at any speed',
          'Reply time 99 in 100 beat',
          'Processor use',
          'Memory use',
        ]) {
          final option = find.text(name).first;
          await t.ensureVisible(option);
          await t.tap(option);
          await _settle(t);
          _expectPlain(t, 'History ($test, $name)');
        }
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('History: a highlighted framework dims only its own groups', (
    t,
  ) async {
    // Two computers, two runs each; foam3 only ran on the first.
    final state = await _pump(t, const Size(1440, 1400), bundle: _twoGroups());
    state.setPage(DashboardPage.history);
    await _settle(t);
    Finder dimmedIn(String group) => find.descendant(
      of: find.byKey(ValueKey('history-$group|v2')),
      matching: find.byWidgetPredicate(
        (w) => w is AnimatedOpacity && w.opacity < 1,
      ),
    );
    final chip = find.byKey(const ValueKey('legend-mA|v2-java-foam3'));
    await t.ensureVisible(chip);
    await t.tap(chip);
    await _settle(t);
    expect(dimmedIn('mA'), findsWidgets);
    // The other computer has no foam3: nothing there is dimmed.
    expect(find.byKey(const ValueKey('legend-mB|v2-go-mux')), findsOneWidget);
    expect(dimmedIn('mB'), findsNothing);
    // A test switch keeps the highlight where foam3 exists.
    state.setScenario('no_db');
    await _settle(t);
    expect(dimmedIn('mA'), findsWidgets);
    expect(dimmedIn('mB'), findsNothing);
    expect(t.takeException(), isNull);
  });

  // Screenshots of the pages with everything open, for review. Skipped in a
  // normal run (tag "tour"); generate with:
  //   flutter test test/method_history_test.dart --tags tour --run-skipped \
  //     --update-goldens
  for (final size in const [Size(1440, 6000), Size(400, 9000)]) {
    for (final dark in [false, true]) {
      final w = size.width.toInt();
      testWidgets('method and history open at $w${dark ? ' dark' : ''}', (
        t,
      ) async {
        t.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
        final state = await _pump(t, size);
        final suffix = dark ? '-dark' : '';
        state.setPage(DashboardPage.method);
        await _settle(t);
        await _openAll(t);
        await t.drag(find.byType(Scrollable).first, const Offset(0, 20000));
        await t.drag(find.byType(Scrollable).first, const Offset(0, -20000));
        await _settle(t);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../screenshots/$w-m-method-open$suffix.png'),
        );
        state.setPage(DashboardPage.history);
        await _settle(t);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../screenshots/$w-m-history$suffix.png'),
        );
      }, tags: ['tour']);
    }
  }
}
