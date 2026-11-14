// Plain-English summaries built from the data. Every sentence the home
// page shows about the results comes from a function here, so counts,
// names and numbers always match the run on screen. Pure Dart: no widgets.

import 'dart:math' as math;

import 'metrics.dart';
import 'results.dart';
import 'tests.dart';

export 'tests.dart';

/// The tests of [run] in display order.
List<String> testsOf(RunSummary run) => run.scenarios;

/// The number the run ranks by: requests a second held under the limits
/// (current method) or the average (v1).
Metric headlineOf(RunSummary run) =>
    Metrics.headlineFor([for (final b in run.backends) ...b.scenarios.values]);

// ---------------------------------------------------------------- results

/// One framework's main number in one test, with the lowest and highest
/// of its runs.
class Result {
  final BackendResult backend;
  final double value;
  final double low;
  final double high;

  /// It reached the most the load tool could send (`loadgen_bound`).
  final bool capped;
  final int reps;
  final int restarts;

  const Result({
    required this.backend,
    required this.value,
    required this.low,
    required this.high,
    this.capped = false,
    this.reps = 1,
    this.restarts = 0,
  });

  String get key => backend.key;
  String get name => backend.name;

  /// The lowest-to-highest run ranges of the two overlap.
  bool overlaps(Result o) => low <= o.high && o.low <= high;
}

/// Every framework with a result in [test], highest first (name order
/// among equals).
List<Result> resultsFor(RunSummary run, String test, [Metric? metric]) {
  final m = metric ?? headlineOf(run);
  final out = <Result>[];
  for (final b in run.backends) {
    final r = b.scenarios[test];
    if (r == null) continue;
    final s = m.stat(r);
    final v = s?.median ?? m.value(r);
    if (v == null) continue;
    out.add(
      Result(
        backend: b,
        value: v,
        low: s?.min ?? v,
        high: s?.max ?? v,
        capped: r.loadgenBound,
        reps: r.reps,
        restarts: r.restarts,
      ),
    );
  }
  return sortResults(out);
}

/// Highest first; name order among equals, so ties have a stable order.
List<Result> sortResults(Iterable<Result> rs) => [...rs]
  ..sort((a, b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.name.compareTo(b.name);
  });

/// The others in [all] whose run range overlaps [r]'s: too close to call.
/// Highest first.
List<Result> closeTo(List<Result> all, Result r) =>
    sortResults(all.where((o) => o.key != r.key && r.overlaps(o)));

// ---------------------------------------------------------------- numbers

/// 40000 -> "40,000".
String whole(num v) {
  final s = v.round().abs().toString();
  final grouped = s.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return v.round() < 0 ? '-$grouped' : grouped;
}

const _words = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
];

/// 3 -> "three"; digits from 13 up.
String numberWord(int n) => n >= 0 && n < _words.length ? _words[n] : '$n';

String capFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "a", "a and b", "a, b and c".
String joinAnd(List<String> items) => switch (items.length) {
  0 => '',
  1 => items.first,
  _ => '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}',
};

String _names(Iterable<Result> rs) => joinAnd([for (final r in rs) r.name]);

/// "40,000" or "40,000 or more" when the load tool was the limit.
String numberText(Result r) => '${whole(r.value)}${r.capped ? ' or more' : ''}';

/// "27,000" or "27,000 to 30,000".
String spanText(double lo, double hi) =>
    whole(lo) == whole(hi) ? whole(lo) : '${whole(lo)} to ${whole(hi)}';

/// Replies: 0.4 -> "0.4 ms", 70.7 -> "71 ms".
String msText(double v) => '${v < 10 ? v.toStringAsFixed(1) : whole(v)} ms';

/// Processor use as a share of the cores the app was given (the raw value
/// is a percentage of one core).
String cpuText(double v, int cores) =>
    '${math.min(100, (v / math.max(1, cores)).round())}%';

/// Memory: "383 MB", "1.9 GB".
String memText(double mb) =>
    mb >= 1000 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${whole(mb)} MB';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "2026-10-05" -> "5 October 2026"; anything else unchanged.
