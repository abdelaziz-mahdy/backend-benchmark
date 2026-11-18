// Every run names the tool that sent its load: the method changed tools
// twice, and numbers from different tools must not read as the same kind.

import 'package:benchmark_app/models/results.dart';
import 'package:benchmark_app/widgets/run_switcher.dart';
import 'package:flutter_test/flutter_test.dart';

RunIndexEntry _entry(String methodology) => RunIndexEntry.fromJson({
  'id': 'r',
  'kind': 'run',
  'date': '2026-11-18',
  'methodology': methodology,
  'backends': ['a'],
  'file': 'runs/r.json',
});

void main() {
  test('each method names its load tool', () {
    expect(loadTool('v1'), 'Locust');
    expect(loadTool('v2'), 'k6');
    expect(loadTool('v2.1'), 'k6');
    expect(loadTool('v3'), 'vegeta');
  });

  test('the run lists show the load tool', () {
    expect(runDetail(_entry('v2.1')), contains('load from k6'));
    expect(runDetail(_entry('v3')), contains('load from vegeta'));
  });
}
