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

  /// About the same: each one's middle number falls within the other's
  /// lowest-to-highest tries. (Ranges that merely touch are not enough:
  /// one wide range would otherwise call clearly different bars "the
  /// same".)
  bool overlaps(Result o) =>
      o.low <= value && value <= o.high && low <= o.value && o.value <= high;
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
///
/// Never across the top group's edge: if one is in the tie at the top and
/// the other is not, the answer above the bars already told them apart.
List<Result> closeTo(List<Result> all, Result r) {
  final top = {for (final x in topGroup(all)) x.key};
  final mine = top.contains(r.key);
  return sortResults(
    all.where(
      (o) => o.key != r.key && r.overlaps(o) && top.contains(o.key) == mine,
    ),
  );
}

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
    "It hit our testing tool's limit, so it may be faster than this.";

/// "All three runs gave the same result." / "The three runs ranged from
/// 38,000 to 40,000." / "We ran this test once."
String runsSentence(Result r) {
  if (r.reps <= 1) return 'We ran this test once.';
  final n = numberWord(r.reps);
  if (whole(r.low) == whole(r.high)) {
    return 'All $n tries gave the same result.';
  }
  return 'Across $n tries it ranged from ${whole(r.low)} to ${whole(r.high)}.';
}

/// "Too close to call with A and B." or "".
String closeSentence(List<Result> all, Result r) {
  final c = closeTo(all, r);
  return c.isEmpty ? '' : 'About the same as ${_names(c)}.';
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
  // "About the same" (equal numbers, or a close call by the same rule as
  // the bar's box) is never counted as faster.
  final close = {for (final o in closeTo(all, r)) o.key};
  var more = 0, same = 0;
  for (final o in all) {
    if (o.key == r.key) continue;
    if (o.value == r.value || close.contains(o.key)) {
      same++;
    } else if (o.value > r.value) {
      more++;
    }
  }
  if (n <= 1) return 'The only framework measured here.';
  if (more == 0) {
    if (same == 0) return 'The fastest of the $n.';
    return 'Tied for fastest of the $n, with $same '
        '${same == 1 ? 'other' : 'others'}.';
  }
  if (more == n - 1) return 'The slowest of the $n.';
  final tie = same == 0
      ? ''
      : same == 1
      ? ', and one was about the same'
      : ', and ${numberWord(same)} were about the same';
  if (more == 1) return 'One of the other ${n - 1} was faster$tie.';
  return '${capFirst(numberWord(more))} of the other ${n - 1} were '
      'faster$tie.';
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
      return "${capFirst(c.first.name)} hit our testing tool's limit, so it may be faster.";
    }
    return "${capFirst(_names(c))} all hit our testing tool's limit, so we can't "
        'tell which is fastest.';
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

/// [f] (a share of the fastest, 0..1) in words: "about three-quarters as
/// fast". Readers compare words and bar lengths, not numbers.
String asFast(double f) {
  // "About as fast" would read as a tie, which only overlapping runs are.
  if (f >= 0.85) return 'nearly as fast';
  if (f >= 0.7) return 'about three-quarters as fast';
  if (f >= 0.6) return 'about two-thirds as fast';
  if (f >= 0.42) return 'about half as fast';
  if (f >= 0.3) return 'about a third as fast';
  if (f >= 0.22) return 'about a quarter as fast';
  if (f >= 0.16) return 'about a fifth as fast';
  if (f >= 0.1) return 'about a tenth as fast';
  return 'less than a tenth as fast';
}

/// The frameworks at the top of [results] that cannot be told apart: the
/// fastest, those whose runs overlap it, and, when it hit our testing
/// tool's limit, every other one that hit the limit too. Fastest first.
///
/// With [all] (every framework in the test, when [results] is a few picked
/// ones), the tie is the one the whole test has, so Compare never calls two
/// frameworks "about the same" that Who's fastest tells apart.
List<Result> topGroup(List<Result> results, {List<Result>? all}) {
  final own = _topGroupOf(results);
  if (all == null || own.isEmpty) return own;
  final full = {for (final r in _topGroupOf(all)) r.key};
  if (!full.contains(own.first.key)) return own;
  return [
    for (final r in sortResults(results))
      if (full.contains(r.key)) r,
  ];
}

