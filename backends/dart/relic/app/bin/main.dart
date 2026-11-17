import 'dart:io';

import 'package:relic_bench/notes.dart';
import 'package:relic_bench/serve.dart';

Future<void> main() async {
  final native = Platform.environment['BENCH_VARIANT'] == 'native';
  await start(buildApp(), native: native, isolates: isolates);
  stdout.writeln(
    'Relic serving on port 8000 (${native ? 'native' : 'io'}, $isolates isolates)',
  );
}
