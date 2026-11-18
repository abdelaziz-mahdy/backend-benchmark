#!/bin/sh
# Vendors relic_native 2.0.0 from the pub cache into vendor/relic_native and
# applies patches/relic_native-park-while-in-flight.patch: the drain parks
# instead of lingering while handlers are still at work, so their I/O (a
# database reply) is not held behind a 1 ms kernel wait. Run after
# `dart pub get`; the caller adds the path override.
set -eu
dart pub cache add relic_native --version 2.0.0 >/dev/null
src="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/relic_native-2.0.0"
mkdir -p vendor
cp -R "$src" vendor/relic_native
(cd vendor/relic_native && git apply ../../patches/relic_native-park-while-in-flight.patch)
grep -q "_inFlight.isNotEmpty" vendor/relic_native/lib/src/native_adapter.dart
