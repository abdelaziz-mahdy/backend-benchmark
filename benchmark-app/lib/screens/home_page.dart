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
  /// The scroll of the view shown, replaced when the view changes. Back and
  /// Forward start a view where it was left; any other change starts where
  /// the page is (then moves to the switch), and a new page at the top.
  ScrollController? _scroll;
  HomeView? _scrollView;

  ScrollController _scrollFor(DashboardState s) {
    final now = _scroll;
    if (now != null && _scrollView == s.view) return now;
    final from = now != null && now.hasClients ? now.offset : 0.0;
    final view = s.view;
    final c = ScrollController(
      initialScrollOffset: s.viaHistory ? s.viewScroll[view] ?? 0 : from,
      keepScrollOffset: false,
    );
    c.addListener(() {
      if (c.hasClients) s.viewScroll[view] = c.offset;
    });
    // The old one is still attached until this frame swaps the views.
    if (now != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => now.dispose());
    }
    _scroll = c;
    _scrollView = view;
    return c;
  }

  final _switchKey = GlobalKey(debugLabel: 'show-me');
  final _profileHeading = FocusNode(debugLabel: 'profile heading');
  final _switchFocus = {
    for (final v in HomeView.values) v: FocusNode(debugLabel: 'show ${v.name}'),
  };

  @override
  void dispose() {
    _scroll?.dispose();
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
    // at the switch, not wherever the last view was scrolled to; Back and
    // Forward return to where that view was left.
    if (_shown != null && _shown != state.view && !state.viaHistory) _toTop();
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
        key: ValueKey(state.view),
        controller: _scrollFor(state),
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
                  // Described by the run on screen, which lags the chosen
                  // one while that loads.
                  if ((state.shownEntry ?? state.entry) != null &&
                      state.index.isNotEmpty &&
                      (state.shownEntry ?? state.entry) != state.index.first)
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
    // The run on screen, not the one loading: label and numbers agree.
    final entry = state.shownEntry ?? state.entry;
    final run = state.run!;
    // The icon sits inline at the start of the text, so it always shares
    // the text's first line at every width; "Change run" wraps after it.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: context.palette.muted,
                  ),
                ),
              ),
              TextSpan(
                // The latest view combines each framework's newest run.
                text:
                    '${entry?.kind != RunKind.latest
                        ? 'Results from'
                        : entry == state.index.firstOrNull
                        ? 'Latest results, up to'
                        : 'Combined results of an older method, up to'} '
                    '${longDate(entry?.date ?? run.date)}'
                    '${run.isLegacy ? ' (old method)' : ''}',
              ),
            ],
          ),
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
        // Full width, so it sits on its own line under the run choice.
        if (state.failedRun != null)
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: RunLoadFailedNote(state: state),
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
            // Said for what it is: the newest single run is not "old".
            switch ((state.shownEntry ?? state.entry)?.kind) {
              RunKind.legacy => 'You are looking at a run from the old method.',
              RunKind.latest => "You are looking at an older method's results.",
              _ =>
                'You are looking at one run, not the latest combined results.',
            },
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
