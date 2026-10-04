// Screenshot tour of every tab at three widths. Not part of the normal test
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
        await t.pump(const Duration(milliseconds: 600));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../screenshots/$w-$name.png'),
        );
      }

      await shot('1-overview');
      state.setTab(DashboardTab.framework);
      await shot('2-framework');
      final keys = state.rank(state.visibleBackends, state.headline).take(3);
      for (final b in keys) {
        state.toggleCompare(b.key);
      }
      state.setTab(DashboardTab.compare);
      await shot('3-compare');
      state.setTab(DashboardTab.history);
      await shot('4-history');
      state.setTab(DashboardTab.method);
      await shot('5-method');
      final legacy = state.index.firstWhere((e) => e.isLegacy);
      await t.runAsync(() => state.selectRun(legacy));
      state.setTab(DashboardTab.overview);
      await shot('6-legacy-overview');
      state.setTab(DashboardTab.framework);
      await shot('7-legacy-framework');
    });
  }
}
