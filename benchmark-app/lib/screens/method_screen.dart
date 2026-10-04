import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/common.dart';
import '../widgets/implementation.dart';

/// What is measured, how, and what the flags mean. Everything the other
/// tabs only hint at in tooltips, in one scannable place.
class MethodScreen extends StatelessWidget {
  const MethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null) return const SizedBox.shrink();
    return PageBody(
      children: [
        _whatIsMeasured(run),
        _scenarios(run),
        _fairness(run),
        _thisRun(run),
        _flags(),
        _glossary(run),
      ],
    );
  }

  Widget _whatIsMeasured(RunSummary run) {
    if (run.isLegacy) {
      return const SectionCard(
        title: 'What is measured (v1 method, no longer used)',
        child: _Bullets([
          'Locust ramped up to 10,000 simulated users over 120 s and the '
              'average requests per second was recorded.',
          'Each app had one CPU and one run; there was no latency limit, so a '
              'framework could "win" with very slow responses.',
          'These numbers are kept for history only and are not comparable '
              'with the current method.',
        ]),
      );
    }
    final slo = run.params['slo'] as Map? ?? const {};
    final p99 = slo['p99_ms'] ?? 100;
    final err = ((slo['error_rate'] ?? 0.01) as num) * 100;
    final served = ((slo['achieved_ratio'] ?? 0.95) as num) * 100;
    return SectionCard(
      title: 'What is measured',
      child: _Bullets([
        'The load generator (k6) sends requests at a fixed rate, in steps '
            '(${_steps(run)}), ${run.params['step_seconds'] ?? 30} s each, '
            'after a ${run.params['warmup_seconds'] ?? 30} s warmup that is '
            'discarded.',
        'A step passes when p99 latency stays under ${_num(p99)} ms, fewer than '
            '${_num(err)}% of requests fail and at least ${_num(served)}% of '
            'the requested rate is actually served.',
        'Sustainable load (the headline) is the highest passing step; the run '
            'stops at the first failing step and then ${_refine(run)}. '
            'Peak throughput is the most requests per second served at any '
            'step, whatever the latency.',
        'Latency percentiles, CPU and memory are reported at the sustainable '
            'step. Every scenario is repeated ${run.params['reps'] ?? 3} '
            'times; the median is shown and the min–max is kept.',
      ]),
    );
  }

  String _steps(RunSummary run) {
    final steps = run.params['steps'];
    if (steps is! List || steps.isEmpty) return '250 to 64,000 req/s';
    return '${_num(steps.first)} to ${_num(steps.last)} req/s';
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

  Widget _scenarios(RunSummary run) => SectionCard(
    title: 'Scenarios',
    subtitle:
        'Pick one in the header; every number on the other tabs is '
        'for that scenario.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in run.scenarios)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    scenarioLabel(s),
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: factText(scenarioHelp(s))),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _fairness(RunSummary run) {
    if (run.isLegacy) return const SizedBox.shrink();
    final cpusets = run.params['cpusets'] as Map? ?? const {};
    final mem = run.params['memory'] as Map? ?? const {};
    return SectionCard(
      title: 'Fairness rules',
      subtitle:
          'The same for every backend. The Framework tab shows how each '
          'one uses them.',
      child: _Bullets([
        'Each app runs alone in a container pinned to '
            '${_cores(cpusets['app'])} CPU cores'
            '${mem['app'] != null ? ' with a ${mem['app']} memory limit' : ''}; '
            'Postgres has its own cores (${cpusets['db'] ?? 'separate'}), '
            'and so does the load generator (${cpusets['k6'] ?? 'separate'}).',
        'Apps run the way they would in production: release builds, '
            'production servers, one worker per core where the runtime is '
            'single-threaded, and about 20 database connections in total.',
        'Before DB scenarios the table is emptied and seeded with '
            '${_num(run.params['seed_rows'] ?? 10000)} rows through the '
            'app\'s own API. Reads use small offsets so Postgres is not the '
            'bottleneck.',
        'Backends whose native API is RPC (Serverpod, FOAM) are called '
            'through that API, with the same four operations.',
      ]),
    );
  }

  static String _cores(Object? cpuset) {
    if (cpuset is! String) return '2';
    final m = RegExp(r'^(\d+)-(\d+)$').firstMatch(cpuset);
    if (m == null) return cpuset;
    return '${int.parse(m[2]!) - int.parse(m[1]!) + 1}';
  }

  Widget _thisRun(RunSummary run) {
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
    return SectionCard(
      title: 'This run',
      subtitle:
          'Results are only comparable within one machine and method; '
          'the History tab never mixes them.',
      child: FactList(facts: facts, labelWidth: 110),
    );
  }

  Widget _flags() => SectionCard(
    title: 'Flags',
    subtitle: 'Small pills next to a framework name.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flagRow(
          const Flag(text: 'load-gen limit', tooltip: '', color: kBlue),
          'The load generator used most of its own CPU at the top steps. The '
          'real limit may be higher than measured on this machine.',
        ),
        _flagRow(
          const Flag(text: '±15%', tooltip: ''),
          'Repetitions differed by more than 10% on the headline number. '
          'Treat small differences with care.',
        ),
        _flagRow(
          const Flag(text: 'note', tooltip: '', color: kTextMuted),
          'The backend has a remark from its author, shown on its Framework '
          'page.',
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
    ),
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
    return SectionCard(
      title: 'Glossary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in metrics) _term(m.label, m.help),
          _term(
            'Requested vs served',
            'k6 asks for a fixed rate; "served" is what the app actually '
                'answered. Where the step chart leaves the dashed diagonal, '
                'the app stopped keeping up.',
          ),
          _term(
            'SLO',
            'Service level objective: the latency and error limits a step '
                'must meet to count as sustained.',
          ),
        ],
      ),
    );
  }

  Widget _term(String term, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: LayoutBuilder(
      builder: (context, c) {
        final label = Text(
          term,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        );
        if (c.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, factText(text)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 170, child: label),
            Expanded(child: factText(text)),
          ],
        );
      },
    ),
  );
}

class _Bullets extends StatelessWidget {
  final List<String> items;

  const _Bullets(this.items);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final s in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 10),
                child: ColorDot(color: kTextDim, size: 5),
              ),
              Expanded(child: factText(s)),
            ],
          ),
        ),
    ],
  );
}

/// How the run narrowed the limit after the first failing step.
String _refine(RunSummary run) {
  final steps = run.params['refine_steps'];
  final tol = run.params['refine_tolerance'];
  if (steps is num && tol is num) {
    return 'halves the gap to the last passing step up to ${steps.toInt()} '
        'times, until it is within ${(tol * 100).round()}%';
  }
  return 'tests the midpoint once';
}
