import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/benchmark_data.dart';

class DataService {
  static Future<Map<String, BenchmarkService>> loadData() async {
    final jsonString = await rootBundle.loadString('assets/data.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final result = <String, BenchmarkService>{};

    for (final entry in jsonData.entries) {
      result[entry.key] = BenchmarkService.fromJson(
        entry.key,
        entry.value as Map<String, dynamic>,
      );
    }

    return result;
  }
}
