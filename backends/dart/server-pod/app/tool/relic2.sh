#!/bin/sh
# Builds the Relic 2.0.0 variants of the Serverpod benchmark (see
# backend.yaml). Serverpod 4.1.1 pins relic 2.0.0-rc.4 and serves through
# relic_io; these variants move it to the final 2.0.0 release:
#   relic-2.0.0         relic, relic_core and relic_io overridden to 2.0.0
#   relic-native-2.0.0  the same, plus Serverpod patched to start Relic's
#                       native adapter (app.serveNative) instead of
#                       app.serve: Serverpod has no option to choose it.
#   relic-native-fixed-2.0.0  the same, with relic_native's drain fix
#                       (patches/, tool/fix_native.sh).
# Any other variant leaves the app untouched.
set -eu
variant="$1"
case "$variant" in
  relic-2.0.0 | relic-native-2.0.0 | relic-native-fixed-2.0.0) ;;
  *) exit 0 ;;
esac
cat >> pubspec.yaml <<'YAML'

dependency_overrides:
  relic: 2.0.0
  relic_core: 2.0.0
  relic_io: 2.0.0
YAML
if [ "$variant" != relic-2.0.0 ]; then
  # Vendor the pinned Serverpod and patch its server start.
  dart pub get
  src="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/serverpod-4.1.1"
  mkdir -p vendor && cp -R "$src" vendor/serverpod
  f=vendor/serverpod/lib/src/server/server.dart
  perl -0pi -e "s/final server = await _app\.serve\(\s*address: io\.InternetAddress\.anyIPv6,\s*port: port,\s*securityContext: _securityContext,\s*\);/\/\/ Benchmark patch: relic_native instead of relic_io.\n      final server = await _app.serveNative(\n        address: io.InternetAddress.anyIPv4,\n        port: port,\n      );/" "$f"
  grep -q "_app.serveNative(" "$f" || { echo "relic2.sh: serve() call not found in $f" >&2; exit 1; }
  perl -0pi -e "s/(import 'package:serverpod\/serverpod.dart';)/\$1\nimport 'package:relic_native\/relic_native.dart';/" "$f"
  perl -0pi -e "s/  relic: 2\.0\.0-rc\.4/  relic: 2.0.0\n  relic_native: 2.0.0/" vendor/serverpod/pubspec.yaml
  grep -q "relic_native: 2.0.0" vendor/serverpod/pubspec.yaml || { echo "relic2.sh: relic pin not found" >&2; exit 1; }
  cat >> pubspec.yaml <<'YAML'
  serverpod:
    path: vendor/serverpod
YAML
  if [ "$variant" = relic-native-fixed-2.0.0 ]; then
    # relic_native with the drain fix (patches/, tool/fix_native.sh).
    sh tool/fix_native.sh
    printf '  relic_native:\n    path: vendor/relic_native\n' >> pubspec.yaml
  else
    printf '  relic_native: 2.0.0\n' >> pubspec.yaml
  fi
fi
rm -f pubspec.lock
