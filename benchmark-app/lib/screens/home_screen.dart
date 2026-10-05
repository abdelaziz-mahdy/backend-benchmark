import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/app_header.dart';
import '../widgets/common.dart';
import '../widgets/compare_tray.dart';
import '../widgets/loading_widget.dart';
import 'compare_screen.dart';
import 'framework_screen.dart';
import 'history_screen.dart';
import 'leaderboard_screen.dart';
import 'method_screen.dart';

/// Shell: header, the open page, and the compare tray.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    if (state.run == null) {
      return Scaffold(
        body: state.error != null
            ? Center(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load benchmark data',
                  message: '${state.error}',
                ),
              )
            : const LoadingWidget(),
      );
    }
    // Every number, name and fact can be selected and copied. Selection
    // starts on drag or long-press, so taps still reach rows and buttons.
    return Scaffold(
      body: SelectionArea(
        child: Column(
          children: [
            const AppHeader(),
            if (state.loading)
              const LinearProgressIndicator(minHeight: 2, color: kBlue),
            Expanded(
              child: switch (state.page) {
                DashboardPage.home => const LeaderboardScreen(),
                DashboardPage.details => const FrameworkScreen(),
                DashboardPage.compare => const CompareScreen(),
                DashboardPage.history => const HistoryScreen(),
                DashboardPage.method => const MethodScreen(),
              },
            ),
            const CompareTray(),
          ],
        ),
      ),
    );
  }
}
