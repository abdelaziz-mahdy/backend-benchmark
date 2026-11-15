// Data model for the files written by bench/report/report.py:
// assets/results/index.json and assets/results/runs/<id>.json.

import 'tests.dart';

double? _num(Object? v) => v is num ? v.toDouble() : null;

/// Median with the spread across repetitions.
class Stat {
  final double median;
  final double min;
  final double max;

  const Stat(this.median, this.min, this.max);

  static Stat? fromJson(Object? json) {
    if (json is! Map) return null;
    final median = _num(json['median']);
    if (median == null) return null;
    return Stat(
      median,
      _num(json['min']) ?? median,
      _num(json['max']) ?? median,
    );
  }
}

class Machine {
  final String slug;
  final String cpu;
  final int cores;
  final int ramGb;

  const Machine({
    required this.slug,
    required this.cpu,
    required this.cores,
    required this.ramGb,
  });

  factory Machine.fromJson(Map<String, dynamic>? json) => Machine(
    slug: json?['slug'] as String? ?? 'unknown',
    cpu: json?['cpu'] as String? ?? 'unknown CPU',
    cores: (json?['cores'] as num?)?.toInt() ?? 0,
    ramGb: (json?['ram_gb'] as num?)?.toInt() ?? 0,
  );

  String get label => '$cpu · $cores cores · $ramGb GB';
}

enum RunKind { latest, run, legacy }

RunKind _kind(String? s) => switch (s) {
  'latest' => RunKind.latest,
  'legacy' => RunKind.legacy,
  _ => RunKind.run,
};

/// One entry of index.json: enough to list runs and draw History.
class RunIndexEntry {
  final String id;
  final RunKind kind;
  final String? date;
  final Machine machine;
  final String methodology;
  final bool dirty;
  final String? contributor;
  final List<String> backends;
  final List<String> scenarios;
  final List<String> runs;
  final Map<String, String> names;
  final String file;

  /// backend key -> scenario -> metric -> median.
  final Map<String, Map<String, Map<String, double>>> headline;

  const RunIndexEntry({
    required this.id,
    required this.kind,
    required this.date,
    required this.machine,
    required this.methodology,
    required this.dirty,
    required this.contributor,
    required this.backends,
    required this.scenarios,
    required this.runs,
    required this.names,
    required this.file,
    required this.headline,
  });

  factory RunIndexEntry.fromJson(Map<String, dynamic> json) {
    final headline = <String, Map<String, Map<String, double>>>{};
    final raw = json['headline'];
    if (raw is Map) {
      raw.forEach((backend, scenarios) {
        if (scenarios is! Map) return;
        final perScenario = <String, Map<String, double>>{};
        scenarios.forEach((scenario, metrics) {
          if (metrics is! Map) return;
          final values = <String, double>{};
          metrics.forEach((k, v) {
            final n = _num(v);
            if (n != null) values[k as String] = n;
          });
          perScenario[scenario as String] = values;
        });
        headline[backend as String] = perScenario;
      });
    }
    return RunIndexEntry(
      id: json['id'] as String,
      kind: _kind(json['kind'] as String?),
      date: json['date'] as String?,
      machine: Machine.fromJson(json['machine'] as Map<String, dynamic>?),
      methodology: json['methodology'] as String? ?? 'v2',
      dirty: json['dirty'] == true,
      contributor: json['contributor'] as String?,
      backends: [...?(json['backends'] as List?)?.cast<String>()],
      scenarios: [...?(json['scenarios'] as List?)?.cast<String>()],
      runs: [...?(json['runs'] as List?)?.cast<String>()],
      names: {...?(json['names'] as Map?)?.cast<String, String>()},
      file: json['file'] as String,
      headline: headline,
    );
  }

  /// Runs are comparable only on the same machine with the same method.
  String get groupKey => '${machine.slug}|$methodology';

  bool get isLegacy => methodology == 'v1';
}

/// One load step: target rate and what the backend delivered.
class LoadStep {
  final double targetRps;
  final double achievedRps;
  final double errorRate;
  final double p50;
  final double p90;
  final double p99;
  final double p999;
  final double? appCpu;
  final double? appMemMb;
  final bool pass;
  final bool k6Bound;
  final bool refine;

