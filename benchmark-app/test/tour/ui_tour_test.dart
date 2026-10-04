// Screenshot tour of every page at three widths. Not part of the normal test
// run (tagged "tour"); generate with:
//   flutter test test/tour --tags tour --update-goldens
// Uses the data in assets/results/ (run bench/report/report.py first).
@Tags(['tour'])
library;

import 'package:benchmark_app/main.dart';
import 'package:benchmark_app/services/results_service.dart';
import 'package:benchmark_app/state/dashboard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support.dart';

void main() {
  setUpAll(loadRealFonts);

  for (final size in const [
    Size(1440, 1700),
    Size(1024, 1500),
    Size(400, 2200),
  ]) {
    final w = size.width.toInt();
    testWidgets('tour at $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
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
        // Two frames: the first schedules implicit animations (hint fade,
        // chip colours), the second lets them finish.
        await t.pump(const Duration(milliseconds: 600));
        await t.pump(const Duration(milliseconds: 600));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../screenshots/$w-$name.png'),
        );
      }

      String keyOf(String name) =>
          state.run!.backends.firstWhere((b) => b.name == name).key;
      final foam = keyOf('foam3 (postgres)');
      final fast = keyOf('rust actix-web');
      final slow = keyOf('django (sync)');

      // T1: the home table, nothing expanded.
      await shot('1-home');

      // T2: a slow framework's row expanded (foam3).
      state.toggleExpanded(foam);
      await shot('2-home-foam3-expanded');

      // T2 again with a fast one, and the search narrowing the list.
      state.toggleExpanded(fast);
      state.setQuery('rust');
      await shot('3-home-search-rust-expanded');
      state.setQuery('');
      state.toggleExpanded(fast);

      // T3: tray with two picked, then a 3-way comparison including foam3.
      state.toggleCompare(foam);
      state.toggleCompare(slow);
      await shot('4-home-tray');
      state.toggleCompare(fast);
      state.openCompare();
      await shot('5-compare-3way');

      // Details of the fast one, DB mixed.
      state.setScenario('db_mixed');
      state.openDetails(fast);
      await shot('6-details-actix-db-mixed');

      state.setPage(DashboardPage.history);
      await shot('7-history');
      state.setPage(DashboardPage.method);
      await shot('8-method');

      final legacy = state.index.firstWhere((e) => e.isLegacy);
      await t.runAsync(() => state.selectRun(legacy));
      state.goHome();
      await shot('9-legacy-home');
    });
  }
}
