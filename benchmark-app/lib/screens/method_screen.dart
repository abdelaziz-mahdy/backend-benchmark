import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/plain.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/calm.dart';
import '../widgets/common.dart';
import '../widgets/implementation.dart' show SourceLink;
import '../widgets/prose.dart';
import '../widgets/race_replay.dart' show Slo;
import '../widgets/run_switcher.dart';
import '../widgets/site_frame.dart' show SiteFooter, SiteWidth, kSiteWidth;

/// How the numbers are made. Four key facts up front, one real run drawn
/// step by step, then numbered sections that open on tap. Every section is
/// a one-line lead and short bullets, so it reads in pieces. Also where
/// the run shown on the site is changed.
class MethodScreen extends StatefulWidget {
  const MethodScreen({super.key});

  @override
  State<MethodScreen> createState() => _MethodScreenState();
}

class _Section {
  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final Widget body;

  /// One key per section id for the life of the page, so a rebuild keeps
  /// each section's state and "jump to" finds the section it asked for.
  static final _keys = Expando<Map<String, GlobalKey>>();
  final GlobalKey key;

  _Section._(this.id, this.title, this.summary, this.icon, this.body, this.key);

  static _Section Function(String, String, String, IconData, Widget) forPage(
    Object page,
  ) {
    final keys = _keys[page] ??= {};
    return (id, title, summary, icon, body) => _Section._(
      id,
      title,
      summary,
      icon,
      body,
      keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'method-$id')),
    );
  }
}

/// Width of the contents rail beside the page on wide screens.
const _railWidth = 220.0;
const _railGap = 28.0;

class _MethodScreenState extends State<MethodScreen> {
  bool _contentsOpen = false;

  /// What the result means and the tests are what most visitors came for,
  /// so they start open; the rest opens on demand.
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