  const LoadStep({
    required this.targetRps,
    required this.achievedRps,
    required this.errorRate,
    required this.p50,
    required this.p90,
    required this.p99,
    required this.p999,
    required this.appCpu,
    required this.appMemMb,
    required this.pass,
    required this.k6Bound,
    required this.refine,
  });

  factory LoadStep.fromJson(Map<String, dynamic> j) => LoadStep(
    targetRps: _num(j['target_rps']) ?? 0,
    achievedRps: _num(j['achieved_rps']) ?? 0,
    errorRate: _num(j['error_rate']) ?? 0,
    p50: _num(j['p50_ms']) ?? 0,
    p90: _num(j['p90_ms']) ?? 0,
    p99: _num(j['p99_ms']) ?? 0,
    p999: _num(j['p999_ms']) ?? 0,
    appCpu: _num(j['app_cpu']),
    appMemMb: _num(j['app_mem_mb']),
    pass: j['pass'] == true,
    k6Bound: j['k6_bound'] == true,
    refine: j['refine'] == true,
  );
}

/// Column-oriented time series ("t" plus one list per series).
class TimeSeries {
  final List<double> t;
  final Map<String, List<double?>> series;

  const TimeSeries(this.t, this.series);

  static const empty = TimeSeries([], {});

  factory TimeSeries.fromJson(Object? json) {
    if (json is! Map) return empty;
    final t = [...?(json['t'] as List?)?.map((v) => _num(v) ?? 0)];
    final series = <String, List<double?>>{};
    json.forEach((k, v) {
      if (k == 't' || v is! List) return;
      series[k as String] = v.map(_num).toList();
    });
    return TimeSeries(t, series);
  }

  bool get isEmpty => t.isEmpty;
}

class ScenarioResult {
  final int reps;
  final Map<String, Stat> stats;
  final double spread;
  final bool unstable;
  final bool loadgenBound;

  /// Times the app had to be restarted because it did not recover from an
  /// overloaded step (all repetitions together).
  final int restarts;
  final List<LoadStep> steps;
  final TimeSeries timeseries;
  final String? fromRun;

  const ScenarioResult({
    required this.reps,
    required this.stats,
    required this.spread,
    required this.unstable,
    required this.loadgenBound,
    this.restarts = 0,
    required this.steps,
    required this.timeseries,
    required this.fromRun,
  });

  static const statKeys = [
    'sustainable_rps',
    'peak_rps',
    'avg_rps',
    'p50_ms',
    'p90_ms',
    'p99_ms',
    'p999_ms',
    'error_rate',
    'app_cpu',
    'app_mem_mb',
    'db_cpu',
    'db_mem_mb',
  ];

  factory ScenarioResult.fromJson(Map<String, dynamic> j) {
    final stats = <String, Stat>{};
    for (final k in statKeys) {
      final s = Stat.fromJson(j[k]);
      if (s != null) stats[k] = s;
    }
    return ScenarioResult(
      reps: (j['reps'] as num?)?.toInt() ?? 0,
      stats: stats,
      spread: _num(j['spread']) ?? 0,
      unstable: j['unstable'] == true,
      loadgenBound: j['loadgen_bound'] == true,
      restarts: (j['restarts'] as num?)?.toInt() ?? 0,
      steps: [
        ...?(j['steps'] as List?)?.whereType<Map<String, dynamic>>().map(
          LoadStep.fromJson,
        ),
      ],
      timeseries: TimeSeries.fromJson(j['timeseries']),
      fromRun: j['from_run'] as String?,
    );
  }
}

/// How a backend is run and talks to its database (backend.yaml
/// `implementation`). Four short free-text facts; any may be missing.
class Implementation {
  final String? server;
  final String? concurrency;
  final String? dbAccess;
  final String? pool;

  const Implementation({
    this.server,
    this.concurrency,
    this.dbAccess,
    this.pool,
  });