String longDate(String? iso) {
  if (iso == null) return 'an unknown date';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  final month = int.parse(m[2]!);
  if (month < 1 || month > 12) return iso;
  return '${int.parse(m[3]!)} ${_months[month - 1]} ${m[1]}';
}

// -------------------------------------------------------------- sentences

const kLimitSentence =
    'This reached the most our test tool could send, so the real figure may '
    'be higher.';

/// "All three runs gave the same result." / "The three runs ranged from
/// 38,000 to 40,000." / "We ran this test once."
String runsSentence(Result r) {
  if (r.reps <= 1) return 'We ran this test once.';
  final n = numberWord(r.reps);
  if (whole(r.low) == whole(r.high)) return 'All $n runs gave the same result.';
  return 'The $n runs ranged from ${whole(r.low)} to ${whole(r.high)}.';
}

/// "Too close to call with A and B." or "".
String closeSentence(List<Result> all, Result r) {
  final c = closeTo(all, r);
  return c.isEmpty ? '' : 'Too close to call with ${_names(c)}.';
}

/// "It stopped responding when overloaded and was restarted twice." or "".
String restartSentence(Result r) => switch (r.restarts) {
  <= 0 => '',
  1 => 'It stopped responding when overloaded and had to be restarted once.',
  2 => 'It stopped responding when overloaded and had to be restarted twice.',
  _ =>
    'It stopped responding when overloaded and had to be restarted '
        '${r.restarts} times.',
};

/// Where [r] sits among [all]: "3 of the other 11 handled more."
String placeSentence(List<Result> all, Result r) {
  final n = all.length;
  var more = 0, same = 0;
  for (final o in all) {
    if (o.key == r.key) continue;
    if (o.value > r.value) {
      more++;
    } else if (o.value == r.value) {
      same++;
    }
  }
  if (n <= 1) return 'The only framework measured here.';
  if (more == 0) {
    if (same == 0) return 'The highest of the $n.';
    return 'Joint highest of the $n, level with $same '
        '${same == 1 ? 'other' : 'others'}.';
  }
  if (more == n - 1) return 'The lowest of the $n.';
  return '$more of the other ${n - 1} handled more.';
}

/// What the inline reveal and the profile rows say after the number: the
/// runs, the tool limit or the close call, restarts. [withPlace] adds the
/// framework's place first.
List<String> resultSentences(
  List<Result> all,
  Result r, {
  bool withPlace = false,
}) => [
  if (withPlace) placeSentence(all, r),
  runsSentence(r),
  if (r.capped) kLimitSentence else closeSentence(all, r),
  restartSentence(r),
].where((s) => s.isNotEmpty).toList();

// ------------------------------------------------------------------ bands

/// A range of numbers and the frameworks in it, for the short answer.
class Band {
  final double from;

  /// Exclusive upper bound; null for the top band.
  final double? to;
  final List<Result> members;

  const Band(this.from, this.to, this.members);

  /// "30,000 or more", "10,000 to 20,000", "Under 10,000".
  String get label {
    if (to == null) return '${whole(from)} or more';
    if (from <= 0) return 'Under ${whole(to!)}';
    return '${whole(from)} to ${whole(to!)}';
  }

  List<Result> get capped => members.where((m) => m.capped).toList();

  /// The note under a band's names about the load-tool limit, or "".
  String get cappedNote {
    final c = capped;
    if (c.isEmpty) return '';
    if (c.length == 1) {
      return '${capFirst(c.first.name)} reached the most our test tool could '
          'send, so its real figure may be higher.';
    }
    return '${capFirst(_names(c))} all reached the most our test tool could '
        'send, so we cannot tell them apart.';
  }
}

/// A round step that splits [max] into about four bands: 1, 2, 2.5 or 5
/// times a power of ten, at least 1.
double bandStep(double max) {
  final raw = max / 4;
  if (raw <= 1) return 1;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (raw <= m * mag + 1e-9) return m * mag;
  }
  return 10 * mag;
}

