import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/contributions.dart';
import '../models/results.dart';

/// Loads the generated dashboard data from assets/results/.
class ResultsService {
  final AssetBundle bundle;
  final _runs = <String, Future<RunSummary>>{};

  ResultsService([AssetBundle? bundle]) : bundle = bundle ?? rootBundle;

  static const _base = 'assets/results';

  Future<List<RunIndexEntry>> loadIndex() async {
    final raw = await bundle.loadString('$_base/index.json', cache: false);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return [
      ...?(json['runs'] as List?)?.whereType<Map<String, dynamic>>().map(
        RunIndexEntry.fromJson,
      ),
    ];
  }

  /// Run summaries are loaded on demand and cached; a failed load is not
  /// kept, so picking the run again tries again.
  Future<RunSummary> loadRun(RunIndexEntry entry) {
    final cached = _runs[entry.id];
    if (cached != null) return cached;
    final load = () async {
      final raw = await bundle.loadString('$_base/${entry.file}', cache: false);
      return RunSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }();
    _runs[entry.id] = load;
    unawaited(
      load.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_runs[entry.id], load)) _runs.remove(entry.id);
        },
      ),
    );
    return load;
  }

  /// The Contributions page's list, newest first.
  Future<List<Contribution>> loadContributions() async {
    final raw = await bundle.loadString(
      '$_base/contributions.json',
      cache: false,
    );
    return Contribution.listFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
