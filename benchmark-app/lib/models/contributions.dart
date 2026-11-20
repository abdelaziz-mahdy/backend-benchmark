/// Work in other projects that came out of the benchmark, from
/// assets/results/contributions.json (built from docs/contributions.yaml).
class Contribution {
  final String title;
  final String repo;
  final String project;
  final int stars;
  final DateTime date;
  final String summary;
  final List<ContributionLink> links;
  final List<BeforeAfter> numbers;
  final String? note;

  const Contribution({
    required this.title,
    required this.repo,
    required this.project,
    required this.stars,
    required this.date,
    required this.summary,
    required this.links,
    required this.numbers,
    this.note,
  });

  String get repoUrl => 'https://github.com/$repo';

  factory Contribution.fromJson(Map<String, dynamic> j) => Contribution(
    title: j['title'] as String,
    repo: j['repo'] as String,
    project: j['project'] as String,
    stars: (j['stars'] as num).toInt(),
    date: DateTime.parse(j['date'] as String),
    summary: j['summary'] as String,
    links: [
      for (final l in (j['links'] as List).cast<Map<String, dynamic>>())
        ContributionLink.fromJson(l),
    ],
    numbers: [
      for (final n
          in ((j['numbers'] as List?) ?? const []).cast<Map<String, dynamic>>())
        BeforeAfter.fromJson(n),
    ],
    note: j['note'] as String?,
  );

  /// Newest first, as the page lists them.
  static List<Contribution> listFromJson(Map<String, dynamic> j) {
    final list = [
      for (final e
          in ((j['contributions'] as List?) ?? const [])
              .cast<Map<String, dynamic>>())
        Contribution.fromJson(e),
    ];
    // Newest first; the file's order breaks ties.
    final order = {for (var i = 0; i < list.length; i++) list[i]: i};
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : order[a]!.compareTo(order[b]!);
    });
    return list;
  }
}

enum LinkState {
  open('Open'),
  merged('Merged'),
  closed('Closed');

  final String label;

  const LinkState(this.label);

  static LinkState parse(String s) =>
      values.firstWhere((v) => v.name == s, orElse: () => LinkState.open);
}

/// An issue, a pull request or a Gerrit change.
class ContributionLink {
  final String kind;
  final int number;
  final String url;
  final LinkState state;

  /// Who wrote it, when not the benchmark's author (a maintainer's fix that
  /// a closed pull request led to).
  final String? by;

  const ContributionLink({
    required this.kind,
    required this.number,
    required this.url,
    required this.state,
    this.by,
  });

  factory ContributionLink.fromJson(Map<String, dynamic> j) => ContributionLink(
    kind: j['kind'] as String,
    number: (j['number'] as num).toInt(),
    url: j['url'] as String,
    state: LinkState.parse(j['state'] as String),
    by: j['by'] as String?,
  );

  /// "Issue #445", "Pull request #446", "Change 577480".
  String get label => switch (kind) {
    'issue' => 'Issue #$number',
    'pr' => 'Pull request #$number',
    _ => 'Change $number',
  };
}

/// A measured effect: the number before the change and with it.
class BeforeAfter {
  final String label;
  final double before;
  final double after;
  final String unit;

  const BeforeAfter({
    required this.label,
    required this.before,
    required this.after,
    required this.unit,
  });

  factory BeforeAfter.fromJson(Map<String, dynamic> j) => BeforeAfter(
    label: j['label'] as String,
    before: (j['before'] as num).toDouble(),
    after: (j['after'] as num).toDouble(),
    unit: j['unit'] as String,
  );

  /// "13.8× as many", "+27%" or "-23%".
  String get change {
    final ratio = after / before;
    if (ratio >= 2) {
      final x = ratio >= 10
          ? ratio.round().toString()
          : ratio.toStringAsFixed(1);
      return '$x× as many';
    }
    final pct = ((ratio - 1) * 100).round();
    return pct >= 0 ? '+$pct%' : '−${-pct}%';
  }
}
