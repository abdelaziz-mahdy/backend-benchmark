import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/app_header.dart';
import '../widgets/common.dart';
import '../widgets/race_replay.dart' show Slo;
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

  /// One key per section id for the life of the page, so a rebuild keeps
  /// each section's state and "jump to" finds the section it asked for.
  static final _keys = Expando<Map<String, GlobalKey>>();
  final GlobalKey key;

  _Section._(this.id, this.title, this.summary, this.body, this.key);

  static _Section Function(String, String, String, Widget) forPage(
    Object page,
  ) {
    final keys = _keys[page] ??= {};
    return (id, title, summary, body) => _Section._(
      id,
      title,
      summary,
      body,
      keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'method-$id')),
    );
  }
}

class _MethodScreenState extends State<MethodScreen> {
  bool _contentsOpen = false;

  /// The definition and the scenarios are what most visitors came for, so
  /// they start open; the rest opens on demand.
  final Set<String> _open = {'sustainable', 'scenarios'};
  final _scroll = ScrollController();
  String? _active;
  List<_Section> _current = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_track);
  }

  @override
  void dispose() {
    _scroll.removeListener(_track);
    _scroll.dispose();
    super.dispose();
  }

  /// Highlights the section at the top of the view in the contents rail.
  void _track() {
    if (!_scroll.hasClients) return;
    String? active;
    for (final s in _current) {
      final ro = s.key.currentContext?.findRenderObject();
      if (ro == null || !ro.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(ro);
      if (viewport == null) continue;
      final top = viewport.getOffsetToReveal(ro, 0).offset;
      if (top <= _scroll.offset + 120) active = s.id;
    }
    if (active != _active) setState(() => _active = active);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null) return const SizedBox.shrink();
    final sections = _sections(state, run);
    _current = sections;
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 900;
        final pad = c.maxWidth < kNarrow ? 16.0 : 28.0;
        final title = PageTitle(
          eyebrow: 'Method',
          title: "How it's measured",
          subtitle: run.isLegacy
              ? 'An old run with the previous (v1) method'
              : 'The short version first; open any section for the details.',
          onBack: state.goHome,
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 18),
            if (!run.isLegacy) ...[
              _keyFacts(run),
              const SizedBox(height: 14),
              _RunStaircase(state: state),
            ],
            if (narrow) ...[
              const SizedBox(height: 12),
              _ContentsList(
                sections: sections,
                collapsible: true,
                open: _contentsOpen,
                active: _active ?? sections.firstOrNull?.id,
                onToggle: () => setState(() => _contentsOpen = !_contentsOpen),
                onJump: _jump,
              ),
            ],
            for (var i = 0; i < sections.length; i++) ...[
              const SizedBox(height: 10),
              KeyedSubtree(
                key: sections[i].key,
                child: _Collapsible(
                  number: i + 1,
                  title: sections[i].title,
                  summary: sections[i].summary,
                  open: _open.contains(sections[i].id),
                  onToggle: () => setState(() {
                    if (!_open.remove(sections[i].id)) {
                      _open.add(sections[i].id);
                    }
                  }),
                  child: sections[i].body,
                ),
              ),
            ],
          ],
        );
        final scroll = SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(pad, 20, narrow ? pad : 12, 32),
          child: content,
        );
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: kMaxContentWidth + pad * 2),
            child: narrow
                ? scroll
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: scroll),
                      // Outside the scroll view, so it stays put.
                      Padding(
                        padding: EdgeInsets.fromLTRB(12, 20, pad, 20),
                        child: SizedBox(
                          width: 220,
                          child: _ContentsList(
                            sections: sections,
                            collapsible: false,
                            open: true,
                            active: _active ?? sections.firstOrNull?.id,
                            onToggle: () {},
                            onJump: _jump,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
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

  List<_Section> _sections(DashboardState state, RunSummary run) {
    final section = _Section.forPage(this);
    return [
      if (run.isLegacy)
        section(
          'overview',
          'Overview',
          'Old method, kept for history; not comparable with current runs.',
          _overview(run),
        ),
      if (!run.isLegacy)
        section(
          'load',
          'How load is applied',
          'k6 raises the request rate step by step until the app falls behind.',
          _load(run),
        ),
      section(
        'sustainable',
        run.isLegacy
            ? 'What the v1 numbers are'
            : 'What "sustainable load" means',
        run.isLegacy
            ? 'Average requests per second during a user ramp.'
            : 'The highest rate held while staying fast and error-free.',
        _sustainable(run),
      ),
      section(
        'scenarios',
        'Scenarios',
        'Static JSON, database reads, inserts, and an 80/20 mix.',
        _scenarios(run),
      ),
      if (!run.isLegacy)
        section(
          'fairness',
          'Fairness rules',
          'Same cores, memory, seed data and pool size for every framework.',
          _fairness(run),
        ),
      section(
        'run',
        'Hardware and this run',
        '${run.machine.cpu} · ${run.date ?? 'undated'} · change the run here.',
        _thisRun(state, run),
      ),
      section(
        'flags',
        'Flags and marks',
        'What the capped, noisy and restarted markers mean.',
        _flags(),
      ),
      section(
        'glossary',
        'Glossary',
        'Every metric in one line.',
        _glossary(run),
      ),
      section(
        'limits',
        'Known limitations',
        'What these numbers cannot tell you.',
        _limits(run),
      ),
    ];
  }

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
          value: '${run.appCores} cores',
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
          'pinned to ${run.appCores} CPU cores, with Postgres and the load '
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
        '${run.appCores} pinned cores per app'
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
            'kept and marked noisy when they differ by more than 10%.',
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
        const MarkerIcon(Marker.capped, size: 16),
        'Capped by the load generator: k6 used most of its own CPU at the '
        'top steps, so the real limit may be higher than measured on this '
        'machine. Several frameworks tie at this cap in No DB.',
      ),
      _flagRow(
        const MarkerIcon(Marker.noisy, size: 16),
        'Noisy repetitions: they differed by more than 10% on the headline '
        'number. Treat small differences with care.',
      ),
      _flagRow(
        const MarkerIcon(Marker.restarted, size: 16),
        'Restarted under overload: the app stopped responding and did not '
        'recover by itself; the runner restarted it (keeping its data) and '
        'kept measuring. Says something about resilience, not just speed.',
      ),
      _flagRow(
        Text('—', style: mono(14, color: kTextDim)),
        'Not measured in that scenario.',
      ),
      _flagRow(
        const Flag(text: 'capped', icon: Icons.speed, tooltip: ''),
        'The same load-generator cap, as a label on the Details page.',
      ),
      _flagRow(
        const Flag(text: '±15%', icon: Icons.waves, tooltip: ''),
        'The same spread warning, with the measured spread.',
      ),
      _flagRow(
        const Flag(text: 'note', tooltip: '', color: kTextMuted),
        'The backend has a remark from its author; it is printed in full '
        'when the row is opened.',
      ),
      _flagRow(
        const Flag(text: 'modified', tooltip: ''),
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
          'machine, so the fastest frameworks tie in No DB (marked capped). '
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

/// Card with a big section number, a title and one-line summary; the
/// details open on tap.
class _Collapsible extends StatelessWidget {
  final int number;
  final String title;
  final String summary;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  const _Collapsible({
    required this.number,
    required this.title,
    required this.summary,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: motion(context, 200),
      decoration: BoxDecoration(
        color: open ? kCardBgRaised : kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: open ? kSignal.withValues(alpha: 0.35) : kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(kRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        number.toString().padLeft(2, '0'),
                        style: mono(
                          24,
                          weight: FontWeight.w700,
                          color: open ? kSignal : kTextDim,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: display(17)),
                          const SizedBox(height: 2),
                          Text(summary, style: body(12.5, color: kTextMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: motion(context, 200),
                      child: Icon(
                        Icons.expand_more,
                        color: kTextMuted,
                        semanticLabel: open ? 'Hide details' : 'Show details',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 0, 16, 18),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// Table of contents: a rail beside the page (desktop) that marks the
/// section in view, or a collapsible list at the top (phone). Entries open
/// their section and scroll to it.
class _ContentsList extends StatelessWidget {
  final List<_Section> sections;
  final bool collapsible;
  final bool open;
  final String? active;
  final VoidCallback onToggle;
  final ValueChanged<_Section> onJump;

  const _ContentsList({
    required this.sections,
    required this.collapsible,
    required this.open,
    required this.active,
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
                  Text('CONTENTS', style: caps(11, color: kTextSecondary)),
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
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('CONTENTS', style: caps(11, color: kTextSecondary)),
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (open)
            for (var i = 0; i < sections.length; i++)
              InkWell(
                onTap: () => onJump(sections[i]),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: active == sections[i].id ? kSignal : kBorder,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          (i + 1).toString().padLeft(2, '0'),
                          style: mono(11.5, color: kTextDim),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          sections[i].title,
                          style: body(
                            12.5,
                            color: active == sections[i].id
                                ? kSignal
                                : kTextSecondary,
                            weight: active == sections[i].id
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// "How a run works", drawn from one real result: every load step the
/// best framework of the ranked scenario ran (one the load generator did
/// not cap, when there is one), in order of rate. Each bar is what was
/// served on a log scale, under an outline of what was asked; lime steps
/// held the limits, red ones broke one, amber ones failed because the load
/// generator itself was the limit. The flag marks the sustainable step.
class _RunStaircase extends StatelessWidget {
  final DashboardState state;

  const _RunStaircase({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state.sortScenario ?? state.scenario;
    if (s == null) return const SizedBox.shrink();
    final ranked = state
        .rank(state.backendsIn(s), Metrics.sustainable, s)
        .where((b) => (b.scenarios[s]?.steps.length ?? 0) > 1)
        .toList();
    if (ranked.isEmpty) return const SizedBox.shrink();
    // An example the load generator capped would show its failures as the
    // app's; prefer the best uncapped one.
    final b = ranked.firstWhere(
      (x) => !x.scenarios[s]!.loadgenBound,
      orElse: () => ranked.first,
    );
    final r = b.scenarios[s]!;
    final steps = [...r.steps]
      ..sort((a, c) => a.targetRps.compareTo(c.targetRps));
    final slo = Slo.of(state.run!.params);
    final base = steps.first.targetRps;
    final top = steps
        .map((x) => math.max(x.targetRps, x.achievedRps))
        .reduce(math.max);
    double h(double rps) => rps <= 0
        ? 0
        : (math.log(math.max(rps, base) / base) / math.log(top / base)).clamp(
            0.0,
            1.0,
          );
    final lastPass = steps.lastIndexWhere((x) => x.pass);
    final firstFail = steps.indexWhere((x) => !x.pass);
    final sustainable = Metrics.sustainable.value(r);
    final pick = b == ranked.first
        ? 'the leader'
        : 'the best framework the load generator did not cap';
    final ticks = [
      for (var p = 1000.0; p <= top; p *= 10)
        if (p > base) p,
    ];
    const barArea = 150.0;
    Color tone(LoadStep x) => x.pass
        ? kSignal
        : x.k6Bound
        ? kAmber
        : kRedline;
    return SectionCard(
      eyebrow: 'How a run works',
      title: 'One real run, step by step',
      subtitle:
          'Every load step ${b.name} ($pick) ran in ${scenarioLabel(s)}, '
          'from its median repetition, in order of rate. A bar is what was '
          'served (log scale); the outline is what was asked. Lime steps '
          'held p99 < ${formatMs(slo.p99Ms)} with < '
          '${(slo.errorRate * 100).toStringAsFixed(0)}% errors; red ones '
          'broke a limit; amber ones failed because the load generator was '
          'the limit. Narrow bars are probes between the last pass and the '
          'first fail. The flag is the sustainable load'
          '${sustainable == null ? '' : ' (median of the repetitions: ${formatMetric(Metrics.sustainable, sustainable)})'}.',
      child: LayoutBuilder(
        builder: (context, c) {
          const axis = 38.0;
          final width = c.maxWidth - axis;
          final gap = width < 500 ? 3.0 : 6.0;
          final barW = (width - gap * (steps.length - 1)) / steps.length;
          final labelEvery = barW < 30 ? 2 : 1;
          final wide = barW >= 64;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: barArea + 24 + (wide ? 30 : 0) + 20,
                child: Stack(
                  children: [
                    // Log gridlines with their rates.
                    for (final t in ticks)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 26 + (wide ? 30 : 0) + barArea * h(t) - 7,
                        child: Row(
                          children: [
                            SizedBox(
                              width: axis,
                              child: Text(
                                compactRps(t),
                                style: mono(10.5, color: kTextMuted),
                              ),
                            ),
                            Expanded(
                              child: Container(height: 1, color: kGridLine),
                            ),
                          ],
                        ),
                      ),
                    Positioned.fill(
                      left: axis,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < steps.length; i++) ...[
                            if (i > 0) SizedBox(width: gap),
                            SizedBox(
                              width: barW,
                              child: _StepBar(
                                step: steps[i],
                                index: i,
                                held: i == lastPass,
                                served: barArea * h(steps[i].achievedRps),
                                asked: barArea * h(steps[i].targetRps),
                                color: tone(steps[i]),
                                reason: wide
                                    ? (i == lastPass
                                          ? 'p99 ${formatMs(steps[i].p99)} · held'
                                          : slo.reason(steps[i]))
                                    : null,
                                showRate: i % labelEvery == 0 || i == lastPass,
                                slo: slo,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    if (lastPass >= 0)
                      TextSpan(
                        text:
                            'Held ${compactRps(steps[lastPass].targetRps)} '
                            'with p99 ${formatMs(steps[lastPass].p99)}. ',
                        style: body(12.5, color: kSignal),
                      ),
                    if (firstFail >= 0)
                      TextSpan(
                        text:
                            'First failure at '
                            '${compactRps(steps[firstFail].targetRps)}: '
                            '${slo.reason(steps[firstFail])}.',
                        style: body(
                          12.5,
                          color: steps[firstFail].k6Bound ? kAmber : kRedline,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final LoadStep step;
  final int index;
  final bool held;
  final double served;
  final double asked;
  final Color color;
  final String? reason;
  final bool showRate;
  final Slo slo;

  const _StepBar({
    required this.step,
    required this.index,
    required this.held,
    required this.served,
    required this.asked,
    required this.color,
    required this.reason,
    required this.showRate,
    required this.slo,
  });

  @override
  Widget build(BuildContext context) {
    final i = index;
    final probe = step.refine;
    final why = slo.reason(step);
    return Tooltip(
      message:
          '${formatRps(step.targetRps)} req/s asked · served '
          '${formatRps(step.achievedRps)} · p99 ${formatMs(step.p99)} · '
          'errors ${(step.errorRate * 100).toStringAsFixed(2)}%'
          '${probe ? ' · probe step' : ''}'
          '${why.isEmpty ? ' · held' : ' · failed: $why'}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (held)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(
                Icons.flag,
                size: 16,
                color: kSignal,
                semanticLabel: 'Highest step held',
              ),
            ),
          FractionallySizedBox(
            widthFactor: probe ? 0.62 : 1,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: motion(context, 360 + i * 45),
              curve: Interval(
                i * 45 / (360 + i * 45),
                1,
                curve: Curves.easeOutCubic,
              ),
              builder: (context, t, _) => SizedBox(
                height: 6 + asked * t,
                child: Stack(
                  children: [
                    // What was asked: an outline cap.
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          border: Border.all(
                            color: color.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                    // What was served.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: (6 + served * t).clamp(0, 6 + asked * t),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: step.pass ? (held ? 0.95 : 0.45) : 0.4,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: showRate
                ? FittedBox(
                    child: Text(
                      compactRps(step.targetRps),
                      style: mono(
                        10.5,
                        color: held ? kSignal : kTextMuted,
                        weight: held ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  )
                : null,
          ),
          if (reason != null)
            SizedBox(
              height: 30,
              child: Text(
                reason!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mono(10, color: color, height: 1.25),
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
                      color: e.kind == RunKind.latest ? kSignal : kTextMuted,
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