List<Result> _topGroupOf(List<Result> results) {
  final sorted = sortResults(results);
  if (sorted.isEmpty) return const [];
  final leader = sorted.first;
  bool joins(Result r) =>
      r.value == leader.value ||
      r.overlaps(leader) ||
      (leader.capped && r.capped);
  // Walk down from the top in blocks of equal numbers: a block joins only
  // when every one in it does, so two frameworks with the same number are
  // never split between "about the same" and "next"; the first block that
  // does not join ends the group.
  final out = <Result>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j < sorted.length && sorted[j].value == sorted[i].value) {
      j++;
    }
    final block = sorted.sublist(i, j);
    if (i > 0 && !block.every(joins)) break;
    out.addAll(block);
    i = j;
  }
  return out;
}

/// The answer under a test, in words: who is fastest (or which ones are
/// about the same at the top, the same rule Compare uses) and how the next
/// one compares. Numbers are one tap away on the bars, not in the sentence.
String answerFor(List<Result> results) {
  final (words, limitSaid) = _ranked(results, followers: 1);
  final rs = sortResults(results);
  // The leader's number is a floor when it hit the tool's limit; say so,
  // as Compare does, unless the tie sentence already did.
  if (!limitSaid && rs.isNotEmpty && rs.first.capped) {
    return "$words ${capFirst(rs.first.name)} hit our testing tool's limit, "
        'so it may be faster.';
  }
  return words;
}

/// Who is at the top of [results] in words, then up to [followers] of the
/// rest as a share of the fastest: "Next is B, about half as fast. Then C,
/// about a tenth as fast." The flag says whether it already named the
/// testing tool's limit.
(String, bool) _ranked(
  List<Result> results, {
  required int followers,
  List<Result>? all,
}) {
  if (results.isEmpty) {
    return ('No framework has a result in this test.', false);
  }
  final sorted = sortResults(results);
  final leader = sorted.first;
  if (sorted.length == 1) {
    return ('${capFirst(leader.name)} is the only one.', false);
  }
  final top = {for (final r in topGroup(sorted, all: all)) r.key};
  final tied = [
    for (final r in sorted)
      if (top.contains(r.key)) r,
  ];
  final out = <String>[];
  final limitSaid = tied.length > 1 && tied.every((r) => r.capped);
  if (tied.length > 1) {
    final who = tied.length > 3
        ? '${capFirst(numberWord(tied.length))} frameworks'
        : capFirst(_names(tied));
    out.add(
      limitSaid
          ? "$who tie for fastest at our testing tool's limit, so we can't "
                'tell them apart.'
          : '$who are about the same, the fastest.',
    );
  } else {
    out.add('${capFirst(leader.name)} is the fastest.');
  }
  // The rest in blocks of equal numbers, so frameworks with the same
  // number are named together: "Next are A and B, about half as fast."
  final rest = sorted.where((r) => !top.contains(r.key)).toList();
  final blocks = <List<Result>>[];
  for (final r in rest) {
    if (blocks.isNotEmpty && blocks.last.first.value == r.value) {
      blocks.last.add(r);
    } else {
      blocks.add([r]);
    }
  }
  for (final (i, block) in blocks.take(followers).indexed) {
    final v = block.first.value;
    final how = leader.value <= 0 ? '' : ', ${asFast(v / leader.value)}';
    final who = _names(block);
    out.add(
      i == 0
          ? 'Next ${block.length == 1 ? 'is' : 'are'} $who$how.'
          : 'Then $who$how.',
    );
  }
  return (out.join(' '), limitSaid);
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
) => answerFor(results);

// ---------------------------------------------------------------- compare