  static Implementation? fromJson(Object? json) {
    if (json is! Map) return null;
    String? s(String k) {
      final v = json[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final impl = Implementation(
      server: s('server'),
      concurrency: s('concurrency'),
      dbAccess: s('db_access'),
      pool: s('pool'),
    );
    return impl.isEmpty ? null : impl;
  }

  bool get isEmpty =>
      server == null && concurrency == null && dbAccess == null && pool == null;
}

const kRepoUrl = 'https://github.com/abdelaziz-mahdy/backend-benchmark';

class BackendResult {
  final String key;
  final String name;
  final String language;
  final String? framework;
  final String? version;
  final String? runtime;
  final String? variant;
  final String? db;
  final bool pgbouncer;
  final String? notes;
  final String status;

  /// `backends/<lang>/<fw>` folder, when the backend still exists.
  final String? path;
  final String apiStyle;
  final Implementation? implementation;

  /// "run" when recorded with the run, "manifest" when report.py filled it
  /// from the current source because the run predates the field.
  final String? implementationFrom;
  final Map<String, ScenarioResult> scenarios;

  /// The name this backend had in the run's own files, when the dashboard
  /// shows today's name instead (v1 results used slug-like names).
  final String? formerName;

  const BackendResult({
    required this.key,
    required this.name,
    required this.language,
    required this.framework,
    required this.version,
    required this.runtime,
    required this.variant,
    required this.db,
    required this.pgbouncer,
    required this.notes,
    required this.status,
    required this.path,
    required this.apiStyle,
    required this.implementation,
    required this.implementationFrom,
    required this.scenarios,
    this.formerName,
  });

  /// The same backend shown under [newName]; numbers are untouched.
  BackendResult renamed(String newName) => newName == name
      ? this
      : BackendResult(
          key: key,
          name: newName,
          language: language,
          framework: framework,
          version: version,
          runtime: runtime,
          variant: variant,
          db: db,
          pgbouncer: pgbouncer,
          notes: notes,
          status: status,
          path: path,
          apiStyle: apiStyle,
          implementation: implementation,
          implementationFrom: implementationFrom,
          scenarios: scenarios,
          formerName: name,
        );

  factory BackendResult.fromJson(Map<String, dynamic> j) {
    final scenarios = <String, ScenarioResult>{};
    final raw = j['scenarios'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          scenarios[k as String] = ScenarioResult.fromJson(v);
        }
      });
    }
    return BackendResult(
      key: j['key'] as String,
      name: j['name'] as String? ?? j['key'] as String,
      language: j['language'] as String? ?? 'other',
      framework: j['framework'] as String?,
      version: j['version'] as String?,
      runtime: j['runtime'] as String?,
      variant: j['variant'] as String?,
      db: j['db'] as String?,
      pgbouncer: j['pgbouncer'] == true,
      notes: j['notes'] as String?,
      status: j['status'] as String? ?? 'unknown',
      path: j['path'] as String?,
      apiStyle: j['api_style'] as String? ?? 'rest',
      implementation: Implementation.fromJson(j['implementation']),
      implementationFrom: j['implementation_from'] as String?,
      scenarios: scenarios,
    );
  }

  /// Source folder on GitHub (main branch), when the backend still exists.
  String? get sourceUrl =>
      path == null ? null : '$kRepoUrl/tree/main/backends/$path';

  /// Same folder at the commit the run was made from.
  String? sourceUrlAt(String? sha) =>
      path == null || sha == null ? null : '$kRepoUrl/tree/$sha/backends/$path';

  /// How the test calls it, in plain words.
  String get apiLabel => switch (apiStyle) {
    'serverpod_rpc' => "Serverpod's own calls (RPC)",
    'foam_rpc' => "FOAM's own calls (RPC)",
    'rest' => 'Plain web requests (JSON)',
    _ => apiStyle,
  };

  /// Where it keeps its data, in plain words.
  String get storageLabel => switch (db) {
    'none' => 'Its own storage, no database',
    'postgres' =>
      pgbouncer
          ? 'PostgreSQL, through a connection sharer (PgBouncer)'
          : 'PostgreSQL',
    null => 'Not recorded',
    _ => db!,
  };

  /// "serverpod 4.0.3 on dart 3.13": the one way versions are written.
  String? get versionLine {
    if (version == null && runtime == null) return null;
    return [
      if (version != null) '${framework ?? name} $version',
      if (runtime != null) version == null ? runtime! : 'on $runtime',
    ].join(' ');
  }

  /// How it is built, with one set of labels for the profile card and
  /// Compare. Values may be null when not recorded.
  List<(String, String?)> get builtFacts => [
    ('Web server', _plain(implementation?.server)),
    ('How it handles many requests', _plain(implementation?.concurrency)),
    ('Database access', _plain(implementation?.dbAccess)),
    ('Database connections', _plain(implementation?.pool)),
    ('How it is called', apiLabel),
    ('Storage', storageLabel),
    ('Versions', versionLine),
  ];

  /// Drops setting names in brackets, "20 (database.maxConnectionCount)"
  /// -> "20": they mean nothing to a reader.
  static String? _plain(String? v) => v
      ?.replaceAll(RegExp(r'\s*\((?:[A-Za-z0-9_-]+\.)+[A-Za-z0-9_-]+\)'), '')
      .trim();

  /// Text used by the finder: name, language, framework, runtime, key.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      name,
      language,
      ?framework,
      ?runtime,
      key,
      ?variant,
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }
}

