import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/implementation.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

enum _OverTime { cpu, memory, dbCpu, rps }

class _CompareScreenState extends State<CompareScreen> {
  _OverTime _overTime = _OverTime.cpu;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final visible = state.visibleBackends;
    if (state.run == null || visible.isEmpty) {
      return const PageBody(
        children: [
          EmptyState(
            icon: Icons.filter_list_off,
            title: 'No frameworks match the filters',
          ),
        ],
      );
    }
    final selected = [
      for (final k in state.compareKeys)
        ?visible.where((b) => b.key == k).firstOrNull,
    ];
    return PageBody(
      children: [
        _Chooser(state: state, visible: visible),
        if (selected.length < 2)
          const EmptyState(
            icon: Icons.compare_arrows,
            title: 'Pick at least two frameworks to compare',
            message: 'Tap the chips above, or tick rows on the Overview.',
          )
        else ...[
          _Bars(state: state, selected: selected),
          if (selected.any((b) => state.resultOf(b)!.steps.isNotEmpty))
            _steps(state, selected),
          _overTimeCard(state, selected),
          _Table(state: state, selected: selected),
        ],
      ],
    );
  }

  Widget _steps(DashboardState state, List<BackendResult> selected) {
    final series = [
      for (final b in selected)
        if (state.resultOf(b)!.steps.isNotEmpty)
          StepSeries(b, state.resultOf(b)!.steps),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final a = SectionCard(
          title: 'Throughput per load step',
          subtitle:
              'Where each line leaves the dashed diagonal, it stops keeping up.',
          child: Column(
            children: [
              StepLoadChart(series: series, mode: StepChartMode.throughput),
              const SizedBox(height: 8),
              ChartLegend(backends: selected),
            ],
          ),
        );
        final b = SectionCard(
          title: 'p99 latency per load step',
          subtitle: 'Above the orange line the SLO is missed.',
          child: Column(
            children: [
              StepLoadChart(series: series, mode: StepChartMode.p99),
              const SizedBox(height: 8),
              ChartLegend(backends: selected),
            ],
          ),
        );
        if (c.maxWidth < 900) {
          return Column(children: [a, const SizedBox(height: 16), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _overTimeCard(DashboardState state, List<BackendResult> selected) {
    final series = [
      for (final b in selected)
        if (!state.resultOf(b)!.timeseries.isEmpty)
          (b, state.resultOf(b)!.timeseries),
    ];
    if (series.isEmpty) return const SizedBox.shrink();
    final available = {
      _OverTime.cpu: series.any((s) => s.$2.series.containsKey('app_cpu')),
      _OverTime.memory: series.any(
        (s) => s.$2.series.containsKey('app_mem_mb'),
      ),
      _OverTime.dbCpu: series.any((s) => s.$2.series.containsKey('db_cpu')),
      _OverTime.rps: series.any((s) => s.$2.series.containsKey('rps')),
    };
    final mode = available[_overTime]! ? _overTime : _OverTime.cpu;
    final (field, format) = switch (mode) {
      _OverTime.cpu => ('app_cpu', (double v) => '${v.toStringAsFixed(0)}%'),
      _OverTime.memory => ('app_mem_mb', (double v) => '${formatNumber(v)} MB'),
      _OverTime.dbCpu => ('db_cpu', (double v) => '${v.toStringAsFixed(0)}%'),
      _OverTime.rps => ('rps', formatNumber),
    };
    return SectionCard(
      title: 'Over time',
      subtitle:
          'Whole run, warmup included. Faster frameworks run more steps, so their lines are longer.',
      trailing: SegmentedButton<_OverTime>(
        showSelectedIcon: false,
        style: kSegmentedStyle,
        segments: [
          for (final e in available.entries)
            if (e.value)
              ButtonSegment(
                value: e.key,
                label: Text(switch (e.key) {
                  _OverTime.cpu => 'CPU',
                  _OverTime.memory => 'Memory',
                  _OverTime.dbCpu => 'DB CPU',
                  _OverTime.rps => 'rps',
                }, style: const TextStyle(fontSize: 12)),
              ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => setState(() => _overTime = s.first),
      ),
      child: Column(
        children: [
          TimeSeriesChart(series: series, field: field, format: format),
          const SizedBox(height: 8),
          ChartLegend(backends: [for (final s in series) s.$1]),
        ],
      ),
    );
  }
}

class _Chooser extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> visible;

  const _Chooser({required this.state, required this.visible});

  @override
  Widget build(BuildContext context) {
    final ranked = state.rank(visible, state.headline);
    final full = state.compareKeys.length >= DashboardState.maxCompare;
    return SectionCard(
      title: 'Frameworks',
      subtitle: full
          ? 'Comparing the maximum of ${DashboardState.maxCompare}. Remove one to add another.'
          : 'Pick 2 to ${DashboardState.maxCompare}. Ordered by ${state.headline.label.toLowerCase()}.',
      trailing: state.compareKeys.isEmpty
          ? TextButton(
              onPressed: () {
                for (final b in ranked.take(3)) {
                  state.toggleCompare(b.key);
                }
              },
              child: const Text('Top 3'),
            )
          : TextButton(
              onPressed: () {
                for (final k in [...state.compareKeys]) {
                  state.toggleCompare(k);
                }
              },
              child: const Text('Clear'),
            ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final b in ranked)
            _chip(
              b,
              state.compareKeys.contains(b.key),
              state.canAddCompare(b.key),
            ),
        ],
      ),
    );
  }

  Widget _chip(BackendResult b, bool on, bool enabled) {
    final color = BackendColors.of(b.key);
    return FilterChip(
      avatar: ColorDot(color: enabled ? color : kTextDim, size: 9),
      label: Text(b.name),
      selected: on,
      onSelected: enabled ? (_) => state.toggleCompare(b.key) : null,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12.5,
        color: on ? kTextPrimary : (enabled ? kTextSecondary : kTextDim),
      ),
      color: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? color.withValues(alpha: 0.18)
            : kBackground,
      ),
      side: BorderSide(color: on ? color : kBorder),
      tooltip: enabled
          ? null
          : 'Compare holds up to ${DashboardState.maxCompare}',
    );
  }
}

/// One small bar group per metric; the best value is bold.
class _Bars extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> selected;

  const _Bars({required this.state, required this.selected});

  @override
  Widget build(BuildContext context) {
    final results = selected.map(state.resultOf).whereType<ScenarioResult>();
    final metrics = Metrics.available(results, [
      state.headline,
      Metrics.peak,
      Metrics.p99,
      Metrics.cpu,
      Metrics.memory,
      Metrics.rpsPerCore,
    ]);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 700 ? 2 : 1);
        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final m in metrics) SizedBox(width: w, child: _group(m)),
          ],
        );
      },
    );
  }

  Widget _group(Metric m) {
    final values = {
      for (final b in selected) b.key: m.value(state.resultOf(b)!),
    };
    final present = values.values.whereType<double>();
    final max = present.isEmpty ? 0.0 : present.reduce((a, b) => a > b ? a : b);
    final best = state.rank(selected, m).first.key;
    return SectionCard(
      title: m.label,
      subtitle: m.higherIsBetter ? 'Higher is better' : 'Lower is better',
      child: Column(
        children: [
          for (final b in selected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      b.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: InlineBar(
                      value: values[b.key],
                      max: max,
                      color: BackendColors.of(b.key),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      formatMetricShort(m, values[b.key]),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: b.key == best ? kTextPrimary : kTextSecondary,
                        fontWeight: b.key == best
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> selected;

  const _Table({required this.state, required this.selected});

  @override
  Widget build(BuildContext context) {
    final results = selected.map(state.resultOf).whereType<ScenarioResult>();
    final metrics = Metrics.available(results, Metrics.all);
    final sha = state.run!.dirty ? null : state.run!.gitSha;
    return SectionCard(
      title: 'Side by side',
      subtitle:
          'Best value per row in green. The lower half shows how each one is '
          'implemented, so you can judge whether the comparison is fair.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 34,
          dataRowMaxHeight: double.infinity,
          columnSpacing: 28,
          horizontalMargin: 4,
          columns: [
            const DataColumn(
              label: Text(
                'Metric',
                style: TextStyle(color: kTextMuted, fontSize: 12),
              ),
            ),
            for (final b in selected)
              DataColumn(
                label: Row(
                  children: [
                    ColorDot(color: BackendColors.of(b.key), size: 8),
                    const SizedBox(width: 6),
                    Text(
                      b.name,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          rows: [
            for (final m in metrics) _row(m),
            _heading('Implementation'),
            _textRow('Server', (b) => b.implementation?.server),
            _textRow('Concurrency', (b) => b.implementation?.concurrency),
            _textRow('DB access', (b) => b.implementation?.dbAccess),
            _textRow('DB pool', (b) => b.implementation?.pool),
            _textRow('API', (b) => b.apiLabel),
            _textRow('Database', (b) => b.storageLabel),
            _textRow('Version', (b) => b.version),
            _textRow('Runtime', (b) => b.runtime),
            DataRow(
              cells: [
                _label('Source'),
                for (final b in selected)
                  DataCell(
                    b.sourceUrl == null
                        ? _dim('—')
                        : _cell(
                            SourceLink(
                              url: b.sourceUrlAt(sha) ?? b.sourceUrl!,
                              label: 'backends/${b.path}',
                            ),
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _cellWidth = 230.0;

  Widget _cell(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: _cellWidth),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: child,
    ),
  );

  Widget _dim(String s) =>
      Text(s, style: const TextStyle(color: kTextDim, fontSize: 12.5));

  DataCell _label(String text) => DataCell(
    Text(text, style: const TextStyle(color: kTextSecondary, fontSize: 12.5)),
  );

  DataRow _heading(String text) => DataRow(
    color: WidgetStatePropertyAll(kBlue.withValues(alpha: 0.06)),
    cells: [
      DataCell(
        Text(
          text,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      for (final _ in selected) const DataCell(SizedBox.shrink()),
    ],
  );

  DataRow _textRow(String label, String? Function(BackendResult) value) =>
      DataRow(
        cells: [
          _label(label),
          for (final b in selected)
            DataCell(
              value(b) == null
                  ? _dim('—')
                  : _cell(
                      Text(
                        value(b)!,
                        softWrap: true,
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ),
            ),
        ],
      );

  DataRow _row(Metric m) {
    final best = state.rank(selected, m).first.key;
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Text(
                m.label,
                style: const TextStyle(color: kTextSecondary, fontSize: 12.5),
              ),
              InfoIcon(m.help),
            ],
          ),
        ),
        for (final b in selected)
          DataCell(
            Text(
              formatMetric(m, m.value(state.resultOf(b)!)),
              style: TextStyle(
                color: b.key == best && m.value(state.resultOf(b)!) != null
                    ? kGreen
                    : kTextSecondary,
                fontSize: 12.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}
