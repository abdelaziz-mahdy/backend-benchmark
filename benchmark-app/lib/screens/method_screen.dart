import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/app_header.dart';
import '../widgets/common.dart';
import '../widgets/implementation.dart';

/// How the numbers are made. Four key facts up front; every section shows a
/// one-line summary and opens its details on tap, so the page reads in
/// seconds and the rest is there for the curious. Also where the run shown
/// in the dashboard is changed.
class MethodScreen extends StatefulWidget {
  const MethodScreen({super.key});

  @override
  State<MethodScreen> createState() => _MethodScreenState();
}

class _Section {
  final String id;
  final String title;
  final String summary;
  final Widget body;
  final GlobalKey key = GlobalKey();

  _Section(this.id, this.title, this.summary, this.body);
}

class _MethodScreenState extends State<MethodScreen> {
  bool _contentsOpen = false;
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null) return const SizedBox.shrink();
    final sections = _sections(state, run);
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 900;
        final pad = c.maxWidth < kNarrow ? 12.0 : 24.0;
        final title = PageTitle(
          title: "How it's measured",
          subtitle: run.isLegacy
              ? 'An old run with the previous (v1) method'
              : 'The short version first; tap a section for details',
          onBack: state.goHome,
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!run.isLegacy) _keyFacts(run),
            if (narrow) ...[
              const SizedBox(height: 12),
              _ContentsList(
                sections: sections,
                collapsible: true,
                open: _contentsOpen,
                onToggle: () => setState(() => _contentsOpen = !_contentsOpen),
                onJump: _jump,
              ),
            ],
            for (final s in sections) ...[
              const SizedBox(height: 10),
              KeyedSubtree(
                key: s.key,
                child: _Collapsible(
                  title: s.title,
                  summary: s.summary,
                  open: _open.contains(s.id),
                  onToggle: () => setState(() {
                    if (!_open.remove(s.id)) _open.add(s.id);
                  }),
                  child: s.body,
                ),
              ),
            ],
          ],
        );
        final scroll = SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [title, const SizedBox(height: 12), content],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title spans both columns so the contents box lines
                        // up with the first card.
                        title,
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: content),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 200,
                              child: _ContentsList(
                                sections: sections,
                                collapsible: false,
                                open: true,
                                onToggle: () {},
                                onJump: _jump,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
        return scroll;
      },
    );
  }

  /// Opens the section, then scrolls to it.
  void _jump(_Section s) {
    setState(() => _open.add(s.id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(s));
  }

  void _scrollTo(_Section s) {
    final ctx = s.key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0.02,
    );
  }

  List<_Section> _sections(DashboardState state, RunSummary run) => [
    if (run.isLegacy)
      _Section(
        'overview',
        'Overview',
        'Old method, kept for history; not comparable with current runs.',
        _overview(run),
      ),
    if (!run.isLegacy)
      _Section(
        'load',
        'How load is applied',
        'k6 raises the request rate step by step until the app falls behind.',
        _load(run),
      ),
    _Section(
      'sustainable',
      run.isLegacy
          ? 'What the v1 numbers are'
          : 'What "sustainable load" means',
      run.isLegacy
          ? 'Average requests per second during a user ramp.'
          : 'The highest rate held while staying fast and error-free.',
      _sustainable(run),
    ),
    _Section(
      'scenarios',
      'Scenarios',
      'Static JSON, database reads, inserts, and an 80/20 mix.',
      _scenarios(run),
    ),
    if (!run.isLegacy)
      _Section(
        'fairness',
        'Fairness rules',
        'Same cores, memory, seed data and pool size for every framework.',
        _fairness(run),
      ),
    _Section(
      'run',
      'Hardware and this run',
      '${run.machine.cpu} · ${run.date ?? 'undated'} · change the run here.',
      _thisRun(state, run),
    ),
    _Section(
      'flags',
      'Flags and marks',
      'What † (load-generator limit), ± (noisy repetitions) and ‡ (restarted) mean.',
      _flags(),
    ),
    _Section(
      'glossary',
      'Glossary',
      'Every metric in one line.',
      _glossary(run),
    ),
    _Section(
      'limits',
      'Known limitations',
      'What these numbers cannot tell you.',
      _limits(run),
    ),
  ];

  /// Four facts that answer "how was this measured?" at a glance.
  Widget _keyFacts(RunSummary run) {
    final slo = (run.params['slo'] as Map?) ?? const {};
    final reps = run.params['reps'] ?? 3;
    final steps = (run.params['steps'] as List?)?.whereType<num>().toList();
    final range = steps == null || steps.isEmpty
        ? 'from 250 req/s'
        : '${_k(steps.first)} to ${_k(steps.last)} req/s';
    return TileGrid(
      minTileWidth: 165,
      children: [
        StatTile(
          label: 'Each app gets',
          value: '${_cores(run)} cores',
          detail: 'pinned, nothing else on them',
        ),
        StatTile(
          label: 'Passing means',
          value: 'p99 < ${_num(slo['p99_ms'] ?? 100)} ms',
          detail:
              'and < ${_num(((slo['error_rate'] ?? 0.01) as num) * 100)}% errors',
        ),
        StatTile(label: 'Load', value: 'stepped up', detail: range),
        StatTile(
          label: 'Every result is',
          value: 'median of $reps',
          detail: 'repetitions per scenario',
        ),
      ],
    );
  }

  // ------------------------------------------------------------ sections

  Widget _overview(RunSummary run) => _Para([
    if (run.isLegacy)
      'This is an old run with the v1 method: Locust ramped up to 10,000 '
          'simulated users and the average requests per second was '
          'recorded. There was no latency limit. These numbers are kept for '
          'history and are not comparable with the current method.'
    else ...[
      'Every framework serves the same four scenarios from a container '
          'pinned to ${_cores(run)} CPU cores, with Postgres and the load '
          'generator on their own cores.',
      'The load generator raises the request rate step by step. The '
          'headline number, sustainable load, is the highest rate a '
          'framework held while staying fast and error-free.',
      'Each scenario is repeated ${run.params['reps'] ?? 3} times; the '
          'dashboard shows the median and keeps the min–max.',
    ],
  ]);

  Widget _load(RunSummary run) {
    final refine = run.params['refine_steps'];
    final refineText = switch (refine) {
      null || 1 =>
        'tests the midpoint between the last passing and the first failing '
            'step',
      0 => 'stops there',
      _ =>
        'halves the gap between the last passing and the first failing '
            'step up to $refine times, stopping once it is within '
            '${((run.params['refine_tolerance'] as num? ?? 0.06) * 100).round()}%',
    };
    return _Facts([
      ('Load generator', 'k6, fixed request rate per step (open model)'),
      ('Steps', _steps(run)),
      ('Step length', '${run.params['step_seconds'] ?? 30} s'),
      (
        'Warmup',
        '${run.params['warmup_seconds'] ?? 30} s before the first step, '
            'discarded',
      ),
      (
        'Stop rule',
        'The run stops at the first step that misses the limits, then '
            '$refineText. After every failing step it waits until the app '
            'answers quickly again, so a backlog from the overload does not '
            'spoil the next step.',
      ),
    ]);
  }

  Widget _sustainable(RunSummary run) {
    if (run.isLegacy) {
      return _Para(const [
        'Average throughput: mean requests per second during the ramp.',
        'Latency, CPU and memory are averages over the whole run.',
        'One run, one CPU per app, no latency or error limit.',
      ]);
    }
    final slo = run.params['slo'] as Map? ?? const {};
    final p99 = slo['p99_ms'] ?? 100;
    final err = ((slo['error_rate'] ?? 0.01) as num) * 100;
    final served = ((slo['achieved_ratio'] ?? 0.95) as num) * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Para(const [
          'A step passes when all three limits hold. Sustainable load is '
              'the highest passing step.',
        ]),
        const SizedBox(height: 8),
        _Facts([
          ('p99 latency', 'under ${_num(p99)} ms'),
          ('Errors', 'fewer than ${_num(err)}% of requests'),
          ('Served', 'at least ${_num(served)}% of the requested rate'),
          (
            'Also reported',
            'Peak throughput (most requests per second at any step, whatever '
                'the latency); latency percentiles, CPU and memory at the '
                'sustainable step.',
          ),
        ]),
      ],
    );
  }

  Widget _scenarios(RunSummary run) => _Facts([
    for (final s in run.scenarios) (scenarioLabel(s), scenarioHelp(s)),
  ]);

  Widget _fairness(RunSummary run) {
    final cpusets = run.params['cpusets'] as Map? ?? const {};
    final mem = run.params['memory'] as Map? ?? const {};
    return _Facts([
      (
        'CPU',
        '${_cores(run)} pinned cores per app'
            '${mem['app'] != null ? ', ${mem['app']} memory limit' : ''}; '
            'Postgres on cores ${cpusets['db'] ?? 'of its own'}, k6 on '
            '${cpusets['k6'] ?? 'its own'}.',
      ),
      (
        'Configuration',
        'Production mode, release builds, one worker per core where the '
            'runtime is single-threaded, about 20 database connections in '
            'total.',
      ),
      (
        'Data',
        'Before DB scenarios the table is emptied and seeded with '
            '${_num(run.params['seed_rows'] ?? 10000)} rows through the '
            'app\'s own API. Reads use small offsets so Postgres is not the '
            'bottleneck.',
      ),
      (
        'RPC backends',
        'Serverpod and FOAM are called through their native API with the '
            'same four operations.',
      ),
      (
        'Repetitions',
        '${run.params['reps'] ?? 3} per scenario; median shown, min–max '
            'kept and shown as ± when they differ by more than 10%.',
      ),
    ]);
  }

  Widget _thisRun(DashboardState state, RunSummary run) {
    final images = run.params['images'] as Map? ?? const {};
    final facts = <(String, Widget)>[
      ('Run', factText(run.id)),
      if (run.date != null) ('Date', factText(run.date!)),
      ('Machine', factText(run.machine.label)),
      if (run.docker['cpus'] != null)
        (
          'Docker VM',
          factText(
            '${run.docker['cpus']} CPUs · ${run.docker['mem_gb'] ?? '?'} GB'
            '${run.docker['version'] != null ? ' · Docker ${run.docker['version']}' : ''}',
          ),
        ),
      ('Method', factText(run.isLegacy ? 'v1 (Locust)' : run.methodology)),
      if (run.contributor != null) ('Contributor', factText(run.contributor!)),
      for (final e in images.entries) (e.key, factText('${e.value}')),
      if (run.gitSha != null)
        (
          'Code',
          run.dirty
              ? factText(
                  '${run.gitSha} with uncommitted changes (see the '
                  '"modified code" flag)',
                )
              : SourceLink(
                  url: '$kRepoUrl/tree/${run.gitSha}',
                  label: 'commit ${run.gitSha}',
                ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Results are only comparable within one machine and one method. '
          'Pick which run the dashboard shows:',
          style: TextStyle(color: kTextSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        RunPicker(state: state),
        const SizedBox(height: 14),
        FactList(facts: facts, labelWidth: 110),
      ],
    );
  }

  Widget _flags() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _flagRow(
        const Text('†', style: TextStyle(color: kBlue, fontSize: 14)),
        'Load-generator limit: k6 used most of its own CPU at the top '
        'steps, so the real limit may be higher than measured on this '
        'machine. Several frameworks tie at this cap in No DB.',
      ),
      _flagRow(
        const Text('±', style: TextStyle(color: kBlue, fontSize: 14)),
        'Repetitions differed by more than 10% on the headline number. '
        'Treat small differences with care.',
      ),
      _flagRow(
        const Text('‡', style: TextStyle(color: kBlue, fontSize: 14)),
        'Stopped responding under overload and did not recover by itself; '
        'the runner restarted it (keeping its data) and kept measuring. '
        'Says something about resilience, not just speed.',
      ),
      _flagRow(
        const Flag(text: 'load-gen limit', tooltip: '', color: kBlue),
        'The same load-generator limit, as shown on the Details page.',
      ),
      _flagRow(
        const Flag(text: '±15%', tooltip: ''),
        'The same spread warning, with the measured spread.',
      ),
      _flagRow(
        const Flag(text: 'note', tooltip: '', color: kTextMuted),
        'The backend has a remark from its author; it is printed in full '
        'when the row is opened.',
      ),
      _flagRow(
        const Flag(text: 'modified code', tooltip: ''),
        'The run was made from a working copy with uncommitted changes, so '
        'the linked commit is not exactly what ran.',
      ),
      _flagRow(
        const Flag(text: 'v1 method', tooltip: ''),
        'An old run with the previous method. Not comparable with v2.',
      ),
    ],
  );

  Widget _flagRow(Widget flag, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Align(alignment: Alignment.centerLeft, child: flag),
        ),
        Expanded(child: factText(text)),
      ],
    ),
  );

  Widget _glossary(RunSummary run) {
    final results = [for (final b in run.backends) ...b.scenarios.values];
    final metrics = Metrics.available(results, Metrics.all);
    return _Facts([
      for (final m in metrics) (m.label, m.help),
      (
        'Requested vs served',
        'k6 asks for a fixed rate; "served" is what the app actually '
            'answered. Where the step chart leaves the dashed diagonal, the '
            'app stopped keeping up.',
      ),
      (
        'SLO',
        'Service level objective: the latency and error limits a step must '
            'meet to count as sustained.',
      ),
      (
        'Rank, share of the best',
        'Position among every framework measured in that scenario; equal '
            'values share a position. The share is this value divided by the '
            'best one.',
      ),
    ]);
  }

  Widget _limits(RunSummary run) => _Para([
    if (!run.isLegacy)
      'The load generator caps out around 48k requests per second on this '
          'machine, so the fastest frameworks tie in No DB (marked †). '
          'Their real limit is higher.',
    'One machine, one Docker VM: absolute numbers are specific to it. Only '
        'runs on the same machine with the same method are comparable, which '
        'is why History never mixes them.',
    'Storage variants of one framework (such as FOAM3 embedded vs '
        'Postgres) only separate where storage is the bottleneck; where the '
        "framework's request handling is the limit they show similar numbers.",
    'p99 is taken at each framework\'s own sustainable load: a slower '
        'framework can show a lower p99 simply by serving less traffic.',
    'Implementation details for runs made before the field existed come '
        'from the current source, not from the run; the dashboard says so '
        'where it applies.',
  ]);

  // -------------------------------------------------------------- helpers

  String _steps(RunSummary run) {
    final steps = run.params['steps'];
    if (steps is! List || steps.isEmpty) return '250 to 64,000 req/s';
    return '${steps.length} steps, ${_num(steps.first)} to '
        '${_num(steps.last)} req/s, doubling each time';
  }

  /// 64000 -> "64k", 250 -> "250".
  static String _k(num v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
      : '${v.toInt()}';

  static String _cores(RunSummary run) {
    final cpusets = run.params['cpusets'] as Map? ?? const {};
    final cpuset = cpusets['app'];
    if (cpuset is! String) return '2';
    final m = RegExp(r'^(\d+)-(\d+)$').firstMatch(cpuset);
    if (m == null) return cpuset;
    return '${int.parse(m[2]!) - int.parse(m[1]!) + 1}';
  }

  static String _num(Object? v) {
    if (v is! num) return '$v';
    if (v == v.roundToDouble()) {
      final s = v.toInt().toString();
      return s.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
    }
    return v.toString();
  }
}

