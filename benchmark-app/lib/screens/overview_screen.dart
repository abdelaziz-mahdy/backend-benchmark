import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/common.dart';

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
      return const PageBody(
        children: [
          EmptyState(
            icon: Icons.filter_list_off,
            title: 'No frameworks match the filters',
            message: 'Pick another scenario or clear the language filter.',
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
    final v1 = run.methodology == 'v1';
    final reps = run.params['reps'];
    final text = v1
        ? 'v1 method: Locust ramped to 10,000 users over 120 s, one run, 1 CPU '
              'per app. Not comparable with current results.'
        : 'Sustainable load = highest request rate held with p99 < 100 ms and '
              '< 1% errors. Each app gets 2 pinned cores; numbers are the '
              'median of ${reps ?? 3} runs.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (v1 ? kYellow : kBlue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: (v1 ? kYellow : kBlue).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            v1 ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 16,
            color: v1 ? kYellow : kBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
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
                  TextSpan(
                    text: '  ${run.machine.label}',
                    style: const TextStyle(color: kTextDim),
                  ),
                ],
              ),
              style: const TextStyle(color: kTextSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
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
      state.headline,
      Metrics.p99,
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
    final best = state.rank(backends, m).first;
    final value = m.value(state.resultOf(best)!);
    return Tooltip(
      message: m.help,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => state.openFramework(best.key),
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
              Text(
                m.higherIsBetter
                    ? 'Most ${m.short.toLowerCase()}'
                    : 'Lowest ${m.short}',
                style: const TextStyle(color: kTextMuted, fontSize: 12),
              ),
              const SizedBox(width: 10),
              ColorDot(color: BackendColors.of(best.key), size: 8),
              const SizedBox(width: 6),
              Text(
                best.name,
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
              rank: Text('${i + 1}', style: const TextStyle(color: kTextMuted)),
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
    return Row(
      children: [
        Flexible(child: BackendLabel(backend: b)),
        if (flags.isNotEmpty) ...[
          const SizedBox(width: 8),
          Wrap(spacing: 4, children: flags),
        ],
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

  const _LeaderCards({
    required this.state,
    required this.ranked,
    required this.headline,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final max = _maxOf(state, ranked, headline);
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
                          '${i + 1}',
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
