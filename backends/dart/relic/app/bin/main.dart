import 'dart:io';

import 'package:relic_bench/notes.dart';
import 'package:relic_bench/serve.dart';

Future<void> main() async {
  // native, or native-fixed (relic_native with the drain fix, see patches/).
  final native =
      Platform.environment['BENCH_VARIANT']?.startsWith('native') ?? false;
  await start(buildApp(), native: native, isolates: isolates);
  stdout.writeln(
    'Relic serving on port 8000 (${native ? 'native' : 'io'}, $isolates isolates)',
  );
}
