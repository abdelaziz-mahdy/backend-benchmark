import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/app_header.dart';
import '../widgets/common.dart';
import '../widgets/loading_widget.dart';
import 'compare_screen.dart';
import 'framework_screen.dart';
import 'history_screen.dart';
import 'method_screen.dart';
import 'overview_screen.dart';

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
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          if (state.loading)
            const LinearProgressIndicator(minHeight: 2, color: kBlue),
          Expanded(
            child: IndexedStack(
              index: state.tab.index,
              children: const [
                OverviewScreen(),
                FrameworkScreen(),
                CompareScreen(),
                HistoryScreen(),
                MethodScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
