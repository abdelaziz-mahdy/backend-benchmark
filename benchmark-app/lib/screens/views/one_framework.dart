import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/metrics.dart';
import '../../models/plain.dart';
import '../../models/results.dart';
import '../../state/dashboard_state.dart';
import '../../utils/colors.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';
import 'framework_charts.dart';
import 'home_nav.dart';

/// One framework: a picker (type to find one), the names when nothing is
/// chosen, and the chosen framework's profile.
class OneFrameworkView extends StatelessWidget {
  const OneFrameworkView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run!;
    final nav = HomeNav.of(context);
    final t = Txt.of(context);
    final b = state.selectedBackend;
    final alpha = [...run.backends]..sort((a, c) => a.name.compareTo(c.name));
    final missing = state.missingKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrameworkPicker(
          key: ValueKey('picker-${run.id}-${b?.key}'),
          backends: alpha,
          selected: b,
          focusNode: nav.picker,
          onSelected: (key) {
            state.selectFramework(key);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => nav.picker.requestFocus(),
            );
          },
        ),
        if (missing != null && b == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${capFirst(state.nameOf(missing))} was not part of this run. '
              'Pick another framework, or change the run.',
              style: t.body,
            ),
          ),
        if (b == null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final x in alpha)
                NameChip(label: x.name, onTap: () => nav.open(x.key)),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _Profile(state: state, run: run, backend: b),
          ),
      ],
    );
  }
}

/// The design's select, with typing to narrow the list (name, language or
/// runtime). Enter picks the first match.
class FrameworkPicker extends StatelessWidget {
  final List<BackendResult> backends;
  final BackendResult? selected;
  final FocusNode focusNode;
  final ValueChanged<String> onSelected;

  const FrameworkPicker({
    super.key,
    required this.backends,
    required this.selected,
    required this.focusNode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: p.text),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Framework', style: t.small),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => DropdownMenu<String>(
            width: c.maxWidth < 360 ? c.maxWidth : 360,
            menuHeight: 380,
            focusNode: focusNode,
            initialSelection: selected?.key,
            hintText: 'Choose a framework…',
            enableFilter: true,
            requestFocusOnTap: true,
            textStyle: t.body,
            filterCallback: (entries, filter) {
              final q = filter.trim();
              // The field shows the chosen name; that is not a search.
              if (q.isEmpty || q == selected?.name) return entries;
              return [
                for (final e in entries)
                  if (backends.firstWhere((b) => b.key == e.value).matches(q))
                    e,
              ];
            },
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: p.surface,
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.focus, width: 3),
              ),
              hintStyle: t.muted,
            ),
            menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(p.surface),
            ),
            dropdownMenuEntries: [
              for (final b in backends)
                DropdownMenuEntry(
                  value: b.key,
                  label: b.name,
                  style: MenuItemButton.styleFrom(
                    foregroundColor: p.text,
                    textStyle: t.body,
                    minimumSize: const Size(0, 44),
                  ),
                ),
            ],
            onSelected: (key) {
              if (key != null && key != selected?.key) onSelected(key);
            },
          ),
        ),
      ],
    );
  }
}

class _Profile extends StatelessWidget {
  final DashboardState state;
  final RunSummary run;
  final BackendResult backend;

  const _Profile({
    required this.state,
    required this.run,
    required this.backend,
  });

  @override
  Widget build(BuildContext context) {
    final nav = HomeNav.of(context);
    final p = context.palette;
    final t = Txt(p);
    final b = backend;
    final tests = testsOf(run).where(b.scenarios.containsKey).toList();
    final about = [
      languageLabel(b.language),
      [
        [b.framework ?? b.name, ?b.version].join(' '),
        if (b.runtime != null) 'on ${b.runtime}',
      ].join(' '),
      if (b.formerName != null) 'named "${b.formerName}" in this run',
    ].join(' · ');
    final cores = appCoreCount(run);
    final unit = unitFor(state.headline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          focusNode: nav.profileHeading,
          child: Semantics(
            header: true,
            child: Text(capFirst(b.name), style: t.h2),
          ),
        ),
        const SizedBox(height: 4),
        Text(about, style: t.muted),
        if (b.notes != null) ...[
          const SizedBox(height: 8),
          Text(b.notes!, style: t.smallText),
        ],
        const SizedBox(height: 12),
        _ProfileActions(state: state, backend: b),
        Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final test in tests)
                _TestRow(run: run, backend: b, test: test, unit: unit),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'On each line, the large dot is ${b.name} and the small dots are '
          'the other ${numberWord(run.backends.length - 1)} frameworks. '
          'Further right means more requests a second. The shaded part shows '
          'the lowest and highest of its runs.',
          style: t.small,
        ),
        const SizedBox(height: 8),
        Fold(
          key: ValueKey('extra-${run.id}-${b.key}'),
          title: 'Reply times, processor and memory',
          topLine: true,
          child: _ExtraTable(backend: b, tests: tests, cores: cores),
        ),
        Fold(
          key: ValueKey('charts-${run.id}-${b.key}'),
          title: 'Charts from the test',
          subtitle:
              'Every step of the load, reply times, processor and '
              'memory over time, how it is built, and its history.',
          child: FrameworkCharts(backend: b),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            CalmButton(
              label: 'Back to the short answer',
              onTap: () => nav.go(HomeView.short),
            ),
            CalmButton(
              label: 'Compare with every framework',
              onTap: () => nav.go(HomeView.all),
            ),
          ],
        ),
      ],
    );
  }
}