/// [results] grouped into at most four bands of equal width, highest
/// first; empty bands are left out and the top one is open-ended.
List<Band> bandsFor(List<Result> results) {
  if (results.isEmpty) return const [];
  final max = results.map((r) => r.value).reduce(math.max);
  final step = bandStep(max);
  final groups = <int, List<Result>>{};
  for (final r in sortResults(results)) {
    final k = math.min(3, (r.value / step).floor());
    (groups[k] ??= []).add(r);
  }
  final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (var i = 0; i < keys.length; i++)
      Band(
        keys[i] * step,
        i == 0 ? null : (keys[i] + 1) * step,
        groups[keys[i]]!,
      ),
  ];
}

// ---------------------------------------------------------------- answers

/// The answer paragraph of the short answer: who handled the most, who
/// came next, and who stayed in the lowest band.
String answerFor(List<Result> results) {
  if (results.isEmpty) return 'No framework has a result in this test.';
  final sorted = sortResults(results);
  final leader = sorted.first;
  final top = sortResults([leader, ...closeTo(sorted, leader)]);
  final out = <String>[];
  final atLeast = top.any((r) => r.capped) ? 'at least ' : '';
  if (top.length == 1) {
    out.add(
      '${capFirst(leader.name)} handled the most: $atLeast'
      '${whole(leader.value)} requests a second.',
    );
  } else {
    final lo = top.map((r) => r.value).reduce(math.min);
    final hi = top.map((r) => r.value).reduce(math.max);
    out.add(
      '${capFirst(_names(top))} handled the most, too close to call: '
      '$atLeast${spanText(lo, hi)} requests a second.',
    );
  }
  final shown = {for (final r in top) r.key};
  final rest = sorted.where((r) => !shown.contains(r.key)).toList();
  if (rest.isNotEmpty) {
    final next = rest.first;
    final group = sortResults([
      next,
      ...closeTo(rest, next).where((r) => !shown.contains(r.key)),
    ]);
    shown.addAll(group.map((r) => r.key));
    final lo = group.map((r) => r.value).reduce(math.min);
    final hi = group.map((r) => r.value).reduce(math.max);
    out.add('${capFirst(_names(group))} came next, at ${spanText(lo, hi)}.');
  }
  final bands = bandsFor(sorted);
  if (bands.length > 1) {
    final bottom = bands.last;
    final low = bottom.members.where((r) => !shown.contains(r.key)).toList();
    if (low.isNotEmpty && bottom.to != null) {
      out.add('${capFirst(_names(low))} stayed under ${whole(bottom.to!)}.');
    }
  }
  return out.join(' ');
}

/// Spearman's rank correlation of the frameworks both lists share; null
/// when fewer than three are shared.
double? orderAgreement(List<Result> a, List<Result> b) {
  final keys = {
    for (final r in a) r.key,
  }.intersection({for (final r in b) r.key});
  if (keys.length < 3) return null;
  final ra = [for (final r in sortResults(a)) r.key].where(keys.contains);
  final rb = [for (final r in sortResults(b)) r.key].where(keys.contains);
  final pa = {for (final (i, k) in ra.indexed) k: i};
  final pb = {for (final (i, k) in rb.indexed) k: i};
  final n = keys.length;
  var d2 = 0.0;
  for (final k in keys) {
    final d = (pa[k]! - pb[k]!).toDouble();
    d2 += d * d;
  }
  return 1 - 6 * d2 / (n * (n * n - 1));
}