/// "one kind of work", "three kinds of work".
String kindsOfWork(int n) => '${numberWord(n)} ${n == 1 ? 'test' : 'tests'}';

/// The comparison's answer in one plain sentence (or two): who handled the
/// most in how many kinds of work, and where it was too close to call.
/// [byTest] holds the picked frameworks' results per test, in test order.
/// [full] holds every framework's results per test, for the tie rule.
String compareVerdict(
  Map<String, List<Result>> byTest, {
  Map<String, List<Result>>? full,
}) {
  final wins = <String, List<String>>{};
  final names = <String, String>{};
  var contested = 0;
  final ties = <List<Result>>[];
  for (final e in byTest.entries) {
    final rs = sortResults(e.value);
    if (rs.length < 2) continue;
    contested++;
    final top = topGroup(rs, all: full?[e.key]);
    if (top.length > 1) {
      ties.add(top);
      continue;
    }
    (wins[rs[0].key] ??= []).add(e.key);
    names[rs[0].key] = rs[0].name;
  }
  if (contested == 0) {
    return 'Pick frameworks that were measured in the same tests.';
  }
  if (wins.isEmpty) {
    return contested == 1
        ? 'They were about the same.'
        : 'They were about the same in every test.';
  }
  final most = wins.values.map((w) => w.length).reduce(math.max);
  final leaders = wins.keys.where((k) => wins[k]!.length == most).toList();
  final close = ties.length;
  // Said the way the test's own sentence says it: "the top three tie at our
  // testing tool's limit", or "the top two were about the same".
  String tieWords(List<Result> t) => t.every((r) => r.capped)
      ? "the top ${numberWord(t.length)} tie at our testing tool's limit"
      : 'the top ${numberWord(t.length)} were about the same';
  final closeNote = close == 0
      ? ''
      : close == 1
      ? ' In one test, ${tieWords(ties.single)}.'
      : ' In ${numberWord(close)} tests, there was a tie at the top.';
  if (leaders.length > 1) {
    return '${capFirst(joinAnd([for (final k in leaders) names[k]!]))} each '
        'were fastest in ${kindsOfWork(most)}.$closeNote';
  }
  final top = leaders.single;
  final head = most == contested
      ? (contested == 1
            ? '${capFirst(names[top]!)} was fastest.'
            : '${capFirst(names[top]!)} was fastest in all '
                  '${kindsOfWork(contested)}.')
      : '${capFirst(names[top]!)} was fastest in ${numberWord(most)} of '
            'the ${kindsOfWork(contested)}.';
  final others = [
    for (final e in wins.entries)
      if (e.key != top)
        '${capFirst(names[e.key]!)} led in '
            '${joinAnd([for (final t in e.value) testInfo(t).inSentence])}.',
  ];
  return [head, ...others].join(' ') + closeNote;
}

