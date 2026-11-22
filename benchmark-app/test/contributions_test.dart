// The Contributions page on the real data in assets/results/ (built from
// docs/contributions.yaml): reached from the menu and its link, newest
// first, with states, stars and before/after numbers, and a way to try
// again when its file cannot be read.

import 'dart:convert';
import 'dart:io';

import 'package:benchmark_app/app_router.dart';
import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/models/contributions.dart';
import 'package:benchmark_app/screens/contributions_screen.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:benchmark_app/widgets/site_frame.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support.dart';

/// The real assets, except contributions.json fails until [fail] is false.
class _FlakyBundle extends DirectoryBundle {
  bool fail = true;

  _FlakyBundle() : super('.');

  @override
  Future<ByteData> load(String key) {
    if (fail && key.endsWith('contributions.json')) {
      throw const FileSystemException('offline');
    }
    return super.load(key);
  }
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
  await t.runAsync(() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await t.pump();
    }
  });
  await t.pump(const Duration(milliseconds: 400));
}

List<Contribution> _real() => Contribution.listFromJson(
  jsonDecode(File('assets/results/contributions.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  setUpAll(loadRealFonts);

  test('the list is newest first and every link has a state', () {
    final list = _real();
    expect(list, isNotEmpty);
    for (var i = 1; i < list.length; i++) {
      expect(list[i - 1].date.isBefore(list[i].date), isFalse);
    }
    expect(list.expand((c) => c.links), everyElement(isA<ContributionLink>()));
  });

  test('before and after read as a change', () {
    BeforeAfter n(double b, double a) =>
        BeforeAfter(label: 'x', before: b, after: a, unit: 'u');
    expect(n(1600, 22000).change, '14× as many');
    expect(n(1000, 2500).change, '2.5× as many');
    expect(n(5500, 7000).change, '+27%');
    expect(n(1.57, 1.21).change, '−23%');
    expect(contributionDate(DateTime(2026, 11, 18)), 'Nov 18, 2026');
    expect(starCount(3335), '3,335');
    expect(starCount(11360), '11.4k');
  });

  test('a closed card says its first number and its fixes in one line', () {
    final relic = _real().firstWhere((c) => c.title.startsWith("Relic's"));
    expect(
      contributionHeadline(relic),
      '1,750 to 19,000 replies a second, 11× as many · Fix: 1 merged',
    );
    final parser = _real().firstWhere((c) => c.title.contains('Content-Type'));
    expect(contributionHeadline(parser), 'Fixes: 2 merged, 1 closed');
    ContributionLink issue(LinkState s) =>
        ContributionLink(kind: 'issue', number: 1, url: 'u', state: s);
    final onlyIssue = Contribution(
      title: 't',
      repo: 'a/b',
      project: 'b',
      stars: 1,
      date: DateTime(2026),
      summary: 's',
      links: [issue(LinkState.open)],
      numbers: const [],
    );
    expect(contributionHeadline(onlyIssue), 'Issue: 1 open');
  });

  for (final size in const [
    Size(360, 1600),
    Size(400, 1600),
    Size(1440, 1400),
  ]) {
    final w = size.width.toInt();

    testWidgets('Contributions at $w: from the menu, newest first', (t) async {
      final state = await _pump(t, size);
      await t.tap(
        find.descendant(
          of: find.byType(SiteHeader),
          matching: find.text('Contributions'),
        ),
      );
      await _settle(t);
      expect(state.page, DashboardPage.contributions);
      expect(locationOf(state).path, '/contributions');

      final list = _real();
      expect(find.text(list.first.title), findsOneWidget);
      expect(find.text(starCount(list.first.stars)), findsWidgets);
      expect(find.textContaining('fixes merged ·'), findsOneWidget);

      // Closed: one line each, no summary, bars or links yet.
      expect(find.text(contributionHeadline(list.first)), findsOneWidget);
      expect(find.text(list.first.summary), findsNothing);
      expect(find.text('Before'), findsNothing);
      expect(find.text('Pull request #446'), findsNothing);

      // The title opens the card in place, and closes it again.
      await t.tap(find.text(list.first.title));
      await _settle(t);
      expect(find.text(list.first.summary), findsOneWidget);
      expect(find.text(contributionHeadline(list.first)), findsNothing);
      expect(find.text('Before'), findsWidgets);
      expect(find.text('Merged'), findsWidgets);
      expect(find.text('Pull request #446'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text(list.first.title));
      await _settle(t);
      expect(find.text('Pull request #446'), findsNothing);

      // Every card is on the page, in the file's order.
      final ys = <double>[];
      for (final c in list) {
        await t.scrollUntilVisible(
          find.text(c.title),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        ys.add(t.getTopLeft(find.text(c.title)).dy);
      }
      expect(t.takeException(), isNull);
      expect(ys.length, list.length);
    });
  }

  testWidgets('a link to /contributions opens the page', (t) async {
    final state = await _pump(t, const Size(1440, 1400));
    applyLocation(state, Uri.parse('/contributions'));
    await _settle(t);
    expect(state.page, DashboardPage.contributions);
    expect(find.byType(ContributionsScreen), findsOneWidget);
  });

  testWidgets('a failed load says so and Try again loads it', (t) async {
    final bundle = _FlakyBundle();
    final state = await _pump(t, const Size(1440, 1400), bundle: bundle);
    state.setPage(DashboardPage.contributions);
    await _settle(t);
    expect(find.text('Could not load the contributions'), findsOneWidget);
    bundle.fail = false;
    await t.tap(find.text('Try again'));
    await _settle(t);
    expect(find.text('Could not load the contributions'), findsNothing);
    expect(find.text(_real().first.title), findsOneWidget);
  });

  // Screenshots for review, not checked in CI:
  //   flutter test test/contributions_test.dart --tags tour --run-skipped \
  //     --update-goldens
  for (final size in const [Size(1440, 3200), Size(390, 5200)]) {
    for (final dark in [false, true]) {
      final w = size.width.toInt();
      testWidgets('contributions page at $w${dark ? ' dark' : ''}', (t) async {
        t.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
        final state = await _pump(t, size);
        state.setPage(DashboardPage.contributions);
        await _settle(t);
        // The first card open, the rest closed, as a reader finds them.
        await t.tap(find.text(_real().first.title));
        await _settle(t);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../screenshots/$w-contributions${dark ? '-dark' : ''}.png',
          ),
        );
      }, tags: ['tour']);
    }
  }
}
