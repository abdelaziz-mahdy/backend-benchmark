import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/plain.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/calm.dart';
import '../widgets/run_switcher.dart';
import 'views/compare_view.dart';
import 'views/home_nav.dart';
import 'views/every_number.dart';
import 'views/one_framework.dart';
import 'views/short_answer.dart';

/// The home page: a quiet site line, the question, the "Show me" switch,
/// the chosen view, then "How we tested" and the footer.
class HomePage extends StatefulWidget {
  final FocusNode picker;

  const HomePage({super.key, required this.picker});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scroll = ScrollController();
  final _switchKey = GlobalKey(debugLabel: 'show-me');
  final _profileHeading = FocusNode(debugLabel: 'profile heading');
  final _switchFocus = {
    for (final v in HomeView.values) v: FocusNode(debugLabel: 'show ${v.name}'),
  };

  @override
  void dispose() {
    _scroll.dispose();
    _profileHeading.dispose();
    for (final f in _switchFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Scrolls the switch back into view when it is above the screen.
  void _toTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _switchKey.currentContext;
      if (ctx == null || !mounted) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      if (box.localToGlobal(Offset.zero).dy >= 0) return;
      Scrollable.ensureVisible(
        ctx,
        duration: motion(context, 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _go(HomeView view) {
    context.read<DashboardState>().setView(view);
    _toTop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _switchFocus[view]?.requestFocus();
    });
  }

  void _open(String key) {
    context.read<DashboardState>().selectFramework(key);
    _toTop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _profileHeading.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run!;
    final p = context.palette;
    final t = Txt(p);
    final view = switch (state.view) {
      HomeView.short => const ShortAnswerView(),
      HomeView.one => const OneFrameworkView(),
      HomeView.all => const EveryNumberView(),
      HomeView.compare => const CompareView(),
    };
    return HomeNav(
      go: _go,
      open: _open,
      picker: widget.picker,
      profileHeading: _profileHeading,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kHomeWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SiteLine(state: state),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(
                    'How much traffic can each backend framework handle?',
                    style: t.h1,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Text(ledeFor(run), style: t.muted),
                ),
                if (run.isLegacy) _LegacyNote(state: state),
                const SizedBox(height: 26),
                Text('Show me', key: _switchKey, style: t.small),
                const SizedBox(height: 6),
                SegmentSwitch<HomeView>(
                  label: 'Show me',
                  focusNodes: _switchFocus,
                  options: [for (final v in HomeView.values) (v, v.label)],
                  selected: state.view,
                  onSelected: state.setView,
                ),
                const SizedBox(height: 30),
                Semantics(
                  container: true,
                  label: state.view.label,
                  explicitChildNodes: true,
                  child: KeyedSubtree(
                    key: ValueKey('${run.id}/${state.view.name}'),
                    child: view,
                  ),
                ),
                const SizedBox(height: 44),
                Fold(
                  key: ValueKey('method-${run.id}'),
                  title: 'How we tested',
                  topLine: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bullets(
                        howWeTested(run),
                        style: t.body.copyWith(fontSize: 15.5),
                      ),
                      const SizedBox(height: 12),
                      TextLink(
                        label: 'Full method',
                        onTap: () => state.setPage(DashboardPage.method),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(kFootLine, style: t.small.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 20,
                  children: [
                    TextLink(
                      label: 'History',
                      onTap: () => state.setPage(DashboardPage.history),
                    ),
                    TextLink(
                      label: 'Full method',
                      onTap: () => state.setPage(DashboardPage.method),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Backend speed test · run on 5 October 2026 · Change run". The name goes
/// back to the short answer.
class _SiteLine extends StatelessWidget {
  final DashboardState state;

  const _SiteLine({required this.state});

  @override
  Widget build(BuildContext context) {
    final t = Txt.of(context);
    final entry = state.entry;
    final run = state.run!;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Pressable(
          onTap: state.goHome,
          radius: 4,
          semanticLabel: 'Backend speed test, back to the short answer',
          builder: (context, hovered) => Align(
            widthFactor: 1,
            child: Text(
              'Backend speed test',
              style: t.small.copyWith(
                decoration: hovered ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
        Text(
          ' · run on ${longDate(entry?.date ?? run.date)}'
          '${run.isLegacy ? ' (old method)' : ''} · ',
          style: t.small,
        ),
        ChangeRunButton(state: state),
        if (state.loading)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class _LegacyNote extends StatelessWidget {
  final DashboardState state;

  const _LegacyNote({required this.state});

  @override
  Widget build(BuildContext context) {
    final latest = state.index.where((e) => !e.isLegacy).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            'You are looking at an old run.',
            style: Txt.of(context).body.copyWith(fontWeight: FontWeight.w700),
          ),
          if (latest != null)
            TextLink(
              label: 'Back to the latest results',
              size: 15.5,
              onTap: () => state.selectRun(latest),
            ),
        ],
      ),
    );
  }
}
