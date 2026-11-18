import 'results.dart';
import 'tests.dart';

enum Unit { rps, ms, percent, cpu, mb, ratio, bytes }

/// A number the dashboard can rank, chart and compare.
class Metric {
  final String id;
  final String label;
  final String short;
  final Unit unit;
  final bool higherIsBetter;
  final String help;
  final double? Function(ScenarioResult r) value;

  const Metric({
    required this.id,
    required this.label,
    required this.short,
    required this.unit,
    required this.higherIsBetter,
    required this.help,
    required this.value,
  });

  /// Label with the unit table cells leave out: "Sustainable load (req/s)".
  /// Metrics whose cells carry their unit (ms, %, MB) keep the bare label.
  String get labelWithUnit => switch (unit) {
    Unit.rps || Unit.ratio => '$label (req/s)',
    _ => label,
  };

  /// Whether the metric is a race: more is better and ranking by it is fair
  /// (throughput, efficiency). The others (latency, errors, CPU, memory) are
  /// measured at each framework's own sustainable load, so a framework that
  /// serves less can look better; they are context, not a ranking.
  bool get isRace => higherIsBetter;

  /// Value plus min/max across reps when it is a direct stat.
  Stat? stat(ScenarioResult r) => r.stats[id];
}

double? _stat(ScenarioResult r, String k) => r.stats[k]?.median;

/// Throughput the efficiency metrics are based on: sustainable for v2,
/// average for v1 runs, which had no step load.
double? _throughput(ScenarioResult r) =>
    _stat(r, 'sustainable_rps') ?? _stat(r, 'avg_rps');