/// Table of contents: a quiet list on the side (desktop) or a collapsible
/// list at the top (phone). Entries scroll to their section.
/// Card with a title and one-line summary; the details open on tap.
class _Collapsible extends StatelessWidget {
  final String title;
  final String summary;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  const _Collapsible({
    required this.title,
    required this.summary,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: open ? kBlue.withValues(alpha: 0.4) : kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(kRadius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: const TextStyle(
                            color: kTextMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: kTextMuted,
                    semanticLabel: open ? 'Hide details' : 'Show details',
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _ContentsList extends StatelessWidget {
  final List<_Section> sections;
  final bool collapsible;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<_Section> onJump;

  const _ContentsList({
    required this.sections,
    required this.collapsible,
    required this.open,
    required this.onToggle,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final header = collapsible
        ? InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Text(
                    'Contents',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: kTextMuted,
                  ),
                ],
              ),
            ),
          )
        : const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Contents',
              style: TextStyle(
                color: kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (open)
            for (var i = 0; i < sections.length; i++)
              InkWell(
                onTap: () => onJump(sections[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${i + 1}. ${sections[i].title}',
                    style: const TextStyle(color: kBlue, fontSize: 12.5),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Short paragraphs, one per item.
class _Para extends StatelessWidget {
  final List<String> items;

  const _Para(this.items);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
          child: Text(
            items[i],
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
    ],
  );
}

/// Small label/value table.
class _Facts extends StatelessWidget {
  final List<(String, String)> rows;

  const _Facts(this.rows);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final stacked = c.maxWidth < 480;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, text) in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kGridLine)),
              ),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_label(label), factText(text)],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 150, child: _label(label)),
                        Expanded(child: factText(text)),
                      ],
                    ),
            ),
        ],
      );
    },
  );

  Widget _label(String s) => Text(
    s,
    style: const TextStyle(
      color: kTextPrimary,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Which run the dashboard shows. Lives on the Method page.
class RunPicker extends StatelessWidget {
  final DashboardState state;

  const RunPicker({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final selected = state.entry;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected?.id,
          isExpanded: true,
          isDense: true,
          dropdownColor: kCardBg,
          icon: const Icon(Icons.expand_more, color: kTextMuted, size: 20),
          style: labelStyle(context, 13, color: kTextPrimary),
          padding: const EdgeInsets.symmetric(vertical: 8),
          items: [
            for (final e in state.index)
              DropdownMenuItem(
                value: e.id,
                child: Row(
                  children: [
                    Icon(
                      switch (e.kind) {
                        RunKind.latest => Icons.auto_awesome,
                        RunKind.legacy => Icons.history,
                        RunKind.run => Icons.play_circle_outline,
                      },
                      size: 15,
                      color: e.kind == RunKind.latest ? kBlue : kTextMuted,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(runLabel(e), overflow: TextOverflow.ellipsis),
                    ),
                    if (e.dirty) ...[
                      const SizedBox(width: 6),
                      const Flag(
                        text: 'modified code',
                        tooltip:
                            'Run from a working copy with uncommitted changes.',
                      ),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (id) {
            final e = state.index.firstWhere((x) => x.id == id);
            state.selectRun(e);
          },
        ),
      ),
    );
  }
}