  /// Highlights the section at the top of the view in the contents list.
  void _track() {
    if (!_scroll.hasClients || !mounted) return;
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
    // A run switch can drop the section that was active (the old method
    // has other sections); fall back to the first.
    final active = sections.any((s) => s.id == _active)
        ? _active
        : sections.firstOrNull?.id;
    return LayoutBuilder(
      builder: (context, c) {
        // The rail sits in the margin beside the site column, so the
        // content lines up with the header; without room it goes inline.
        final rail =
            c.maxWidth >= kSiteWidth + 40 + 2 * (_railWidth + _railGap);
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead(
              icon: Icons.science_outlined,
              title: "How it's measured",
              lead: run.isLegacy
                  ? 'This is an old run, made with an older method. Its '
                        'numbers cannot be compared with newer runs.'
                  : 'The short version first. Open any section below for '
                        'the details.',
              onBack: () => state.setPage(DashboardPage.home),
            ),
            if (!run.isLegacy) ...[
              const SizedBox(height: kSectionGap),
              _keyFacts(run),
              const SizedBox(height: kSectionGap),
              _RunStaircase(state: state),
            ],
            if (!rail) ...[
              const SizedBox(height: kSectionGap),
              _ContentsList(
                sections: sections,
                collapsible: true,
                open: _contentsOpen,
                active: active,
                onToggle: () => setState(() => _contentsOpen = !_contentsOpen),
                onJump: _jump,
              ),
            ],
            const SizedBox(height: kSectionGap),
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              KeyedSubtree(
                key: sections[i].key,
                child: _Collapsible(
                  number: i + 1,
                  icon: sections[i].icon,
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
        final page = SingleChildScrollView(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SiteWidth(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: content,
                ),
              ),
              const SiteFooter(),
            ],
          ),
        );
        if (!rail) return page;
        return Stack(
          children: [
            Positioned.fill(child: page),
            // Outside the scroll view, so it stays put.
            Positioned(
              top: 28,
              left: c.maxWidth / 2 + kSiteWidth / 2 + _railGap,
              width: _railWidth,
              child: _ContentsList(
                sections: sections,
                collapsible: false,
                open: true,
                active: active,
                onToggle: () {},
                onJump: _jump,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Opens the section, then scrolls to it.
  void _jump(_Section s) {
    setState(() => _open.add(s.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollTo(s);
    });
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
          'An old method, kept for history. Not comparable with newer runs.',
          Icons.history,
          _overview(run),
        ),
      if (!run.isLegacy)
        section(
          'load',
          'How the traffic is sent',
          'Our testing tool sends more and more requests until the app falls '
              'behind.',
          Icons.stairs_outlined,
          _load(run),
        ),
      section(
        'sustainable',
        run.isLegacy ? 'What the old numbers are' : 'What the result means',
        run.isLegacy
            ? 'The average requests a second while users were added.'
            : 'The busiest step it handled while replies stayed fast, few '
                  'failed and it kept up.',
        Icons.flag_outlined,
        _sustainable(run),
      ),
      section(
        'scenarios',
        'The tests',
        capFirst(
          joinAnd([for (final s in run.scenarios) testInfo(s).inSentence]),
        ),
        Icons.checklist,
        _scenarios(run),
      ),
      if (!run.isLegacy)
        section(
          'fairness',
          'Fairness rules',
          'Same processor, memory and data for every framework.',
          Icons.balance,
          _fairness(run),
        ),
      section(
        'run',
        'This run and the computer',
        '${run.machine.cpu} · ${_when(state)} · change the run here.',
        Icons.computer,
        _thisRun(state, run),
      ),
      section(
        'flags',
        'Marks next to results',
        'What the limit, noisy, restarted and other marks mean.',
        Icons.label_outline,
        _flags(),
      ),
      section(
        'glossary',
        'Words we use',
        'Every number explained in one line.',
        Icons.menu_book_outlined,
        _glossary(run),
      ),
      section(
        'limits',
        "What these numbers can't tell you",
        'Where to be careful when reading them.',
        Icons.warning_amber_outlined,
        _limits(run),
      ),
    ];
  }

  int _reps(RunSummary run) =>
      (run.params['reps'] is num) ? (run.params['reps'] as num).toInt() : 3;

  /// Four facts that answer "how was this measured?" at a glance.
  Widget _keyFacts(RunSummary run) {
    final slo = Slo.of(run.params);
    final reps = _reps(run);
    final cores = appCoreCount(run);
    final steps = (run.params['steps'] as List?)?.whereType<num>().toList();
    final range = steps == null || steps.isEmpty
        ? 'from 250 requests a second'
        : 'from ${whole(steps.first)} to ${whole(steps.last)} requests a '
              'second';
    return TileGrid(
      minTileWidth: 190,
      children: [
        FactCard(
          icon: Icons.memory,
          label: 'Each app gets',
          value: capFirst(
            '${numberWord(cores)} ${cores == 1 ? 'core' : 'cores'}',
          ),
          detail:
              'Processor cores kept for it alone. Nothing else runs on '
              'them.',
        ),
        FactCard(
          icon: Icons.check_circle_outline,
          label: 'To pass a step',
          value: 'Fast, few errors, keeping up',
          detail:
              '99 of every 100 replies within ${msText(slo.p99Ms)}, fewer '
              'than ${_pct(slo.errorRate)} errors, and at least '
              '${_pct(slo.servedRatio)} of requests answered.',
        ),
        FactCard(
          icon: Icons.stairs_outlined,
          label: 'The traffic',
          value: 'Steps up',
          detail: '${capFirst(range)}.',
        ),
        FactCard(
          icon: Icons.repeat,
          label: 'Every result is',
          value: 'Middle of $reps tries',
          detail: 'Every test is tried ${numberWord(reps)} times.',
        ),
      ],
    );
  }

  // ------------------------------------------------------------ sections

  Widget _overview(RunSummary run) {
    final users = run.params['users'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead('This run used our first, simpler method.'),
        const SizedBox(height: 14),
        Points([
          Point(
            'How:',
            'an older testing tool (Locust) added simulated users, up to '
                '${users is num ? whole(users) : '10,000'}, and recorded the '
                'average requests a second.',
          ),
          const Point('No limit', 'on how slow replies could get.'),
          const Point(
            'Kept for history.',
            'These numbers cannot be compared with the current method.',
          ),
        ]),
      ],
    );
  }

  Widget _load(RunSummary run) {
    final refine = run.params['refine_steps'];
    final tolerance = ((run.params['refine_tolerance'] as num? ?? 0.06) * 100)
        .round();
    final refineText = switch (refine) {
      null || 1 =>
        'it tries one extra step halfway between the last pass and the first '
            'fail.',
      0 => 'it stops there.',
      _ =>
        'it tries extra steps between the last pass and the first fail, '
            'halving the gap up to $refine times, until the two are within '
            '$tolerance% of each other.',
    };
    final seconds = run.params['step_seconds'] ?? 30;
    final warmup = run.params['warmup_seconds'] ?? 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead(
          'Our testing tool sends a fixed number of requests a second, then '
          'steps up.',
        ),
        const SizedBox(height: 14),
        Points([
          Point('Steps:', '${_steps(run)}.'),
          Point('Each step lasts', '$seconds seconds.'),
          Point(
            'Warm-up:',
            '$warmup seconds before the first step. Not counted.',
          ),
          const Point(
            'Steady rate:',
            'the tool keeps sending at the set rate even when replies are '
                'slow, the way real visitors keep arriving.',
          ),
          const Point(
            'Stop rule:',
            'the test stops at the first step that fails a limit.',
          ),
          Point('Extra steps:', 'after that, $refineText'),
          const Point(
            'Cool-down:',
            'after every failed step it waits until the app answers quickly '
                'again, so the backlog does not spoil the next step.',
          ),
        ]),
      ],
    );
  }

  Widget _sustainable(RunSummary run) {
    if (run.isLegacy) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Lead('The old method measured an average, with no limits.'),
          SizedBox(height: 14),
          Points([
            Point(
              'The result:',
              'the average requests a second while simulated users were '
                  'added.',
            ),
            Point(
              'Reply times, processor and memory',
              'are averages over the whole test.',
            ),
            Point(
              'One run,',
              'one processor core per app, and no limit on reply time or '
                  'errors.',
            ),
          ]),
        ],
      );
    }
    final slo = Slo.of(run.params);
    final p = context.palette;
    Widget tick() => Icon(Icons.check, size: 18, color: p.accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead(
          'A step passes when all three limits hold. The result is the '
          'busiest step that passed.',
        ),
        const SizedBox(height: 14),
        Points([
          Point(
            'Slow reply:',
            '99 of every 100 replies came back within ${msText(slo.p99Ms)}.',
            leading: tick(),
          ),
          Point(
            'Errors:',
            'fewer than ${_pct(slo.errorRate)} of requests failed.',
            leading: tick(),
          ),
          Point(
            'Kept up:',
            'the app answered at least ${_pct(slo.servedRatio)} of the '
                'requests we sent.',
            leading: tick(),
          ),
        ]),
        const SizedBox(height: 24),
        const SubHead(Icons.add_chart, 'Also reported', size: 16),
        const SizedBox(height: 10),
        const Points([
          Point(
            'Most requests a second at any step,',
            'however slow the replies were.',
          ),
          Point(
            'Reply times, processor and memory',
            'at the busiest step that passed.',
          ),
        ]),
      ],
    );
  }

  Widget _scenarios(RunSummary run) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Lead(
          'Every framework ran the same '
          '${numberWord(run.scenarios.length)} '
          '${run.scenarios.length == 1 ? 'test' : 'tests'}.',
        ),
        const SizedBox(height: 14),
        Points(lead: 30, [
          for (final s in run.scenarios)
            Point(
              '${testInfo(s).title}:',
              testInfo(s).what,
              leading: Icon(testIcon(s), size: 20, color: p.accent),
            ),
        ]),
      ],
    );
  }

  Widget _fairness(RunSummary run) {
    final cpusets = run.params['cpusets'] as Map? ?? const {};
    final mem = run.params['memory'] as Map? ?? const {};
    final cores = appCoreCount(run);
    final reps = _reps(run);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead('Every framework gets the same conditions.'),
        const SizedBox(height: 14),
        Points([
          Point(
            'Processor:',
            '${numberWord(cores)} cores per app, kept for it alone. The '
                'database runs on '
                '${cpusets['db'] != null ? 'cores ${cpusets['db']}' : 'cores of its own'}'
                ', our testing tool on '
                '${cpusets['k6'] != null ? 'cores ${cpusets['k6']}' : 'cores of its own'}.',
          ),
          if (mem['app'] != null)
            Point('Memory:', 'each app may use up to ${_size(mem['app'])}.'),
          const Point(
            'Settings:',
            'each app runs the way it would for real visitors, not in a '
                'test or debug mode. Most frameworks whose language uses one '
                'processor core at a time start one copy per core; serverpod '
                'runs a single copy (see its page).',
          ),
          const Point(
            'Database connections:',
            'about 20 kept open by each app. The two django apps instead go '
                'through a connection sharer (PgBouncer) with 50, and foam3 '
                '(embedded) has no database at all. Each one\'s page lists '
                'its own.',
          ),
          Point(
            'Data:',
            'before each database test the table is emptied and filled with '
                '${whole(run.params['seed_rows'] as num? ?? 10000)} rows '
                'by sending them to the app, the same way visitors would.',
          ),
          const Point(
            'Reads',
            'ask for rows near the start of the table, so the database is '
                'not what slows things down.',
          ),
          const Point(
            'serverpod and foam3',
            'have their own way of calling the server (RPC) instead of plain '
                'web addresses. We call them that way, with the same four '
                'operations.',
          ),
          Point(
            'Repeats:',
            'every test is tried ${numberWord(reps)} times. We show the '
                'middle try; tap a bar to see the lowest and highest next to '
                'it.',
          ),
        ]),
      ],
    );
  }

  Widget _thisRun(DashboardState state, RunSummary run) {
    final images = run.params['images'] as Map? ?? const {};
    final current = state.index.isEmpty ? null : state.index.first.methodology;
    final method = run.isLegacy
        ? 'the old method (version 1)'
        : 'version ${run.methodology.replaceFirst(RegExp('^v'), '')}'
              '${current == null
                  ? ''
                  : run.methodology == current
                  ? ' (the current one)'
                  : ' (an older one)'}';
    final docker = run.docker;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead(
          'Results can only be compared on the same computer with the same '
          'method.',
        ),
        const SizedBox(height: 16),
        Text(
          'Pick which run the site shows:',
          style: proseStyle(context).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        RunPicker(state: state),
        const SizedBox(height: 24),
        Points([
          if (run.date != null) Point('Date:', '${capFirst(_when(state))}.'),
          Point('Computer:', '${run.machine.label} memory.'),
          if (docker['cpus'] != null)
            Point(
              'Shared by the apps, database and testing tool:',
              '${docker['cpus']} processor cores and '
                  '${docker['mem_gb'] ?? '?'} GB of memory. Each part runs in '
                  'its own sealed-off box (a Docker container)'
                  '${docker['version'] != null ? ', Docker version ${docker['version']}' : ''}.',
            ),
          Point('Method:', '$method.'),
          if (run.contributor != null) Point('Run by:', run.contributor!),
          for (final e in images.entries)
            Point(
              '${_image('${e.key}', '${e.value}').$1}:',
              _image('${e.key}', '${e.value}').$2,
            ),
        ]),
        if (run.gitSha != null) ...[
          const SizedBox(height: 16),
          if (run.dirty)
            Points([
              Point(
                'Code:',
                'made from code with changes not yet saved, so there is no '
                    'link to the exact code (see the "modified" mark).',
              ),
            ])
          else
            Align(
              alignment: Alignment.centerLeft,
              child: SourceLink(
                url: '$kRepoUrl/tree/${run.gitSha}',
                label: 'See the exact code used for this run',
                fontSize: 16,
              ),
            ),
        ],
      ],
    );
  }

  Widget _flags() {
    final p = context.palette;
    Widget row(Widget mark, String term, String text) => Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.sizeOf(context).width < 560 ? 22 : 14,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final text0 = Points(lead: 0, [
            Point(term, text, leading: const SizedBox()),
          ]);
          // Phones: the mark above its meaning, so the text keeps its width.
          if (c.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mark,
                const SizedBox(height: 6),
                Points(lead: 0, [Point(term, text, leading: const SizedBox())]),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Align(alignment: Alignment.centerLeft, child: mark),
                ),
              ),
              Expanded(child: text0),
            ],
          );
        },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead('Some results carry a mark. Here is what each one means.'),
        const SizedBox(height: 4),
        row(
          const MarkerIcon(Marker.capped, size: 18),
          "Hit our testing tool's limit:",
          'our testing tool used most of its own processor at the top steps, '
              'so the app may be faster than measured. Several frameworks tie '
              'at this limit in No database.',
        ),
        row(
          const MarkerIcon(Marker.noisy, size: 18),
          'Noisy runs:',
          'the runs differed by more than 10% on the main number. Treat small '
              'differences with care.',
        ),
        row(
          const MarkerIcon(Marker.restarted, size: 18),
          'Restarted when overloaded:',
          'the app stopped answering and did not recover by itself. We '
              'restarted it (keeping its data) and kept measuring. This says '
              'something about how it copes, not just its speed.',
        ),
        row(
          Text('—', style: Txt(p).body.copyWith(color: p.muted)),
          'Not measured',
          'in that test.',
        ),
        row(
          const Flag(text: 'capped', icon: Icons.speed, tooltip: ''),
          "The tool's limit, as a label.",
          'On the results page it reads "or more", or a plus sign (+).',
        ),
        row(
          const Flag(text: '±15%', icon: Icons.waves, tooltip: ''),
          'The noisy-runs warning,',
          'with how far apart the runs were.',
        ),
        row(
          Flag(text: 'note', tooltip: '', color: p.muted),
          'A note from its author.',
          "It is printed in full in the framework's own page and when its "
              'name is opened.',
        ),
        row(
          const Flag(text: 'modified', tooltip: ''),
          'Unsaved code changes:',
          'the run was made from code with changes not yet saved, so the '
              'linked code is not exactly what ran.',
        ),
        row(
          const Flag(text: 'v1 method', tooltip: ''),
          'Old method:',
          'a run made with the older method. Cannot be compared with newer '
              'runs.',
        ),
      ],
    );
  }

  Widget _glossary(RunSummary run) {
    final results = [for (final b in run.backends) ...b.scenarios.values];
    final metrics = Metrics.available(results, Metrics.all);
    final slo = Slo.of(run.params);
    final cores = appCoreCount(run);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead('Every number on this site, in plain words.'),
        const SizedBox(height: 14),
        Points([
          for (final m in metrics)
            Point('${_label(m)}:', _meaning(m, slo, cores, run)),
          // The old method had no steps and no limits.
          if (!run.isLegacy) ...[
            const Point(
              'Asked for and answered:',
              'our testing tool asks for a fixed number of requests a second. '
                  '"Answered" is what the app really replied to. Where the '
                  'step chart leaves the dashed diagonal, the app stopped '
                  'keeping up.',
            ),
            const Point(
              'Limits:',
              'the three limits a step must meet to pass: slow replies, '
                  'errors and keeping up. Engineers call these an SLO '
                  '(service level objective).',
            ),
          ],
        ]),
      ],
    );
  }

  /// A number's name in the glossary: the same one the tables use.
  static String _label(Metric m) => plainMetricLabel(m);

  /// What a number means, in plain words.
  String _meaning(Metric m, Slo slo, int cores, RunSummary run) =>
      capFirst(_meaningText(m, slo, cores, run));

  String _meaningText(
    Metric m,
    Slo slo,
    int cores,
    RunSummary run,
  ) => switch (m.id) {
    'sustainable_rps' =>
      'the busiest step it passed: 99 of every 100 replies within '
          '${msText(slo.p99Ms)}, fewer than ${_pct(slo.errorRate)} '
          'errors, and at least ${_pct(slo.servedRatio)} of requests '
          'answered. The middle of the ${numberWord(_reps(run))} tries.',
    'peak_rps' =>
      'the most requests a second it really answered at any step, '
          'however slow the replies were. The result counts the rate we '
          'sent, so this can sit just below it.',
    'avg_rps' =>
      'old method: the average requests a second while '
          'simulated users were added.',
    'p50_ms' =>
      'half of all replies came back faster than this, '
          '${run.isLegacy ? 'averaged over the whole test' : 'at the busiest step it passed'}.',
    'p90_ms' => '9 in 10 replies came back faster than this.',
    'p99_ms' => '99 of every 100 replies came back within this.',
    'p999_ms' => '999 of every 1,000 replies came back within this.',
    'error_rate' =>
      'the share of requests that failed, '
          '${run.isLegacy ? 'over the whole test' : 'at the busiest step it passed'}.',
    'app_cpu' =>
      'how much of its ${numberWord(cores)} processor '
          '${cores == 1 ? 'core' : 'cores'} the app used. 100% is '
          '${cores == 1 ? 'that core' : 'all of them'}.',
    'app_mem_mb' =>
      'how much memory the app used, at the busiest step it passed.',
    'db_cpu' =>
      'how much processor the database used while serving this '
          'framework. 100% is one full core.',
    'rps_per_core' =>
      'requests a second divided by the processor cores '
          'it really used.',
    'rps_per_100mb' =>
      'requests a second for every 100 MB of memory it '
          'used.',
    _ => m.help,
  };

  Widget _limits(RunSummary run) {
    final limit = toolLimit(run);
    final around = limit == null
        ? '48,000'
        : whole(limit < 1000 ? limit : (limit / 1000).round() * 1000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Lead('Read the numbers with these limits in mind.'),
        const SizedBox(height: 14),
        Points([
          if (!run.isLegacy)
            Point(
              "Our testing tool's limit:",
              'results stop at about $around requests a second on this '
                  'computer in No database (it cannot send more than that '
                  'steadily), and lower in the tests that use the database, '
                  'where it has more work per request. Frameworks '
                  "that hit it get a striped bar end; they may be faster than "
                  'their number.',
            ),
          const Point(
            'One computer:',
            'the numbers belong to this computer and how it was set up. Only '
                'runs on the same computer with the same method can be '
                'compared, which is why History never mixes them.',
          ),
          const Point(
            'Storage options',
            'of one framework (such as foam3 with its own built-in store, or '
                'with PostgreSQL) only differ where storage is what slows '
                'things down. Where handling requests is the limit, they show '
                'similar numbers.',
          ),
          Point(
            'The slow reply',
            run.isLegacy
                ? 'is an average over the whole old test, which sent the same '
                      'traffic to every framework.'
                : "is measured at each framework's own result. A slower "
                      'framework can show a quicker slow reply simply because '
                      'it served less traffic.',
          ),
          const Point(
            'Older runs:',
            'how-it-is-built details for runs made before we recorded them '
                "come from today's code, not from the run. The site says so "
                'where it applies.',
          ),
        ]),
      ],
    );
  }

  // -------------------------------------------------------------- helpers

  String _steps(RunSummary run) {
    final steps = run.params['steps'];
    if (steps is! List || steps.isEmpty) {
      return 'from 250 to 64,000 requests a second';
    }
    return '${numberWord(steps.length)} steps, from ${whole(steps.first as num)} '
        'to ${whole(steps.last as num)} requests a second, doubling each time';
  }

  /// "2g" -> "2 GB".
  static String _size(Object? v) => '$v'.replaceAllMapped(
    RegExp(r'^(\d+)\s*([gm])b?$', caseSensitive: false),
    (m) => '${m[1]} ${m[2]!.toUpperCase()}B',
  );

  /// What an image in the run's settings is for.
  /// ("db", "postgres:18.6") -> ("Database", "PostgreSQL 18.6").
  static (String, String) _image(String key, String image) {
    final version = image.contains(':') ? image.split(':').last : image;
    return switch (key) {
      'db' => ('Database', 'PostgreSQL $version'),
      'k6' => ('Testing tool version', version),
      'pgbouncer' => (
        'Database connection sharer',
        'PgBouncer $version (it lets many requests share a few database '
            'connections)',
      ),
      _ => (capFirst(key), image),
    };
  }
}

