import 'dart:io';

import 'package:relic/relic.dart';
import 'package:relic_native/relic_native.dart';

/// Relic 2: `relic_io` through `serve`, or the native adapter added in 2.0
/// through `serveNative`. The Dockerfile swaps in serve_v1.dart for 1.x.
Future<void> start(
  RelicApp app, {
  required bool native,
  required int isolates,
}) {
  final address = InternetAddress.anyIPv4;
  return native
      ? app.serveNative(address: address, port: 8000, noOfIsolates: isolates)
      : app.serve(address: address, port: 8000, noOfIsolates: isolates);
}
