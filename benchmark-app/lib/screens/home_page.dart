import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/plain.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/calm.dart';
import '../widgets/run_switcher.dart';
import '../widgets/site_frame.dart';
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

  HomeView? _shown;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    // A view changed from elsewhere (the logo, the footer, a link) starts
    // at the switch, not wherever the last view was scrolled to.
    if (_shown != null && _shown != state.view) _toTop();
    _shown = state.view;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SiteWidth(
              max: kHomeWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 36),
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
                  const SizedBox(height: 12),
                  _RunLine(state: state),
                  if (state.entry != null &&
                      state.index.isNotEmpty &&
                      state.entry != state.index.first)
                    _LegacyNote(state: state),
                  const SizedBox(height: 26),
                  SizedBox(key: _switchKey),
                  SegmentSwitch<HomeView>(
                    label: 'Choose a view',
                    focusNodes: _switchFocus,
                    options: [for (final v in HomeView.values) (v, v.label)],
                    icons: const {
                      HomeView.short: Icons.emoji_events_outlined,
                      HomeView.one: Icons.search,
                      HomeView.all: Icons.table_rows_outlined,
                      HomeView.compare: Icons.compare_arrows,
                    },
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
                ],
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

/// "Results from 5 October 2026 · Change run", under the lede.
class _RunLine extends StatelessWidget {
  final DashboardState state;

  const _RunLine({required this.state});

  @override
  Widget build(BuildContext context) {
    final t = Txt.of(context);
    final entry = state.entry;
    final run = state.run!;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: context.palette.muted,
        ),
        const SizedBox(width: 6),
        Text(
          // The latest view combines each framework's newest run.
          '${entry?.kind != RunKind.latest
              ? 'Results from'
              : entry == state.index.firstOrNull
              ? 'Latest results, up to'
              : 'Combined results of an older method, up to'} '
          '${longDate(entry?.date ?? run.date)}'
          '${run.isLegacy ? ' (old method)' : ''}',
          style: t.small,
        ),
        const SizedBox(width: 10),
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
    final latest = state.index.firstOrNull;
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