/// One test of a comparison in words, with no numbers: who is at the top
/// and how far behind each of the others is, as a share of the fastest.
String compareTestSentence(List<Result> results, {List<Result>? all}) {
  final rs = sortResults(results);
  if (rs.isEmpty) return 'None of them was measured here.';
  if (rs.length == 1) return 'Only ${rs.first.name} was measured here.';
  final capped = rs.where((r) => r.capped).toList();
  final (words, limitSaid) = _ranked(rs, followers: rs.length, all: all);
  return [
    words,
    if (capped.isNotEmpty && !limitSaid)
      "${capFirst(_names(capped))} hit our testing tool's limit, so "
          "${capped.length == 1 ? 'it' : 'they'} may be faster.",
  ].join(' ');
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

/// "95%": the share of the requests sent that a step must answer to pass.
String keptUp(RunSummary run) {
  final slo = run.params['slo'];
  final r = slo is Map && slo['achieved_ratio'] is num
      ? (slo['achieved_ratio'] as num).toDouble()
      : 0.95;
  return '${(r * 100).round()}%';
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
    return 'An older test of the same small app, built in $n frameworks. It '
        'sent ${users is num ? whole(users) : 'thousands of'} simulated users '
        'at each one${secs is num ? ' for ${whole(secs)} seconds' : ''}. Its '
        'result is the average number of requests a second it handled. These '
        'numbers cannot be compared with newer runs.';
  }
  return 'We built the same small app in $n frameworks and sent each one '
      'more and more traffic until it slowed down. Each number is the most '
      'requests a second it handled before that.';
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
        'Every test ran once, so there is no range of tries.',
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
    'Every framework ran the same small app on ${numberWord(cores)} '
        'processor ${cores == 1 ? 'core' : 'cores'}'
        '${memText == null ? '' : ' with $memText of memory'}. A PostgreSQL '
        'database ran beside it on its own cores.',
    'Our testing tool sent requests at a steady rate'
        '${seconds == null ? '' : ' for $seconds seconds'}, then at a higher '
        'rate, and kept stepping up until replies got slow.',
    'The result is the highest rate at which 99 of every 100 replies still '
        'came back ${sloPhrase(run)}'
        '${oneIn == null ? '' : ', fewer than 1 in $oneIn failed'}, and it '
        'kept up with at least ${keptUp(run)} of the requests sent.',
    if (reps != null && reps > 1)
      'We tried every test ${numberWord(reps)} times. The number we show is '
          'the middle try. The lowest and highest tries are shown next to it '
          'wherever you see a range.',
    'We call two frameworks about the same when each one\'s middle try '
        "falls inside the other's lowest-to-highest tries.",
    if (limit != null)
      "Our testing tool has its own limit: up to about "
          '${whole(limit < 1000 ? limit : (limit / 1000).round() * 1000)} '
          'requests a second on this computer, and less in the tests that use '
          'the database, where it has more work per request. A framework that '
          'hit the limit may really be faster than its number.',
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
  // The same names as every other table and Method's "Words we use".
  load('Requests a second', 'the main result'),
  typical('Typical reply', 'half of all replies were faster than this'),
  slow('Slow reply', '99 of every 100 replies were faster than this'),
  processor('Processor', 'how much of its processor cores it used'),
  memory('Memory', 'how much memory the framework used');

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
  'app_cpu' => 'Processor (share of its cores)',
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

/// What a measured number means, in plain words, for tooltips next to a
/// number's name.
String metricMeaning(Metric m, RunSummary run) {
  final cores = appCoreCount(run);
  return switch (m.id) {
    'sustainable_rps' =>
      'The main result: the busiest step it passed while 99 of every 100 '
          'replies came back ${sloPhrase(run)}, fewer than 1 in 100 failed '
          'and it kept up with at least ${keptUp(run)} of the requests. '
          'Higher is better.',
    'peak_rps' =>
      'The most requests a second it answered at any step, however slow the '
          'replies were. Higher is better.',
    'avg_rps' =>
      'Old method: the average requests a second while more and more '
          'visitors were added. Higher is better.',
    'p50_ms' =>
      'Typical reply: half of all replies came back faster than this.',
    'p90_ms' => '9 in 10 replies came back faster than this.',
    'p99_ms' => 'Slow reply: 99 of every 100 replies came back within this.',
    'p999_ms' => '999 of every 1,000 replies came back within this.',
    'error_rate' => 'The share of requests that failed.',
    'app_cpu' =>
      'How much of its ${numberWord(cores)} processor '
          '${cores == 1 ? 'core' : 'cores'} the app used. 100% is '
          '${cores == 1 ? 'that core' : 'all of them'}.',
    'app_mem_mb' => 'How much memory the app used.',
    'db_cpu' =>
      "How much processor the database used while serving this framework. "
          '100% is one core.',
    'rps_per_core' =>
      'Requests a second for each processor core it really used.',
    'rps_per_100mb' => 'Requests a second for every 100 MB of memory it used.',
    _ => plainMetricLabel(m),
  };
}