class RunSummary {
  final String id;
  final RunKind kind;
  final String? date;
  final Machine machine;
  final String methodology;
  final bool dirty;
  final String? gitSha;
  final String? contributor;
  final Map<String, dynamic> params;
  final Map<String, dynamic> docker;
  final List<BackendResult> backends;

  const RunSummary({
    required this.id,
    required this.kind,
    required this.date,
    required this.machine,
    required this.methodology,
    required this.dirty,
    required this.gitSha,
    required this.contributor,
    required this.params,
    required this.docker,
    required this.backends,
  });

  factory RunSummary.fromJson(Map<String, dynamic> j) => RunSummary(
    id: j['id'] as String,
    kind: _kind(j['kind'] as String?),
    date: j['date'] as String?,
    machine: Machine.fromJson(j['machine'] as Map<String, dynamic>?),
    methodology: j['methodology'] as String? ?? 'v2',
    dirty: j['dirty'] == true,
    gitSha: j['git_sha'] as String?,
    contributor: j['contributor'] as String?,
    params: (j['params'] as Map<String, dynamic>?) ?? const {},
    docker: (j['docker'] as Map<String, dynamic>?) ?? const {},
    backends: [
      ...?(j['backends'] as List?)?.whereType<Map<String, dynamic>>().map(
        BackendResult.fromJson,
      ),
    ],
  );

  List<String> get scenarios {
    final all = {for (final b in backends) ...b.scenarios.keys};
    const order = kTestOrder;
    return [
      ...order.where(all.contains),
      ...all.where((s) => !order.contains(s)).toList()..sort(),
    ];
  }

  /// This run with its backends replaced (e.g. renamed for display).
  RunSummary withBackends(List<BackendResult> next) => RunSummary(
    id: id,
    kind: kind,
    date: date,
    machine: machine,
    methodology: methodology,
    dirty: dirty,
    gitSha: gitSha,
    contributor: contributor,
    params: params,
    docker: docker,
    backends: next,
  );

  BackendResult? backend(String key) {
    for (final b in backends) {
      if (b.key == key) return b;
    }
    return null;
  }

  bool get isLegacy => methodology == 'v1';

  /// Cores pinned to each app, from the "0-1" cpuset; "2" when unknown.
  String get appCores {
    final cpusets = params['cpusets'] as Map? ?? const {};
    final cpuset = cpusets['app'];
    if (cpuset is! String) return '2';
    final m = RegExp(r'^(\d+)-(\d+)$').firstMatch(cpuset);
    if (m == null) return cpuset;
    return '${int.parse(m[2]!) - int.parse(m[1]!) + 1}';
  }

  /// Repetitions per scenario.
  Object get reps => params['reps'] ?? 3;
}