/// One line for an "Other kinds of work" row: how [results] differ from
/// the main test's [main] (titled [mainTitle]).
String otherSummary(
  List<Result> results,
  List<Result> main,
  TestInfo mainTitle,
) {
  if (results.isEmpty) return 'No framework has a result in this test.';
  final sorted = sortResults(results);
  final capped = sorted.where((r) => r.capped).toList();
  if (capped.length >= 2 && sorted.first.capped) {
    final n = numberWord(capped.length);
    return '${capFirst(n)} frameworks reached the most our test tool can '
        'send, so we cannot tell those $n apart.';
  }
  final leader = sorted.first;
  final lead =
      '${capFirst(leader.name)} handled the most, '
      '${leader.capped ? 'at least ' : ''}${whole(leader.value)} requests a '
      'second.';
  final rho = orderAgreement(sorted, main);
  if (rho == null || main.isEmpty) return lead;
  final order = rho >= 0.8
      ? 'Nearly the same order as ${mainTitle.inSentence}'
      : rho >= 0.5
      ? 'A similar order to ${mainTitle.inSentence}, with some changes'
      : 'A different order from ${mainTitle.inSentence}';
  final topHere = leader.value;
  final topMain = sortResults(main).first.value;
  final numbers = topHere > topMain * 1.1
      ? ', with higher numbers at the top'
      : topHere < topMain * 0.9
      ? ', with lower numbers at the top'
      : '';
  return '$order$numbers. $lead';
}

// ---------------------------------------------------------------- compare

/// "one kind of work", "three kinds of work".
String kindsOfWork(int n) =>
    '${numberWord(n)} ${n == 1 ? 'kind' : 'kinds'} of work';

/// The comparison's answer in one plain sentence (or two): who handled the
/// most in how many kinds of work, and where it was too close to call.
/// [byTest] holds the picked frameworks' results per test, in test order.
String compareVerdict(Map<String, List<Result>> byTest) {
  final wins = <String, List<String>>{};
  final names = <String, String>{};
  var contested = 0, close = 0;
  for (final e in byTest.entries) {
    final rs = sortResults(e.value);
    if (rs.length < 2) continue;
    contested++;
    if (rs[0].overlaps(rs[1])) {
      close++;
      continue;
    }
    (wins[rs[0].key] ??= []).add(e.key);
    names[rs[0].key] = rs[0].name;
  }
  if (contested == 0) {
    return 'Pick frameworks that were measured in the same kind of work.';
  }
  if (wins.isEmpty) {
    return contested == 1
        ? 'They were too close to call.'
        : 'They were too close to call in every kind of work.';
  }
  final most = wins.values.map((w) => w.length).reduce(math.max);
  final leaders = wins.keys.where((k) => wins[k]!.length == most).toList();
  final closeNote = close == 0
      ? ''
      : close == 1
      ? ' In one, the top two were too close to call.'
      : ' In ${numberWord(close)}, the top two were too close to call.';
  if (leaders.length > 1) {
    return '${capFirst(joinAnd([for (final k in leaders) names[k]!]))} each '
        'handled the most in ${kindsOfWork(most)}.$closeNote';
  }
  final top = leaders.single;
  final head = most == contested
      ? (contested == 1
            ? '${capFirst(names[top]!)} handled the most.'
            : '${capFirst(names[top]!)} handled the most in all '
                  '${kindsOfWork(contested)}.')
      : '${capFirst(names[top]!)} handled the most in ${numberWord(most)} of '
            'the ${kindsOfWork(contested)}.';
  final others = [
    for (final e in wins.entries)
      if (e.key != top)
        '${capFirst(names[e.key]!)} led in '
            '${joinAnd([for (final t in e.value) testInfo(t).inSentence])}.',
  ];
  return [head, ...others].join(' ') + closeNote;
}

/// One test of a comparison in words: who handled the most (or who was too
/// close to call), who came next, and who handled the least.
String compareTestSentence(List<Result> results) {
  final rs = sortResults(results);
  if (rs.isEmpty) return 'None of them was measured here.';
  if (rs.length == 1) {
    return 'Only ${rs.first.name} was measured here, at '
        '${numberText(rs.first)}.';
  }
  final lead = rs.first;
  final tied = sortResults([lead, ...closeTo(rs, lead)]);
  final out = <String>[];
  if (tied.length > 1) {
    out.add(
      '${capFirst(_names(tied))} were too close to call, at '
      '${spanText(tied.last.value, tied.first.value)}'
      '${tied.any((r) => r.capped) ? ' or more' : ''}.',
    );
  } else {
    out.add('${capFirst(lead.name)} handled the most, ${numberText(lead)}.');
  }
  final rest = rs.skip(tied.length).toList();
  if (rest.isNotEmpty) {
    out.add(
      '${capFirst(rest.first.name)} came next, at ${whole(rest.first.value)}.',
    );
  }
  if (rest.length > 1) {
    out.add(
      '${capFirst(rest.last.name)} handled the least, ${whole(rest.last.value)}.',
    );
  }
  if (rs.any((r) => r.capped)) {
    final c = rs.where((r) => r.capped).toList();
    out.add(
      '${capFirst(_names(c))} reached the most our test tool could send, so '
      'the real ${c.length == 1 ? 'figure' : 'figures'} may be higher.',
    );
  }
  return out.join(' ');
}