/// Add to (or remove from) the comparison, and copy a link to the profile.
class _ProfileActions extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;

  const _ProfileActions({required this.state, required this.backend});

  @override
  Widget build(BuildContext context) {
    final t = Txt.of(context);
    final nav = HomeNav.of(context);
    final inCompare = state.compareKeys.contains(backend.key);
    final full = !state.canAddCompare(backend.key);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CalmButton(
          label: inCompare ? 'Remove from compare' : 'Add to compare',
          icon: inCompare ? Icons.check : Icons.add,
          onTap: full ? null : () => state.toggleCompare(backend.key),
        ),
        if (state.compareKeys.isNotEmpty)
          CalmButton(
            label: 'Open compare (${state.compareKeys.length})',
            onTap: () => nav.go(HomeView.compare),
          ),
        TextLink(
          label: 'Copy a link',
          onTap: () => copyToClipboard(
            context,
            '${Uri.base.removeFragment()}#${locationOf(state)}',
            'Link copied',
          ),
        ),
        if (full)
          Text(
            'Compare holds up to ${DashboardState.maxCompare} frameworks. '
            'Remove one there to add this one.',
            style: t.small,
          ),
      ],
    );
  }
}

/// One test of the profile: the number, how many others handled more, the
/// dot strip, and the sentences about runs and close calls.
class _TestRow extends StatelessWidget {
  final RunSummary run;
  final BackendResult backend;
  final String test;
  final String unit;

  const _TestRow({
    required this.run,
    required this.backend,
    required this.test,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final all = resultsFor(run, test);
    final r = all.where((x) => x.key == backend.key).firstOrNull;
    final info = testInfo(test);
    if (r == null) return const SizedBox.shrink();
    final max = all.map((x) => x.high).fold(0.0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Semantics(header: true, child: Text(info.title, style: t.h3)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: numberText(r)),
                    TextSpan(
                      text: ' $unit',
                      style: t.small.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                style: t.num(24),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(info.what, style: t.small),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: DotStrip(
              value: r.value,
              low: r.low,
              high: r.high,
              others: [
                for (final o in all)
                  if (o.key != r.key) o.value,
              ],
              max: max,
            ),
          ),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: t.small.copyWith(fontSize: 13)),
                Text(whole(max), style: t.small.copyWith(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            resultSentences(all, r, withPlace: true).join(' '),
            style: t.smallText,
          ),
        ],
      ),
    );
  }
}

/// Typical and slow reply, processor and memory in every test, measured
/// at the framework's own result.
class _ExtraTable extends StatelessWidget {
  final BackendResult backend;
  final List<String> tests;
  final int cores;

  const _ExtraTable({
    required this.backend,
    required this.tests,
    required this.cores,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final cell = t.body.copyWith(
      fontSize: 14.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final head = cell.copyWith(color: p.muted, height: 1.2);
    Widget c(String s, TextStyle st, {bool left = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        s,
        textAlign: left ? TextAlign.left : TextAlign.right,
        style: st,
      ),
    );
    const measures = [
      Measure.typical,
      Measure.slow,
      Measure.processor,
      Measure.memory,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {0: FlexColumnWidth(1.4)},
          defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
          children: [
            TableRow(
              children: [
                c('Kind of work', head, left: true),
                for (final m in measures) c(m.short, head),
              ],
            ),
            for (final test in tests)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.line)),
                ),
                children: [
                  c(testInfo(test).short, cell, left: true),
                  for (final m in measures)
                    c(switch (m.value(
                      backend.scenarios[test]!,
                      Metrics.sustainable,
                    )) {
                      final v? => m.format(v, cores),
                      null => '—',
                    }, cell),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Bullets([
          'All of these were measured while the framework was handling the '
              'number of requests shown above.',
          'Typical reply: ${Measure.typical.meaning}.',
          'Slow reply: ${Measure.slow.meaning}.',
          'Processor: how much of its ${numberWord(cores)} processor '
              '${cores == 1 ? 'core' : 'cores'} the framework used.',
          '"ms" means milliseconds. 1,000 ms is one second.',
          'A dash means it was not measured.',
        ]),
      ],
    );
  }
}
