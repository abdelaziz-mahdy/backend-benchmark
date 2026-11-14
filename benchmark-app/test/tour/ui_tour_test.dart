// Screenshot tour of every view at three widths. Not part of the normal test
// run (tagged "tour"); generate with:
//   flutter test test/tour --tags tour --run-skipped --update-goldens
// Uses the data in assets/results/ (run bench/report/report.py first).
@Tags(['tour'])
library;

import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../support.dart';

void main() {
  setUpAll(loadRealFonts);

  for (final size in const [
    Size(1440, 2300),
    Size(1024, 2500),
    Size(400, 3800),
  ]) {
    final w = size.width.toInt();
    for (final dark in [false, true]) {
      testWidgets('tour at $w${dark ? ' dark' : ''}', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
        final bundle = DirectoryBundle('.');
        await t.runAsync(() async {
          await t.pumpWidget(BenchmarkApp(service: ResultsService(bundle)));
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await t.pump();
          }
        });
        final state = Provider.of<DashboardState>(
          t.element(find.byType(Scaffold).first),
          listen: false,
        );
        Future<void> shot(String name) async {
          await t.pump(const Duration(milliseconds: 600));
          await t.pump(const Duration(milliseconds: 600));
          await t.pump(const Duration(milliseconds: 600));
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../../screenshots/$w-$name.png'),
          );
        }

        Future<void> scrollTo(Finder f) async {
          await t.ensureVisible(f);
          await t.pump(const Duration(milliseconds: 400));
        }

        if (dark) {
          await shot('1-short-answer-dark');
          return;
        }

        await shot('1-short-answer');

        // A chip opened: serverpod in the typical app.
        await t.tap(find.text('serverpod').first);
        await shot('2-chip-open');

        // One framework, serverpod.
        state.selectFramework('dart-server-pod');
        await t.pump();
        await shot('3-one-serverpod');

        // Its charts section open.
        await scrollTo(find.text('Charts from the test'));
        await t.tap(find.text('Charts from the test'));
        await t.pump();
        await scrollTo(find.text('Charts from the test'));
        await shot('4-one-serverpod-charts');

        // Every number.
        state.setView(HomeView.all);
        await t.pump();
        await t.drag(find.byType(Scrollable).first, const Offset(0, 6000));
        await t.pump();
        await shot('5-every-number');

        // Compare with three.
        for (final k in ['rust-actix-web', 'go-mux', 'dart-server-pod']) {
          if (!state.compareKeys.contains(k)) state.toggleCompare(k);
        }
        state.setView(HomeView.compare);
        await t.pump();
        await shot('6-compare-3');

        state.setPage(DashboardPage.history);
        await shot('7-history');
        state.setPage(DashboardPage.method);
        await shot('8-method');

        // The legacy run.
        final legacy = state.index.firstWhere((e) => e.isLegacy);
        await t.runAsync(() => state.selectRun(legacy));
        state.goHome();
        await t.pump();
        await t.drag(find.byType(Scrollable).first, const Offset(0, 6000));
        await t.pump();
        await shot('9-legacy-run');
      });
    }
  }
}