// ------------------------------------------------------------ the method

/// Cores each app was given: from the cpuset ("0-1" is two), else the v1
/// "app_cpus", else 2.
int appCoreCount(RunSummary run) {
  final cpus = run.params['app_cpus'];
  final cpusets = run.params['cpusets'];
  if (cpusets is Map && cpusets['app'] is String) {
    return int.tryParse(run.appCores) ?? 2;
  }
  if (cpus is num) return math.max(1, cpus.round());
  return 2;
}

/// 100 -> "a tenth of a second", 1000 -> "a second", 250 -> "250 ms".
String _msPhrase(num ms) => switch (ms) {
  100 => 'a tenth of a second',
  1000 => 'a second',
  500 => 'half a second',
  _ => '${whole(ms)} ms',
};

/// The limit a reply had to meet, in words: "under a tenth of a second".
String sloPhrase(RunSummary run) {
  final slo = run.params['slo'];
  final p99 = slo is Map && slo['p99_ms'] is num ? slo['p99_ms'] as num : 100;
  return 'under ${_msPhrase(p99)}';
}

/// The most the load tool sent in this run, from the results it capped;
/// null when it never was the limit.
double? toolLimit(RunSummary run) {
  final m = headlineOf(run);
  double? top;
  for (final b in run.backends) {
    for (final r in b.scenarios.values) {
      if (!r.loadgenBound) continue;
      final v = m.value(r);
      if (v != null && (top == null || v > top)) top = v;
    }
  }
  return top;
}

/// The lede under the heading.
String ledeFor(RunSummary run) {
  final n = run.backends.length;
  if (run.isLegacy) {
    final users = run.params['users'];
    final secs = run.params['runtime_s'];
    return 'An older test of the same small API, built in $n frameworks. It '
        'sent ${users is num ? whole(users) : 'thousands of'} simulated users '
        'at each one${secs is num ? ' for ${whole(secs)} seconds' : ''}. Its '
        'result is the average number of requests a second it handled. These '
        'numbers cannot be compared with newer runs.';
  }
  return 'The same small API, built in $n frameworks. We sent each one more '
      'and more requests until its replies got slow. Its result is the most '
      'requests a second it handled while still replying quickly.';
}

