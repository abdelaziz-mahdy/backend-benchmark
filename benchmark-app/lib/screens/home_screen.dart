import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/common.dart';
import '../widgets/loading_widget.dart';
import '../widgets/site_frame.dart';
import 'history_screen.dart';
import 'home_page.dart';
import 'method_screen.dart';

/// Shell: the home page, or History or Method. "/" opens One framework and
/// focuses its picker from anywhere on the home page.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = FocusNode(debugLabel: 'framework picker');

  @override
  void dispose() {
    _picker.dispose();
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
    state.setView(HomeView.one);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _picker.requestFocus();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final p = context.palette;
    if (state.run == null) {
      return Scaffold(
        backgroundColor: p.bg,
        body: state.error != null
            ? Center(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load the results',
                  message: '${state.error}',
                ),
              )
            : const LoadingWidget(),
      );
    }
    // Every number, name and fact can be selected and copied. Selection
    // starts on drag or long-press, so taps still reach chips and buttons.
    return Scaffold(
      backgroundColor: p.bg,
      body: Focus(
        // Focused at start so "/" works before anything was clicked; keys
        // from focused buttons bubble up here too.
        autofocus: true,
        onKeyEvent: _onKey,
        child: SelectionArea(
          child: Column(
            children: [
              const SiteHeader(),
              Expanded(
                child: switch (state.page) {
                  DashboardPage.home => HomePage(picker: _picker),
                  DashboardPage.history => const _Page(child: HistoryScreen()),
                  DashboardPage.method => const _Page(child: MethodScreen()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// History and Method: a thin bar with the site name over the page.
class _Page extends StatelessWidget {
  final Widget child;

  const _Page({required this.child});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final p = context.palette;
    return Column(
      children: [
        SizedBox(
          height: 2,
          child: state.loading
              ? LinearProgressIndicator(
                  minHeight: 2,
                  color: p.accent,
                  backgroundColor: Colors.transparent,
                )
              : null,
        ),
        Expanded(child: child),
      ],
    );
  }
}