/// 0.01 -> "1%", 0.95 -> "95%".
String _pct(double share) {
  final v = share * 100;
  return '${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(1)}%';
}

/// A section card: its number, icon, title and one-line summary; the
/// details open on tap.
class _Collapsible extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String summary;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  const _Collapsible({
    required this.number,
    required this.icon,
    required this.title,
    required this.summary,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return AnimatedContainer(
      duration: motion(context, 200),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: open ? p.accent.withValues(alpha: 0.45) : p.line,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 560;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Pressable(
                onTap: onToggle,
                radius: kRadius,
                expanded: open,
                semanticLabel: '$number. $title. $summary',
                builder: (context, hovered) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: open ? p.accent : p.accentSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 19,
                            color: open ? p.accentInk : p.accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$number. $title',
                                style: t.h3.copyWith(
                                  fontSize: 18,
                                  decoration: hovered
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(summary, style: t.small),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: open ? 0.5 : 0,
                          duration: motion(context, 200),
                          child: Icon(Icons.expand_more, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (open)
                Padding(
                  padding: EdgeInsets.fromLTRB(narrow ? 18 : 64, 4, 18, 24),
                  child: child,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Table of contents: a rail beside the page (wide screens) that marks the
/// section in view, or a collapsible list on the page (narrower). Entries
/// open their section and scroll to it.
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
    final p = context.palette;
    final t = Txt(p);
    final title = Row(
      children: [
        Icon(Icons.toc, size: 20, color: p.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text('On this page', style: t.h3.copyWith(fontSize: 16)),
        ),
        if (collapsible)
          Icon(open ? Icons.expand_less : Icons.expand_more, color: p.muted),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: p.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (collapsible)
            Pressable(
              onTap: onToggle,
              radius: 6,
              expanded: open,
              semanticLabel: 'On this page',
              builder: (context, hovered) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ExcludeSemantics(child: title),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: title,
            ),
          if (open)
            for (var i = 0; i < sections.length; i++)
              Pressable(
                onTap: () => onJump(sections[i]),
                radius: 6,
                minHeight: 36,
                selected: active == sections[i].id,
                semanticLabel: sections[i].title,
                builder: (context, hovered) {
                  final on = active == sections[i].id;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: on ? p.accent : p.line,
                          width: on ? 3 : 2,
                        ),
                      ),
                    ),
                    child: Text(
                      '${i + 1}. ${sections[i].title}',
                      style: t.small.copyWith(
                        fontSize: 14.5,
                        height: 1.35,
                        color: on ? p.text : p.muted,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                        decoration: hovered ? TextDecoration.underline : null,
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

/// Why a step failed, in a few plain words; "passed" when it held.
String _why(LoadStep s, Slo slo) {
  if (s.pass) return 'passed';
  if (s.k6Bound) return 'tool limit';
  final parts = [
    if (s.p99 >= slo.p99Ms) 'slow: ${msText(s.p99)}',
    if (s.errorRate >= slo.errorRate)
      '${(s.errorRate * 100).toStringAsFixed(1)}% errors',
    if (s.targetRps > 0 && s.achievedRps / s.targetRps < slo.servedRatio)
      'answered ${(s.achievedRps / s.targetRps * 100).floor()}%',
  ];
  return parts.isEmpty ? 'failed a limit' : parts.join(', ');
}

/// The same in a full sentence, for the lines under the chart.
String _whySentence(LoadStep s, Slo slo) {
  if (s.k6Bound) {
    return "our testing tool could not send more, so the app wasn't the "
        'limit here';
  }
  final parts = [
    if (s.p99 >= slo.p99Ms)
      'the slow reply took ${msText(s.p99)}, over the '
          '${msText(slo.p99Ms)} limit',
    if (s.errorRate >= slo.errorRate)
      '${(s.errorRate * 100).toStringAsFixed(1)}% of requests failed',
    if (s.targetRps > 0 && s.achievedRps / s.targetRps < slo.servedRatio)
      'it answered only ${(s.achievedRps / s.targetRps * 100).floor()}% of '
          'the requests',
  ];
  return parts.isEmpty ? 'it failed a limit' : joinAnd(parts);
}

/// "How a run works", drawn from one real result: every load step the
/// best framework of the chosen test ran (one our testing tool did not
/// limit, when there is one), in order of rate. Each bar is what was
/// answered under an outline of what was asked; teal steps passed, red
/// ones broke a limit, amber ones failed because the testing tool itself
/// was the limit. The flag marks the result.
class _RunStaircase extends StatelessWidget {
  final DashboardState state;

  const _RunStaircase({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state.scenario;
    final run = state.run;
    if (s == null || run == null) return const SizedBox.shrink();
    final ranked = [
      for (final r in resultsFor(run, s, Metrics.sustainable)) r.backend,
    ].where((b) => (b.scenarios[s]?.steps.length ?? 0) > 1).toList();
    if (ranked.isEmpty) return const SizedBox.shrink();
    // An example our testing tool limited would show its failures as the
    // app's; prefer the best one it did not.
    final b = ranked.firstWhere(
      (x) => !x.scenarios[s]!.loadgenBound,
      orElse: () => ranked.first,
    );
    final r = b.scenarios[s]!;
    final steps = [...r.steps]
      ..sort((a, c) => a.targetRps.compareTo(c.targetRps));
    final slo = Slo.of(run.params);
    final base = steps.first.targetRps;
    final top = steps
        .map((x) => math.max(x.targetRps, x.achievedRps))
        .reduce(math.max);
    double h(double rps) => rps <= 0 || top <= base
        ? 0
        : (math.log(math.max(rps, base) / base) / math.log(top / base)).clamp(
            0.0,
            1.0,
          );
    final lastPass = steps.lastIndexWhere((x) => x.pass);
    final firstFail = steps.indexWhere((x) => !x.pass);
    final sustainable = Metrics.sustainable.value(r);
    final reps = run.params['reps'] is num
        ? (run.params['reps'] as num).toInt()
        : 3;
    final p = context.palette;
    final t = Txt(p);
    // Others it ties with (the same number, or about the same by Who's
    // fastest's rule) are named, so the example never claims a lead that
    // the results page does not back.
    final results = resultsFor(run, s);
    final mine = results.where((x) => x.key == b.key).firstOrNull;
    final topKeys = {for (final x in topGroup(results)) x.key};
    final tied = [
      for (final x in results)
        if (mine != null &&
            x.key != b.key &&
            (x.value == mine.value ||
                (topKeys.contains(b.key) && topKeys.contains(x.key))))
          x.name,
    ];
    final tieNote = tied.isEmpty ? '' : ' (about the same as ${joinAnd(tied)})';
    final pick = b == ranked.first
        ? '${tied.isEmpty ? 'the fastest framework' : 'one of the fastest frameworks'} '
              'in this test$tieNote'
        : "the fastest framework that did not hit our testing tool's "
              'limit$tieNote';
    final ticks = [
      for (var v = 1000.0; v <= top; v *= 10)
        if (v > base) v,
    ];
    final anyToolLimit = steps.any((x) => !x.pass && x.k6Bound);
    final anyFail = steps.any((x) => !x.pass && !x.k6Bound);
    final anyExtra = steps.any((x) => x.refine);
    const barArea = 150.0;
    Color tone(LoadStep x) => x.pass
        ? p.accent
        : x.k6Bound
        ? p.warn
        : p.danger;
    final test = testInfo(s);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How one try works', style: t.small),
          const SizedBox(height: 4),
          const SubHead(Icons.stairs_outlined, 'One real try, step by step'),
          const SizedBox(height: 12),
          Lead(
            'This is what our testing tool did to ${b.name} in the '
            '"${test.title}" test. ${capFirst(b.name)} is $pick.',
          ),
          const SizedBox(height: 20),
          Text('Requests a second', style: t.small.copyWith(fontSize: 13.5)),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              const axis = 48.0;
              final width = c.maxWidth - axis;
              final gap = width < 500 ? 3.0 : 6.0;
              final barW = (width - gap * (steps.length - 1)) / steps.length;
              final wide = barW >= 64;
              // Rate labels need about 46 px each; the result's label
              // always shows, the others where they do not collide.
              final stride = math.max(1, (46 / (barW + gap)).ceil());
              final labelled = <int>{if (lastPass >= 0) lastPass};
              for (var i = 0; i < steps.length; i++) {
                if (labelled.every((j) => (i - j).abs() >= stride)) {
                  labelled.add(i);
                }
              }
              return SizedBox(
                height: barArea + 26 + (wide ? 30 : 0) + 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Gridlines with their rates; each is ten times the
                    // one below.
                    for (final v in ticks)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 26 + (wide ? 30 : 0) + barArea * h(v) - 7,
                        child: Row(
                          children: [
                            SizedBox(
                              width: axis,
                              child: Text(
                                whole(v),
                                style: t.small.copyWith(
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(height: 1, color: p.line),
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
                                          ? 'passed: ${msText(steps[i].p99)}'
                                          : _why(steps[i], slo))
                                    : null,
                                showRate: labelled.contains(i),
                                slo: slo,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Points(lead: 28, [
            if (lastPass >= 0)
              Point(
                'Passed ${whole(steps[lastPass].targetRps)} requests a '
                    'second.',
                '99 of every 100 replies came back within '
                    '${msText(steps[lastPass].p99)}.',
                leading: Icon(Icons.check_circle, size: 20, color: p.accent),
              ),
            if (firstFail >= 0)
              Point(
                'Failed at ${whole(steps[firstFail].targetRps)}:',
                '${_whySentence(steps[firstFail], slo)}.',
                leading: Icon(
                  Icons.cancel,
                  size: 20,
                  color: steps[firstFail].k6Bound ? p.warn : p.danger,
                ),
              ),
            if (sustainable != null)
              Point(
                'The result: ${whole(sustainable)} requests a second.',
                'That is the middle of the ${numberWord(reps)} tries, so it '
                    'can differ a little from this one.',
                leading: Icon(Icons.flag, size: 20, color: p.accent),
              ),
          ]),
          const SizedBox(height: 24),
          const SubHead(Icons.palette_outlined, 'How to read it', size: 16),
          const SizedBox(height: 12),
          Points(lead: 28, [
            Point(
              'Teal: passed.',
              'Fast enough, few enough errors, and it kept up.',
              leading: Swatch(p.accent, fill: 0.45),
            ),
            if (anyFail || !anyToolLimit)
              Point(
                'Red: failed.',
                'Too slow, too many errors, or it could not keep up.',
                leading: Swatch(p.danger, fill: 0.4),
              ),
            if (anyToolLimit)
              Point(
                "Amber: hit our testing tool's limit.",
                'The tool could not send more, so the app was not the limit.',
                leading: Swatch(p.warn, fill: 0.4),
              ),
            Point(
              'Flag:',
              'the busiest step it passed. Its bar is solid and stands out.',
              leading: Icon(Icons.flag, size: 18, color: p.accent),
            ),
            const Point(
              'Filled part',
              'is what the app answered. The outline is what we asked for.',
            ),
            const Point(
              'Left to right,',
              'each step sends more requests. Bars are squeezed so small and '
                  'large numbers both fit: each gridline is ten times the one '
                  'below.',
            ),
            if (anyExtra)
              const Point(
                'Thin bars',
                'are extra steps tried between the last pass and the first '
                    'fail, to find the limit more exactly.',
              ),
          ]),
        ],
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
    final p = context.palette;
    final t = Txt(p);
    final i = index;
    final extra = step.refine;
    final why = _why(step, slo);
    return Tooltip(
      message:
          '${whole(step.targetRps)} requests a second asked · '
          '${whole(step.achievedRps)} answered · slow reply '
          '${msText(step.p99)} · '
          '${(step.errorRate * 100).toStringAsFixed(2)}% errors'
          '${extra ? ' · extra step' : ''} · $why',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (held)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Icon(
                Icons.flag,
                size: 16,
                color: p.accent,
                semanticLabel: 'Busiest step it passed',
              ),
            ),
          FractionallySizedBox(
            widthFactor: extra ? 0.62 : 1,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: motion(context, 360 + i * 45),
              curve: Interval(
                i * 45 / (360 + i * 45),
                1,
                curve: Curves.easeOutCubic,
              ),
              builder: (context, f, _) => SizedBox(
                height: 6 + asked * f,
                child: Stack(
                  children: [
                    // What was asked: an outline.
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
                    // What was answered.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: (6 + served * f).clamp(0, 6 + asked * f),
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
                // May spill past a narrow bar into its unlabelled
                // neighbours' room.
                ? OverflowBox(
                    maxWidth: 64,
                    child: Text(
                      whole(step.targetRps),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: t.num(
                        11,
                        weight: held ? FontWeight.w700 : FontWeight.w400,
                      ).copyWith(color: held ? p.text : p.muted),
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
                style: t.small.copyWith(
                  fontSize: 11,
                  height: 1.25,
                  color: step.pass ? p.accent : color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Which run the site shows. Lives on the Method page.
/// The one run picker on the page, so it can be scrolled back into view.
final _runPickerKey = GlobalKey(debugLabel: 'run picker');

class RunPicker extends StatelessWidget {
  final DashboardState state;

  const RunPicker({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selected = state.entry;
    return Container(
      key: _runPickerKey,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.text),
      ),
      child: Semantics(
        label: 'Run shown on the site',
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected?.id,
            isExpanded: true,
            dropdownColor: p.surface,
            icon: Icon(Icons.expand_more, color: p.text, size: 22),
            style: Txt(p).body.copyWith(fontSize: 15.5),
            // Two lines per run, wrapping instead of "…", so runs on the
            // same computer can be told apart on a phone too.
            itemHeight: null,
            selectedItemBuilder: (context) => [
              for (final e in state.index)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _runLines(context, e),
                  ),
                ),
            ],
            items: [
              for (final e in state.index)
                DropdownMenuItem(
                  value: e.id,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _runLines(context, e),
                  ),
                ),
            ],
            onChanged: (id) async {
              final e = state.index.where((x) => x.id == id).firstOrNull;
              if (e == null) return;
              await state.selectRun(e);
              // Sections above come and go with the run; keep the picker
              // (and the facts it just changed) on screen.
              bringIntoView(_runPickerKey);
            },
          ),
        ),
      ),
    );
  }

  /// A run's icon, its name and, under it, its method and size.
  Widget _runLines(BuildContext context, RunIndexEntry e) {
    final p = context.palette;
    final t = Txt(p);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            switch (e.kind) {
              RunKind.latest => Icons.auto_awesome,
              RunKind.legacy => Icons.history,
              RunKind.run => Icons.play_circle_outline,
            },
            size: 17,
            color: e.kind == RunKind.latest ? p.accent : p.muted,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                runLabel(e, newest: state.index.firstOrNull),
                style: t.body.copyWith(fontSize: 15.5, height: 1.25),
              ),
              Text(
                runDetail(e),
                style: t.small.copyWith(fontSize: 13.5, height: 1.25),
              ),
            ],
          ),
        ),
        if (e.dirty) ...[
          const SizedBox(width: 6),
          const Flag(
            text: 'modified',
            tooltip: 'Made from code with changes not yet saved.',
          ),
        ],
      ],
    );
  }
}

/// When the shown numbers were measured: one date for a single run; for a
/// combined view, "up to 5 October 2026, combined from 2 runs", since each
/// framework keeps its own newest run.
String _when(DashboardState state) {
  final e = state.entry;
  final date = longDate(e?.date ?? state.run?.date);
  if (e == null || e.kind != RunKind.latest) return date;
  return [
    'up to $date',
    if (e.runs.length > 1) 'combined from ${numberWord(e.runs.length)} runs',
  ].join(', ');
}