class Metrics {
  static final sustainable = Metric(
    id: 'sustainable_rps',
    label: 'Sustainable load',
    short: 'Sustainable',
    unit: Unit.rps,
    higherIsBetter: true,
    help:
        'Highest request rate held with p99 < 100 ms, errors < 1% and ≥ 95% of '
        'requests served. Median of the repetitions.',
    value: (r) => _stat(r, 'sustainable_rps'),
  );
  static final peak = Metric(
    id: 'peak_rps',
    label: 'Peak throughput',
    short: 'Peak',
    unit: Unit.rps,
    higherIsBetter: true,
    help: 'Most requests per second served at any step, regardless of latency.',
    value: (r) => _stat(r, 'peak_rps'),
  );
  static final avgRps = Metric(
    id: 'avg_rps',
    label: 'Average throughput (v1)',
    short: 'Avg rps',
    unit: Unit.rps,
    higherIsBetter: true,
    help: 'v1 method: average requests per second during the user ramp.',
    value: (r) => _stat(r, 'avg_rps'),
  );
  static final p50 = Metric(
    id: 'p50_ms',
    label: 'Median latency',
    short: 'p50',
    unit: Unit.ms,
    higherIsBetter: false,
    help: 'Median response time at the sustainable load.',
    value: (r) => _stat(r, 'p50_ms'),
  );
  static final p90 = Metric(
    id: 'p90_ms',
    label: 'p90 latency',
    short: 'p90',
    unit: Unit.ms,
    higherIsBetter: false,
    help: '90th percentile response time at the sustainable load.',
    value: (r) => _stat(r, 'p90_ms'),
  );
  static final p99 = Metric(
    id: 'p99_ms',
    label: 'p99 latency',
    short: 'p99',
    unit: Unit.ms,
    higherIsBetter: false,
    help: '99th percentile response time at the sustainable load.',
    value: (r) => _stat(r, 'p99_ms'),
  );
  static final p999 = Metric(
    id: 'p999_ms',
    label: 'p99.9 latency',
    short: 'p99.9',
    unit: Unit.ms,
    higherIsBetter: false,
    help: '99.9th percentile response time at the sustainable load.',
    value: (r) => _stat(r, 'p999_ms'),
  );
  static final errors = Metric(
    id: 'error_rate',
    label: 'Error rate',
    short: 'Errors',
    unit: Unit.percent,
    higherIsBetter: false,
    help: 'Share of failed requests at the sustainable load.',
    value: (r) => _stat(r, 'error_rate'),
  );
  static final cpu = Metric(
    id: 'app_cpu',
    label: 'App CPU',
    short: 'CPU',
    unit: Unit.cpu,
    higherIsBetter: false,
    help:
        'How much of its processor cores the app used, on average. 100% is all of them.',
    value: (r) => _stat(r, 'app_cpu'),
  );
  static final memory = Metric(
    id: 'app_mem_mb',
    label: 'App memory',
    short: 'Memory',
    unit: Unit.mb,
    higherIsBetter: false,
    help: 'Average memory of the app container.',
    value: (r) => _stat(r, 'app_mem_mb'),
  );
  static final dbCpu = Metric(
    id: 'db_cpu',
    label: 'Database CPU',
    short: 'DB CPU',
    unit: Unit.cpu,
    higherIsBetter: false,
    help: 'Average CPU of Postgres while serving this backend.',
    value: (r) => _stat(r, 'db_cpu'),
  );
  static final bytesIn = Metric(
    id: 'bytes_in',
    label: 'Bytes a reply',
    short: 'Reply bytes',
    unit: Unit.bytes,
    higherIsBetter: false,
    help:
        'Bytes the testing tool received per request at the result step: '
        'status line, headers and body.',
    value: (r) => _stat(r, 'bytes_in'),
  );
  static final bytesOut = Metric(
    id: 'bytes_out',
    label: 'Bytes a request',
    short: 'Request bytes',
    unit: Unit.bytes,
    higherIsBetter: false,
    help:
        'Bytes the testing tool sent per request at the result step: '
        'request line, headers and body.',
    value: (r) => _stat(r, 'bytes_out'),
  );
  static final rpsPerCore = Metric(
    id: 'rps_per_core',
    label: 'Requests per core',
    short: 'rps/core',
    unit: Unit.ratio,
    higherIsBetter: true,
    help: 'Throughput divided by the cores the app actually used.',
    value: (r) {
      final t = _throughput(r);
      final c = _stat(r, 'app_cpu');
      if (t == null || c == null || c <= 0) return null;
      return t / (c / 100);
    },
  );
  static final rpsPer100Mb = Metric(
    id: 'rps_per_100mb',
    label: 'Requests per 100 MB',
    short: 'rps/100MB',
    unit: Unit.ratio,
    higherIsBetter: true,
    help: 'Throughput divided by app memory, per 100 MB.',
    value: (r) {
      final t = _throughput(r);
      final m = _stat(r, 'app_mem_mb');
      if (t == null || m == null || m <= 0) return null;
      return t / (m / 100);
    },
  );

  /// Leaderboard columns, in order.
  static final table = [
    sustainable,
    avgRps,
    peak,
    p99,
    errors,
    cpu,
    memory,
    rpsPerCore,
  ];

  static final all = [
    sustainable,
    peak,
    avgRps,
    p50,
    p90,
    p99,
    p999,
    errors,
    cpu,
    memory,
    dbCpu,
    rpsPerCore,
    rpsPer100Mb,
    bytesIn,
    bytesOut,
  ];

  static Metric byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => sustainable);

  /// The headline metric a run supports: sustainable (v2) or average (v1).
  static Metric headlineFor(Iterable<ScenarioResult> results) =>
      results.any((r) => sustainable.value(r) != null) ? sustainable : avgRps;

  /// Metrics with at least one value among [results].
  static List<Metric> available(
    Iterable<ScenarioResult> results,
    List<Metric> from,
  ) => from.where((m) => results.any((r) => m.value(r) != null)).toList();
}

/// Short plain name of a test: "Typical app".
String scenarioLabel(String id) => testInfo(id).short;

/// What a test's requests do, in one line.
String scenarioHelp(String id) => testInfo(id).what;
