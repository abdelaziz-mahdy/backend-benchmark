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

/// Home: every framework of the run as one row, every scenario as one
/// column. A row expands in place with its numbers for all scenarios, its
/// implementation and the compare actions.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null) return const SizedBox.shrink();
    final rows = state.sortedBackends;
    return PageBody(
      children: [
        if (run.isLegacy) const _LegacyBanner(),
        SectionCard(
          title: 'All frameworks',
          subtitle:
              'Tap a framework for its numbers in every scenario. '
              'Tap a scenario to sort by it.',
          fullBleed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _Controls(),
              ),
              if (rows.isEmpty)
                EmptyState(
                  icon: Icons.search_off,
                  title: 'No framework matches "${state.query.trim()}"',
                  message: 'Try a name, a language or a runtime.',
                )
              else
                LayoutBuilder(
                  builder: (context, c) => c.maxWidth < kNarrow
                      ? _Cards(state: state, rows: rows)
                      : _Table(state: state, rows: rows),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: _Footnote(run: run, metric: state.metric),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegacyBanner extends StatelessWidget {
  const _LegacyBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    decoration: BoxDecoration(
      color: kYellow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kYellow.withValues(alpha: 0.3)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: kYellow),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Old v1 method (Locust, 10,000 users, 1 CPU per app, no latency '
            'limit). Kept for history; not comparable with current results.',
            style: TextStyle(color: kTextSecondary, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}

/// Search box and the "Showing" number picker: the only two controls above
/// the rows.
class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  late final TextEditingController _controller;
  late final DashboardState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<DashboardState>();
    _controller = TextEditingController(text: _state.query);
    _state.addListener(_sync);
  }

  /// Keeps the field in step when the query is changed elsewhere (Clear,
  /// a run switch); done outside build so the hint reappears on empty.
  void _sync() {
    if (_controller.text != _state.query) {
      _controller.value = TextEditingValue(
        text: _state.query,
        selection: TextSelection.collapsed(offset: _state.query.length),
      );
    }
  }

  @override
  void dispose() {
    _state.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final search = SizedBox(
      height: 36,
      child: TextField(
        controller: _controller,
        onChanged: state.setQuery,
        onSubmitted: state.expandFirstMatch,
        style: const TextStyle(color: kTextPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          hintText: 'Find your framework (name, language, runtime)…',
          hintStyle: const TextStyle(color: kTextDim, fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18, color: kTextMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          suffixIcon: state.query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, color: kTextMuted),
                  onPressed: () => state.setQuery(''),
                ),
          filled: true,
          fillColor: kBackground,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBlue),
          ),
        ),
      ),
    );
    final showing = _MetricPicker(state: state);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < kNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 8), showing],
          );
        }
        return Row(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: search,
              ),
            ),
            const SizedBox(width: 16),
            showing,
          ],
        );
      },
    );
  }
}

/// "Showing: Sustainable load ▾" — the number in every cell.
class _MetricPicker extends StatelessWidget {
  final DashboardState state;

  const _MetricPicker({required this.state});

