import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/common.dart';
import '../widgets/implementation.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Metric? _sortBy;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null) return const SizedBox.shrink();
    final backends = state.visibleBackends;
    if (backends.isEmpty) {
      return PageBody(
        children: [
          EmptyState(
            icon: Icons.filter_list_off,
            title: state.query.trim().isNotEmpty
                ? 'No framework matches "${state.query.trim()}"'
                : 'No frameworks match the filters',
            message: 'Pick another scenario or clear the filters.',
          ),
        ],
      );
    }
    final results = backends.map(state.resultOf).whereType<ScenarioResult>();
    final headline = state.headline;
    final columns = Metrics.available(results, Metrics.table);
    final sortBy = columns.contains(_sortBy) ? _sortBy! : headline;
    final ranked = state.rank(backends, sortBy);

    return PageBody(
      children: [
        _MethodNote(run: run, scenario: state.scenario!),
        _RankBy(
          state: state,
          columns: columns,
          sortBy: sortBy,
          onSort: (m) => setState(() => _sortBy = m),
        ),
        _Leaders(state: state, backends: backends),
        SectionCard(
          title: 'Leaderboard',
          subtitle:
              'Sorted by ${sortBy.label.toLowerCase()}. Tap a column to sort, '
              'a row to open the framework.',
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < kNarrow
                ? _LeaderCards(
                    state: state,
                    ranked: ranked,
                    headline: headline,
                    columns: columns,
                    sortBy: sortBy,
                  )
                : _LeaderTable(
                    state: state,
                    ranked: ranked,
                    headline: headline,
                    columns: columns,
                    sortBy: sortBy,
                    onSort: (m) => setState(() => _sortBy = m),
                  ),
          ),
        ),
      ],
    );
  }
}

/// One line explaining what the numbers mean for this run.
class _MethodNote extends StatelessWidget {
  final RunSummary run;
  final String scenario;

  const _MethodNote({required this.run, required this.scenario});

