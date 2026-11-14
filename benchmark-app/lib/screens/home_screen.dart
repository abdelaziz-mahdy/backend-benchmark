import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
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

/// Shell: header, the open page, and the compare dock. "/" focuses the
/// leaderboard search from anywhere on that page.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = FocusNode(debugLabel: 'search');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.slash) {
      return KeyEventResult.ignored;
    }
    final state = context.read<DashboardState>();
    final typing =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
    if (typing || state.page != DashboardPage.home) {
      return KeyEventResult.ignored;
    }
    _search.requestFocus();
    return KeyEventResult.handled;
  }

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
      body: Focus(
        // Focused at start so "/" works before anything was clicked; keys
        // from focused rows and buttons bubble up here too.
        autofocus: true,
        onKeyEvent: _onKey,
        child: SearchFocus(
          node: _search,
          child: SelectionArea(
            child: Column(
              children: [
                const AppHeader(),
                SizedBox(
                  height: 2,
                  child: state.loading
                      ? const LinearProgressIndicator(
                          minHeight: 2,
                          color: kSignal,
                          backgroundColor: Colors.transparent,
                        )
                      : null,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: motion(context, 220),
                    switchInCurve: Curves.easeOutCubic,
                    // Pages fill the space; the default centres a page
                    // whose content is shorter than the window.
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.015),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(state.page),
                      child: switch (state.page) {
                        DashboardPage.home => const LeaderboardScreen(),
                        DashboardPage.details => const FrameworkScreen(),
                        DashboardPage.compare => const CompareScreen(),
                        DashboardPage.history => const HistoryScreen(),
                        DashboardPage.method => const MethodScreen(),
                      },
                    ),
                  ),
                ),
                const CompareTray(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