/// The points of "How we tested", from the run's own settings.
List<String> howWeTested(RunSummary run) {
  final p = run.params;
  final cores = appCoreCount(run);
  final reps = p['reps'] is num ? (p['reps'] as num).toInt() : null;
  final cpu = run.machine.cpu;
  if (run.isLegacy) {
    return [
      'This run used an older method. A tool called Locust sent '
          '${p['users'] is num ? whole(p['users'] as num) : 'thousands of'} '
          'simulated users at each framework'
          '${p['runtime_s'] is num ? ' for ${whole(p['runtime_s'] as num)} seconds' : ''}.',
      'Each framework had ${numberWord(cores)} processor '
          '${cores == 1 ? 'core' : 'cores'}. There was no limit on how slow '
          'replies could get.',
      'The result is the average number of requests a second it handled.',
      if (reps != null && reps > 1)
        'We ran every test ${numberWord(reps)} times.'
      else
        'Every test ran once, so there is no range of runs.',
      'Everything ran on one $cpu computer. On other machines the numbers '
          'will be different.',
    ];
  }
  final mem = (p['memory'] as Map?)?['app'];
  final memText = mem is String
      ? mem.replaceAllMapped(
          RegExp(r'^(\d+)\s*([gm])b?$', caseSensitive: false),
          (m) => '${m[1]} ${m[2]!.toUpperCase()}B',
        )
      : null;
  final slo = p['slo'] as Map? ?? const {};
  final err = slo['error_rate'] is num ? slo['error_rate'] as num : 0.01;
  final oneIn = err > 0 ? whole(1 / err) : null;
  final seconds = p['step_seconds'] is num
      ? whole(p['step_seconds'] as num)
      : null;
  final limit = toolLimit(run);
  return [
    'Every framework ran the same small API on ${numberWord(cores)} '
        'processor ${cores == 1 ? 'core' : 'cores'}'
        '${memText == null ? '' : ' with $memText of memory'}. A PostgreSQL '
        'database ran beside it on its own cores.',
    'A load tool sent requests at a steady rate'
        '${seconds == null ? '' : ' for $seconds seconds'}, then at a higher '
        'rate, and kept stepping up until replies got slow.',
    'The result is the highest rate at which 99 of every 100 replies still '
        'came back ${sloPhrase(run)}'
        '${oneIn == null ? '' : ', and fewer than 1 in $oneIn failed'}.',
    if (reps != null && reps > 1)
      'We ran every test ${numberWord(reps)} times. The number we show is the '
          'middle run. The lowest and highest runs are shown next to it '
          'wherever you see a range.',
    'When two frameworks\' ranges overlap, we call them too close to call.',
    if (limit != null)
      'The load tool itself has a limit (about '
          '${whole(limit < 1000 ? limit : (limit / 1000).round() * 1000)} '
          'requests a second on this machine). A framework that reached the '
          'limit may really be faster than its number.',
    'Everything ran on one $cpu computer. On other machines the numbers will '
        'be different.',
  ];
}

const kFootLine =
    'Small test apps are not real products. Use these results as a rough '
    'guide, not a verdict.';

// --------------------------------------------------------- every number

/// What the Every number table can show.
enum Measure {
  load('Requests a second', 'the main result'),
  typical('Typical reply time', 'half of all replies were faster than this'),
  slow('Slow reply time', '99 of every 100 replies were faster than this'),
  processor('Processor use', 'how much of its processor cores it used'),
  memory('Memory use', 'how much memory the framework used');

  final String label;
  final String meaning;

  const Measure(this.label, this.meaning);

  /// Short column title: "Typical reply".
  String get short => switch (this) {
    load => 'Requests a second',
    typical => 'Typical reply',
    slow => 'Slow reply',
    processor => 'Processor',
    memory => 'Memory',
  };

  double? value(ScenarioResult r, Metric headline) => switch (this) {
    load => headline.value(r),
    typical => Metrics.p50.value(r),
    slow => Metrics.p99.value(r),
    processor => Metrics.cpu.value(r),
    memory => Metrics.memory.value(r),
  };

  String format(double v, int cores) => switch (this) {
    load => whole(v),
    typical || slow => msText(v),
    processor => cpuText(v, cores),
    memory => memText(v),
  };
}

/// A metric's name in plain words, for the full list of numbers.
String plainMetricLabel(Metric m) => switch (m.id) {
  'sustainable_rps' => 'Requests a second (the result)',
  'peak_rps' => 'Most requests a second at any step',
  'avg_rps' => 'Average requests a second',
  'p50_ms' => 'Typical reply (half were faster)',
  'p90_ms' => '9 in 10 replies were faster than',
  'p99_ms' => 'Slow reply (99 in 100 were faster)',
  'p999_ms' => '999 in 1,000 replies were faster than',
  'error_rate' => 'Requests that failed',
  'app_cpu' => 'Processor (100% is one core)',
  'app_mem_mb' => 'Memory',
  'db_cpu' => 'Database processor (100% is one core)',
  'rps_per_core' => 'Requests a second per core it used',
  'rps_per_100mb' => 'Requests a second per 100 MB of memory',
  _ => m.label,
};

/// "requests a second", or "requests a second, on average" for v1 runs.
String unitFor(Metric headline) => headline == Metrics.avgRps
    ? 'requests a second, on average'
    : 'requests a second';
