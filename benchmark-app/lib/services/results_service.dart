import 'dart:convert';

import 'package:flutter/services.dart';

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

  /// Run summaries are loaded on demand and cached.
  Future<RunSummary> loadRun(RunIndexEntry entry) => _runs.putIfAbsent(
    entry.id,
    () async {
      final raw = await bundle.loadString('$_base/${entry.file}', cache: false);
      return RunSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    },
  );
}
