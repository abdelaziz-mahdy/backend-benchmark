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
import 'short_answer.dart';

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
            // Focus moves to the profile's name, not back into the search
            // field, so a phone keyboard does not cover the profile.
            nav.open(key);
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
          const SizedBox(height: 20),
          // Every framework, grouped under its language.
          for (final (lang, group) in byLanguage(run.backends)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                languageLabel(lang),
                style: t.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final x in group)
                  NameChip(
                    label: x.name,
                    leading: LangBadge.of(x.key, x.language),
                    onTap: () => nav.open(x.key),
                  ),
              ],
            ),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _Profile(state: state, run: run, backend: b),
          ),
      ],
    );
  }
}

/// Frameworks grouped by language (languages by name, frameworks by name
/// in each), for pickers that show the hierarchy.
List<(String, List<BackendResult>)> byLanguage(List<BackendResult> all) {
  final groups = <String, List<BackendResult>>{};
  for (final b in all) {
    (groups[b.language] ??= []).add(b);
  }
  final langs = groups.keys.toList()
    ..sort((a, c) => languageLabel(a).compareTo(languageLabel(c)));
  return [
    for (final l in langs)
      (l, groups[l]!..sort((a, c) => a.name.compareTo(c.name))),
  ];
}

/// The design's select as a tree: each language a header with its badge,
/// its frameworks under it. Typing narrows the list (name, language or
/// runtime) and keeps the headers of what matches. Enter picks the first
/// match.
/// Header entries' values: never a framework key.
const _header = '__language__';

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
              final hit = {
                for (final b in backends)
                  if (b.matches(q)) b.key,
              };
              final langs = {
                for (final b in backends)
                  if (hit.contains(b.key)) b.language,
              };
              return [
                for (final e in entries)
                  if (hit.contains(e.value) ||
                      (e.value.startsWith(_header) &&
                          langs.contains(e.value.substring(_header.length))))
                    e,
              ];
            },
            // A search's first framework, never a header, is what Enter picks.
            searchCallback: (entries, query) {
              final q = query.trim();
              if (q.isEmpty || q == selected?.name) return null;
              final i = entries.indexWhere(
                (e) => e.enabled && !e.value.startsWith(_header),
              );
              return i < 0 ? null : i;
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
            leadingIcon: selected == null
                ? const Icon(Icons.search)
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: LangBadge.of(selected!.key, selected!.language),
                  ),
            dropdownMenuEntries: [
              for (final (lang, group) in byLanguage(backends)) ...[
                DropdownMenuEntry(
                  value: '$_header$lang',
                  label: languageLabel(lang),
                  enabled: false,
                  leadingIcon: LangBadge.of(group.first.key, lang, size: 20),
                  style: MenuItemButton.styleFrom(
                    disabledForegroundColor: p.muted,
                    textStyle: t.small.copyWith(fontWeight: FontWeight.w700),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                for (final b in group)
                  DropdownMenuEntry(
                    value: b.key,
                    label: b.name,
                    leadingIcon: Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: LangBadge.of(b.key, b.language, size: 20),
                    ),
                    style: MenuItemButton.styleFrom(
                      foregroundColor: p.text,
                      textStyle: t.body,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
              ],
            ],
            onSelected: (key) {
              if (key == null || key.startsWith(_header)) return;
              if (key != selected?.key) onSelected(key);
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
      ?b.versionLine,
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
            child: Row(
              children: [
                LangBadge.of(b.key, b.language, size: 32),
                const SizedBox(width: 10),
                Flexible(child: Text(b.name, style: t.h2)),
              ],
            ),
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
        Fold(
          key: ValueKey('extra-${run.id}-${b.key}'),
          title: 'Reply times, processor and memory',
          topLine: true,
          child: _ExtraTable(
            backend: b,
            tests: tests,
            cores: cores,
            legacy: run.isLegacy,
          ),
        ),
        Fold(
          key: ValueKey('charts-${run.id}-${b.key}'),
          title: 'Charts from the test',
          subtitle: run.isLegacy
              ? 'Reply times, processor and memory over time, how it is '
                    'built, and its history.'
              : 'Every step of the load, reply times, processor and '
                    'memory over time, how it is built, and its history.',
          child: FrameworkCharts(backend: b),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            CalmButton(
              label: "See who's fastest",
              onTap: () => nav.go(HomeView.short),
            ),
            CalmButton(
              label: 'See all results',
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
        CopyLink(
          link: () => '${Uri.base.removeFragment()}#${locationOf(state)}',
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

/// One test of the profile: its name, where it placed in words, and its bar
/// next to the fastest (or the runner-up when it is the fastest). Tapping a
/// bar opens its number, runs and close calls, as on Who's fastest.
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
    final nav = HomeNav.of(context);
    final all = sortResults(resultsFor(run, test));
    final r = all.where((x) => x.key == backend.key).firstOrNull;
    if (r == null) return const SizedBox.shrink();
    // Fastest by the same rule as Who's fastest: a tie at the top (overlapping
    // runs, or several at our testing tool's limit) counts as fastest.
    final top = topGroup(all);
    final fastest = top.any((x) => x.key == r.key);
    final others = all.where((x) => x.key != r.key);
    final pair = [
      if (fastest) ...[r, ?others.firstOrNull] else ...[all.first, r],
    ];
    // Its place: frameworks with the same number share one.
    final place = 1 + all.where((x) => x.value > r.value).length;
    final placeText = fastest
        ? (top.length < 2 ? 'Fastest' : 'Tied fastest')
        : '${ordinal(place)} of ${all.length}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: TestHeading(
                  id: test,
                  style: t.h3,
                  noDatabase: backend.db == 'none',
                ),
              ),
              const SizedBox(width: 8),
              // Its place in this test, at a glance.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: fastest ? p.accentSoft : p.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: fastest ? p.accent : p.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (fastest) ...[
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 15,
                        color: p.accent,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      placeText,
                      style: t.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SpeedBars(
            key: ValueKey('profile-bars-${run.id}-${backend.key}-$test'),
            test: test,
            results: pair,
            all: all,
            unit: unit,
            mine: backend.key,
            onOpen: nav.open,
            page: backend.key,
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
  final bool legacy;

  const _ExtraTable({
    required this.backend,
    required this.tests,
    required this.cores,
    required this.legacy,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final cell = t.body.copyWith(
      fontSize: 14.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // Phones: a smaller header and a narrower first column, so a heading
    // like "Processor" never breaks mid-word.
    final narrow = MediaQuery.sizeOf(context).width < 480;
    final head = cell.copyWith(
      color: p.muted,
      height: 1.2,
      fontSize: narrow ? 12.5 : null,
    );
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
          columnWidths: {0: FlexColumnWidth(narrow ? 1.1 : 1.4)},
          defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
          children: [
            TableRow(
              children: [
                c('Test', head, left: true),
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
          legacy
              ? 'All of these were measured during the old test, which sent '
                    'the same traffic to every framework.'
              : 'All of these were measured at its result: the busiest step '
                    'it passed (tap its bar above for that number).',
          'Typical reply: ${Measure.typical.meaning}.',
          'Slow reply: ${Measure.slow.meaning}.',
          'Processor: how much of its ${numberWord(cores)} processor '
              '${cores == 1 ? 'core' : 'cores'} the framework used.',
          '"ms" means milliseconds. 1,000 ms is one second.',
          if (tests.any(
            (test) => measures.any(
              (m) =>
                  m.value(backend.scenarios[test]!, Metrics.sustainable) ==
                  null,
            ),
          ))
            'A dash means it was not measured.',
        ]),
      ],
    );
  }
}