  @override
  Widget build(BuildContext context) {
    final metrics = state.availableMetrics;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'Showing',
          style: TextStyle(color: kTextMuted, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Container(
          height: 36,
          width: 190,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Metric>(
              value: metrics.contains(state.metric) ? state.metric : null,
              isDense: true,
              isExpanded: true,
              dropdownColor: kCardBg,
              icon: const Icon(Icons.expand_more, color: kTextMuted, size: 18),
              style: labelStyle(context, 13, color: kTextPrimary),
              items: [
                for (final m in metrics)
                  DropdownMenuItem(
                    value: m,
                    child: Tooltip(
                      message: m.help,
                      waitDuration: const Duration(milliseconds: 400),
                      child: Text(m.labelWithUnit),
                    ),
                  ),
              ],
              onChanged: (m) {
                if (m != null) state.setMetric(m);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Competition ranks for rows already sorted by the sort column: tied
/// values share a position (1, 1, 1, 4, …).
List<int> _positions(DashboardState state, List<BackendResult> sorted) {
  final out = <int>[];
  for (var i = 0; i < sorted.length; i++) {
    final v = state.valueOf(sorted[i], state.metric, state.sortScenario);
    if (i > 0 &&
        v != null &&
        state.valueOf(sorted[i - 1], state.metric, state.sortScenario) == v) {
      out.add(out[i - 1]);
      continue;
    }
    out.add(i + 1);
  }
  return out;
}

/// Largest value of the shown metric per scenario, over every row.
Map<String, double> _columnMax(DashboardState state, List<BackendResult> rows) {
  final out = <String, double>{};
  for (final s in state.run!.scenarios) {
    var max = 0.0;
    for (final b in rows) {
      final v = state.valueOf(b, state.metric, s);
      if (v != null && v > max) max = v;
    }
    out[s] = max;
  }
  return out;
}

const _headStyle = TextStyle(
  color: kTextMuted,
  fontSize: 12,
  fontWeight: FontWeight.w500,
);

class _Table extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> rows;

  const _Table({required this.state, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scenarios = state.run!.scenarios;
    final positions = _positions(state, rows);
    final max = _columnMax(state, rows);
    return Column(
      children: [
        _layout(
          header: true,
          rank: const Text('#', style: _headStyle),
          name: const Text('Framework', style: _headStyle),
          cells: [for (final s in scenarios) _scenarioHeader(s)],
          action: const SizedBox(width: 100),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          _HoverRow(
            expanded: state.expandedKey == rows[i].key,
            onTap: () => state.toggleExpanded(rows[i].key),
            child: _layout(
              rank: Text(
                '${positions[i]}',
                style: const TextStyle(color: kTextMuted),
              ),
              name: _NameCell(backend: rows[i]),
              cells: [
                for (final s in scenarios)
                  _ValueCell(
                    state: state,
                    backend: rows[i],
                    scenario: s,
                    max: max[s]!,
                    sorted: s == state.sortScenario,
                  ),
              ],
              action: SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _CompareButton(state: state, backend: rows[i]),
                ),
              ),
            ),
          ),
          if (state.expandedKey == rows[i].key)
            _ExpandedPanel(state: state, backend: rows[i]),
        ],
      ],
    );
  }

  Widget _scenarioHeader(String s) {
    final active = s == state.sortScenario;
    return Tooltip(
      message: '${scenarioHelp(s)}\nTap to sort by this scenario.',
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: () => state.setSortScenario(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  scenarioLabel(s),
                  overflow: TextOverflow.ellipsis,
                  style: _headStyle.copyWith(
                    color: active ? kTextPrimary : kTextMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                state.metric.higherIsBetter
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 12,
                color: active ? kOrange : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layout({
    required Widget rank,
    required Widget name,
    required List<Widget> cells,
    required Widget action,
    bool header = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: header ? 8 : 9),
      decoration: header
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            )
          : null,
      child: Row(
        children: [
          SizedBox(width: 28, child: rank),
          Expanded(flex: 30, child: name),
          for (final c in cells) ...[
            const SizedBox(width: 12),
            Expanded(flex: 15, child: c),
          ],
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  final BackendResult backend;

  const _NameCell({required this.backend});

  @override
  Widget build(BuildContext context) {
    final b = backend;
    return Row(
      children: [
        ColorDot(color: BackendColors.of(b.key)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                b.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                [
                  languageLabel(b.language),
                  ...b.subtitle.split(' · '),
                ].where((s) => s.isNotEmpty).join(' · '),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextDim, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Number + bar for one framework in one scenario. "—" when it was not
/// measured there. † marks a load-generator-bound result, ± an unstable one;
/// the footnote and the expanded row spell both out.
class _ValueCell extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final String scenario;
  final double max;
  final bool sorted;

  const _ValueCell({
    required this.state,
    required this.backend,
    required this.scenario,
    required this.max,
    required this.sorted,
  });

  @override
  Widget build(BuildContext context) {
    final r = backend.scenarios[scenario];
    final v = r == null ? null : state.metric.value(r);
    final marks = [
      if (r != null && r.loadgenBound) '†',
      if (r != null && r.unstable) '±',
      if (r != null && r.restarts > 0) '‡',
    ].join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scales down rather than overflowing in the narrow phone grid.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMetricShort(state.metric, v),
                style: TextStyle(
                  color: v == null
                      ? kTextDim
                      : (sorted ? kTextPrimary : kTextSecondary),
                  fontSize: 14,
                  fontWeight: sorted ? FontWeight.w600 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (marks.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(marks, style: const TextStyle(color: kBlue, fontSize: 11)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        InlineBar(
          value: v,
          max: max,
          color: BackendColors.of(
            backend.key,
          ).withValues(alpha: sorted ? 1 : 0.55),
          height: 5,
        ),
      ],
    );
  }
}

/// "+ Compare" / "Added" per row. Adds to the tray without leaving the page.
class _CompareButton extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final bool compact;

  const _CompareButton({
    required this.state,
    required this.backend,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = state.compareKeys.contains(backend.key);
    final enabled = state.canAddCompare(backend.key);
    final tooltip = on
        ? 'Remove from the comparison'
        : enabled
        ? 'Add to the comparison'
        : 'The comparison holds up to ${DashboardState.maxCompare}';
    if (compact) {
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        onPressed: enabled ? () => state.toggleCompare(backend.key) : null,
        icon: Icon(
          on ? Icons.check_circle : Icons.add_circle_outline,
          color: on ? kBlue : kTextMuted,
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: SizedBox(
        height: 30,
        child: OutlinedButton.icon(
          onPressed: enabled ? () => state.toggleCompare(backend.key) : null,
          icon: Icon(on ? Icons.check : Icons.add, size: 14),
          label: Text(on ? 'Added' : 'Compare'),
          style: OutlinedButton.styleFrom(
            foregroundColor: on ? kBlue : kTextSecondary,
            side: BorderSide(color: on ? kBlue : kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: labelStyle(context, 12),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  const _HoverRow({
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
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
          decoration: BoxDecoration(
            color: widget.expanded
                ? kBlue.withValues(alpha: 0.08)
                : (_hover ? kCardBgRaised : Colors.transparent),
            border: const Border(top: BorderSide(color: kGridLine)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Phone layout: one card per framework with the four scenario numbers.
class _Cards extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> rows;

  const _Cards({required this.state, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scenarios = state.run!.scenarios;
    final positions = _positions(state, rows);
    final max = _columnMax(state, rows);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _HoverRow(
            expanded: state.expandedKey == rows[i].key,
            onTap: () => state.toggleExpanded(rows[i].key),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${positions[i]}',
                          style: const TextStyle(color: kTextMuted),
                        ),
                      ),
                      Expanded(child: _NameCell(backend: rows[i])),
                      _CompareButton(
                        state: state,
                        backend: rows[i],
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 8),
                    child: Row(
                      children: [
                        for (final s in scenarios)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    scenarioLabel(s),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: s == state.sortScenario
                                          ? kTextMuted
                                          : kTextDim,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  _ValueCell(
                                    state: state,
                                    backend: rows[i],
                                    scenario: s,
                                    max: max[s]!,
                                    sorted: s == state.sortScenario,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.expandedKey == rows[i].key)
            _ExpandedPanel(state: state, backend: rows[i]),
        ],
      ],
    );
  }
}

/// What opens under a tapped row: actions, every metric for every scenario,
/// rank, flags in words, and how the backend is implemented.
class _ExpandedPanel extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;

  const _ExpandedPanel({required this.state, required this.backend});

  @override
  Widget build(BuildContext context) {
    final b = backend;
    final scenarios = state.run!.scenarios;
    final present = scenarios.where(b.scenarios.containsKey).toList();
    final results = b.scenarios.values;
    final metrics = Metrics.available(results, Metrics.table);
    final others = state.allRanked.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: kBlue.withValues(alpha: 0.04),
        border: const Border(
          top: BorderSide(color: kGridLine),
          left: BorderSide(color: kBlue, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: others >= 1
                    ? () => state.compareWithLeaders(b.key)
                    : null,
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: const Text('Compare with the leaders'),
                style: FilledButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: kBackground,
                  visualDensity: VisualDensity.compact,
                  textStyle: labelStyle(context, 12.5, weight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => state.openDetails(b.key),
                icon: const Icon(Icons.show_chart, size: 16),
                label: const Text('Full details and charts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kBorder),
                  visualDensity: VisualDensity.compact,
                  textStyle: labelStyle(context, 12.5),
                ),
              ),
              if (b.sourceUrl != null)
                SourceLink(url: b.sourceUrl!, label: 'Source on GitHub'),
            ],
          ),
          const SizedBox(height: 12),
          if (present.isEmpty)
            const Text(
              'Not measured in this run.',
              style: TextStyle(color: kTextMuted, fontSize: 12.5),
            )
          else
            _Grid(
              state: state,
              backend: b,
              scenarios: scenarios,
              metrics: metrics,
            ),
          ..._notes(b, present),
          const SizedBox(height: 12),
          _implementation(b),
        ],
      ),
    );
  }

  /// Flags written out, one line per scenario they apply to.
  List<Widget> _notes(BackendResult b, List<String> present) {
    final lines = <String>[];
    final bound = present.where((s) => b.scenarios[s]!.loadgenBound).toList();
    if (bound.isNotEmpty) {
      lines.add(
        '† ${bound.map(scenarioLabel).join(', ')}: the load generator was '
        'the limit here; the real number may be higher.',
      );
    }
    for (final s in present) {
      final r = b.scenarios[s]!;
      if (r.unstable) {
        lines.add(
          '± ${scenarioLabel(s)}: repetitions differed by '
          '${(r.spread * 100).toStringAsFixed(0)}%; treat small differences '
          'with care.',
        );
      }
    }
    for (final s in present) {
      final n = b.scenarios[s]!.restarts;
      if (n > 0) {
        lines.add(
          '‡ ${scenarioLabel(s)}: under overload the app stopped responding '
          'and had to be restarted ${n == 1 ? 'once' : '$n times'}; it did not '
          'recover by itself.',
        );
      }
    }
    if (b.notes != null) lines.add('Note: ${b.notes}');
    if (lines.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            l,
            style: const TextStyle(color: kTextSecondary, fontSize: 12),
          ),
        ),
    ];
  }

  Widget _implementation(BackendResult b) {
    final impl = b.implementation;
    final facts = <(String, String)>[
      ...?impl?.facts,
      ('API', b.apiLabel),
      ('Database', b.storageLabel),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How it is implemented',
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (impl == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'No implementation details recorded; see the source folder.',
              style: TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ),
        FactList(facts: [for (final (l, v) in facts) (l, factText(v))]),
        if (b.implementationFrom == 'manifest')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Details come from the current source, not from this run.',
              style: TextStyle(color: kTextDim, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

/// Metric rows × scenario columns for one framework, with a rank row for
/// the number the table shows.
class _Grid extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final List<String> scenarios;
  final List<Metric> metrics;

  const _Grid({
    required this.state,
    required this.backend,
    required this.scenarios,
    required this.metrics,
  });

  static const _label = TextStyle(color: kTextMuted, fontSize: 12);
  static const _value = TextStyle(
    color: kTextSecondary,
    fontSize: 12.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final shown = state.metric;
    final rankMetric = metrics.contains(shown) ? shown : metrics.first;
    final table = Table(
      columnWidths: {
        0: const FixedColumnWidth(168),
        for (var i = 0; i < scenarios.length; i++)
          i + 1: const FixedColumnWidth(96),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          children: [
            const SizedBox(height: 26),
            for (final s in scenarios)
              Text(
                scenarioLabel(s),
                textAlign: TextAlign.right,
                style: _headStyle.copyWith(
                  color: s == state.sortScenario ? kTextPrimary : kTextMuted,
                ),
              ),
          ],
        ),
        for (final m in metrics)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Tooltip(
                  message: m.help,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    m.labelWithUnit,
                    style: m == rankMetric
                        ? _label.copyWith(
                            color: kTextPrimary,
                            fontWeight: FontWeight.w600,
                          )
                        : _label,
                  ),
                ),
              ),
              for (final s in scenarios)
                Text(
                  _cell(m, s),
                  textAlign: TextAlign.right,
                  style: m == rankMetric
                      ? _value.copyWith(
                          color: kTextPrimary,
                          fontWeight: FontWeight.w600,
                        )
                      : _value,
                ),
            ],
          ),
        TableRow(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kGridLine)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                'Rank by ${rankMetric.short.toLowerCase()}',
                style: _label,
              ),
            ),
            for (final s in scenarios)
              Text(
                _rank(rankMetric, s),
                textAlign: TextAlign.right,
                style: _value.copyWith(color: kTextPrimary),
              ),
          ],
        ),
        TableRow(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Text('Share of the best', style: _label),
            ),
            for (final s in scenarios)
              Text(
                _share(rankMetric, s),
                textAlign: TextAlign.right,
                style: _value,
              ),
          ],
        ),
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );
  }

  String _cell(Metric m, String s) {
    final r = backend.scenarios[s];
    if (r == null) return '—';
    return formatMetricShort(m, m.value(r));
  }

  String _rank(Metric m, String s) {
    final rank = state.rankOf(backend, m, s);
    return rank == null ? '—' : rank.label;
  }

  String _share(Metric m, String s) {
    final rank = state.rankOf(backend, m, s);
    if (rank == null) return '—';
    if (rank.position == 1) return rank.tied > 1 ? 'tied best' : 'best';
    final share = m.higherIsBetter
        ? rank.shareOfLeader
        : (rank.value != null && rank.value! > 0 && rank.leader != null
              ? rank.leader! / rank.value!
              : null);
    return share == null ? '—' : '${(share * 100).round()}%';
  }
}

/// What the numbers are, in one place under the table. No tooltips needed.
class _Footnote extends StatelessWidget {
  final RunSummary run;
  final Metric metric;

  const _Footnote({required this.run, required this.metric});

  @override
  Widget build(BuildContext context) {
    final reps = run.params['reps'] ?? 3;
    final what = run.isLegacy
        ? '${metric.label}: ${metric.help}'
        : metric == Metrics.sustainable
        ? 'Sustainable load: the highest request rate each framework held '
              'with p99 < 100 ms and < 1% errors, on 2 pinned cores, median '
              'of $reps repetitions.'
        : '${metric.label}: ${metric.help} Measured at each framework\'s '
              'own sustainable load, on 2 pinned cores, median of $reps '
              'repetitions.';
    return Text(
      '$what  † = the load generator was the limit; the real number may be '
      'higher.  ± = repetitions differed by more than 10%.  '
      '‡ = stopped responding under overload and was restarted.  '
      '— = not measured in that scenario.',
      style: const TextStyle(color: kTextMuted, fontSize: 11.5, height: 1.4),
    );
  }
}

String languageLabel(String l) => switch (l) {
  'c_sharp' => 'C#',
  'javascript' => 'JavaScript',
  _ => l.isEmpty ? l : l[0].toUpperCase() + l.substring(1),
};