  @override
  Widget build(BuildContext context) {
    final state = context.read<DashboardState>();
    final v1 = run.isLegacy;
    final reps = run.params['reps'];
    final text = v1
        ? 'Old v1 method (Locust, 10,000 users, 1 CPU per app). '
              'Not comparable with current results.'
        : 'Numbers are the highest load each app held within the latency '
              'and error limits, on 2 cores, median of ${reps ?? 3} runs.';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: (v1 ? kYellow : kBlue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: (v1 ? kYellow : kBlue).withValues(alpha: 0.3),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 4,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  v1 ? Icons.warning_amber_rounded : Icons.info_outline,
                  size: 16,
                  color: v1 ? kYellow : kBlue,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${scenarioLabel(scenario)}: ',
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: '${scenarioHelp(scenario)} '),
                        TextSpan(text: text),
                      ],
                    ),
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => state.setTab(DashboardTab.method),
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text(
              "How it's measured",
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decision presets: plain-language names for the sort metric.
class _RankBy extends StatelessWidget {
  final DashboardState state;
  final List<Metric> columns;
  final Metric sortBy;
  final ValueChanged<Metric> onSort;

  const _RankBy({
    required this.state,
    required this.columns,
    required this.sortBy,
    required this.onSort,
  });

  static final _presets = <(String, Metric, String?)>[
    ('Most load', Metrics.sustainable, null),
    ('Most load (v1 avg)', Metrics.avgRps, null),
    ('Cheapest per core', Metrics.rpsPerCore, null),
    ('Least memory', Metrics.memory, null),
    (
      'Lowest p99',
      Metrics.p99,
      'Careful: each p99 is measured at that framework\'s own sustainable '
          'load, so a slower framework can show a lower p99 by serving less.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = _presets.where((p) => columns.contains(p.$2)).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Text(
            'Rank by',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
        ),
        for (final (label, metric, caveat) in shown)
          Tooltip(
            message: caveat ?? metric.help,
            waitDuration: const Duration(milliseconds: 300),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (caveat != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.info_outline, size: 12, color: kYellow),
                  ],
                ],
              ),
              selected: sortBy == metric,
              onSelected: (_) => onSort(metric),
              labelStyle: TextStyle(
                fontSize: 12,
                color: sortBy == metric ? kTextPrimary : kTextMuted,
              ),
              selectedColor: kOrange.withValues(alpha: 0.18),
              backgroundColor: kBackground,
              side: BorderSide(color: sortBy == metric ? kOrange : kBorder),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

/// Compact "who leads what" strip.
class _Leaders extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> backends;

  const _Leaders({required this.state, required this.backends});

  @override
  Widget build(BuildContext context) {
    final results = backends.map(state.resultOf).whereType<ScenarioResult>();
    final metrics = Metrics.available(results, [
      // No p99 leader: each framework's p99 is taken at its own sustainable
      // load, so a slower framework can "win" by running less traffic.
      state.headline,
      Metrics.rpsPerCore,
      Metrics.memory,
    ]);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final m in metrics) _leader(m)],
    );
  }

  Widget _leader(Metric m) {
    final ranked = state.rank(backends, m);
    final best = ranked.first;
    final value = m.value(state.resultOf(best)!);
    // Several frameworks can share the top value (e.g. all capped by the load
    // generator); naming only the first would invent a winner.
    final tied = [
      for (final b in ranked)
        if (value != null && m.value(state.resultOf(b)!) == value) b,
    ];
    final isTie = tied.length > 1;
    return Tooltip(
      message: isTie
          ? '${m.help}\n\nTied: ${tied.map((b) => b.name).join(', ')}'
          : m.help,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: isTie ? null : () => state.openFramework(best.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  m.higherIsBetter
                      ? 'Highest ${m.label.toLowerCase()}'
                      : 'Lowest ${m.label.toLowerCase()}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              if (isTie)
                for (final b in tied.take(4))
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: ColorDot(color: BackendColors.of(b.key), size: 8),
                  )
              else
                ColorDot(color: BackendColors.of(best.key), size: 8),
              const SizedBox(width: 6),
              Text(
                isTie ? '${tied.length} tied' : best.name,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMetric(m, value),
                style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _maxOf(DashboardState state, List<BackendResult> bs, Metric m) {
  var max = 0.0;
  for (final b in bs) {
    final r = state.resultOf(b);
    final s = r == null ? null : m.stat(r);
    final v = s?.max ?? (r == null ? null : m.value(r));
    if (v != null && v > max) max = v;
  }
  return max;
}

/// Competition ranks for a list already sorted by [m]: tied values share a
/// position (1, 1, 1, 4, …) so a tie never looks like an order.
List<int> _ranks(DashboardState state, List<BackendResult> sorted, Metric m) {
  final out = <int>[];
  for (var i = 0; i < sorted.length; i++) {
    final r = state.resultOf(sorted[i]);
    final v = r == null ? null : m.value(r);
    if (i > 0 && v != null) {
      final pr = state.resultOf(sorted[i - 1]);
      if (pr != null && m.value(pr) == v) {
        out.add(out[i - 1]);
        continue;
      }
    }
    out.add(i + 1);
  }
  return out;
}

class _LeaderTable extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> ranked;
  final Metric headline;
  final List<Metric> columns;
  final Metric sortBy;
  final ValueChanged<Metric> onSort;

  const _LeaderTable({
    required this.state,
    required this.ranked,
    required this.headline,
    required this.columns,
    required this.sortBy,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final others = columns.where((m) => m != headline).toList();
    final max = _maxOf(state, ranked, headline);
    final positions = _ranks(state, ranked, sortBy);
    return Column(
      children: [
        _row(
          rank: const Text('#', style: _headStyle),
          name: const Text('Framework', style: _headStyle),
          headlineCell: _header(headline),
          cells: [for (final m in others) _header(m)],
          compare: const SizedBox(width: 32),
          header: true,
        ),
        for (var i = 0; i < ranked.length; i++)
          _BodyRow(
            onTap: () => state.openFramework(ranked[i].key),
            child: _row(
              rank: Text(
                '${positions[i]}',
                style: const TextStyle(color: kTextMuted),
              ),
              name: _nameCell(ranked[i]),
              headlineCell: _headlineCell(ranked[i], max),
              cells: [
                for (final m in others)
                  Text(
                    formatMetricShort(m, m.value(state.resultOf(ranked[i])!)),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
              compare: _CompareToggle(state: state, backendKey: ranked[i].key),
            ),
          ),
      ],
    );
  }

  static const _headStyle = TextStyle(
    color: kTextMuted,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  Widget _header(Metric m) {
    final active = m == sortBy;
    return Tooltip(
      message: m.help,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () => onSort(m),
        child: Row(
          mainAxisAlignment: m == headline
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                m == headline ? m.label : m.short,
                overflow: TextOverflow.ellipsis,
                style: _headStyle.copyWith(
                  color: active ? kTextPrimary : kTextMuted,
                ),
              ),
            ),
            Icon(
              m.higherIsBetter ? Icons.arrow_downward : Icons.arrow_upward,
              size: 12,
              color: active ? kOrange : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameCell(BackendResult b) {
    final flags = resultFlags(b, state.resultOf(b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: BackendLabel(backend: b)),
            if (flags.isNotEmpty) ...[
              const SizedBox(width: 8),
              Wrap(spacing: 4, children: flags),
            ],
          ],
        ),
        if (b.implementation != null)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 2),
            child: ImplLine(backend: b),
          ),
      ],
    );
  }

  Widget _headlineCell(BackendResult b, double max) {
    final r = state.resultOf(b)!;
    final s = headline.stat(r);
    final v = headline.value(r);
    return Row(
      children: [
        Expanded(
          child: InlineBar(
            value: v,
            max: max,
            low: s?.min,
            high: s?.max,
            color: BackendColors.of(b.key),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(
            formatMetricShort(headline, v),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: kTextPrimary,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row({
    required Widget rank,
    required Widget name,
    required Widget headlineCell,
    required List<Widget> cells,
    required Widget compare,
    bool header = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: header
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            )
          : null,
      child: Row(
        children: [
          SizedBox(width: 28, child: rank),
          Expanded(flex: 26, child: name),
          const SizedBox(width: 12),
          Expanded(flex: 26, child: headlineCell),
          for (final c in cells) ...[
            const SizedBox(width: 8),
            Expanded(flex: 9, child: c),
          ],
          const SizedBox(width: 8),
          compare,
        ],
      ),
    );
  }
}

class _BodyRow extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _BodyRow({required this.onTap, required this.child});

  @override
  State<_BodyRow> createState() => _BodyRowState();
}

class _BodyRowState extends State<_BodyRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: _hover ? kCardBgRaised : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Adds/removes a framework from the Compare set without leaving the page.
class _CompareToggle extends StatelessWidget {
  final DashboardState state;
  final String backendKey;

  const _CompareToggle({required this.state, required this.backendKey});

  @override
  Widget build(BuildContext context) {
    final on = state.compareKeys.contains(backendKey);
    final enabled = state.canAddCompare(backendKey);
    return SizedBox(
      width: 32,
      child: IconButton(
        tooltip: on
            ? 'Remove from Compare'
            : enabled
            ? 'Add to Compare'
            : 'Compare holds up to ${DashboardState.maxCompare}',
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        onPressed: enabled ? () => state.toggleCompare(backendKey) : null,
        icon: Icon(
          on ? Icons.check_box : Icons.check_box_outline_blank,
          color: on ? kBlue : kTextDim,
        ),
      ),
    );
  }
}

class _LeaderCards extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> ranked;
  final Metric headline;
  final List<Metric> columns;
  final Metric sortBy;

  const _LeaderCards({
    required this.state,
    required this.ranked,
    required this.headline,
    required this.columns,
    required this.sortBy,
  });

  @override
  Widget build(BuildContext context) {
    final max = _maxOf(state, ranked, headline);
    final positions = _ranks(state, ranked, sortBy);
    final others = columns.where((m) => m != headline).take(4).toList();
    return Column(
      children: [
        for (var i = 0; i < ranked.length; i++)
          InkWell(
            onTap: () => state.openFramework(ranked[i].key),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kGridLine)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${positions[i]}',
                          style: const TextStyle(color: kTextMuted),
                        ),
                      ),
                      Expanded(child: BackendLabel(backend: ranked[i])),
                      Text(
                        formatMetric(
                          headline,
                          headline.value(state.resultOf(ranked[i])!),
                        ),
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _CompareToggle(state: state, backendKey: ranked[i].key),
                    ],
                  ),
                  if (ranked[i].implementation != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 2),
                      child: ImplLine(backend: ranked[i]),
                    ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 22, right: 8),
                    child: InlineBar(
                      value: headline.value(state.resultOf(ranked[i])!),
                      max: max,
                      color: BackendColors.of(ranked[i].key),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        for (final m in others)
                          Text(
                            '${m.short} ${formatMetricShort(m, m.value(state.resultOf(ranked[i])!))}',
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ...resultFlags(ranked[i], state.resultOf(ranked[i])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
