import 'dart:io';

import 'package:relic/relic.dart';

/// Relic 1.x has only `relic_io`; the native adapter arrived in 2.0.
Future<void> start(
  RelicApp app, {
  required bool native,
  required int isolates,
}) {
  if (native) throw UnsupportedError('relic_native needs Relic 2');
  return app.serve(
    address: InternetAddress.anyIPv4,
    port: 8000,
    noOfIsolates: isolates,
  );
}
