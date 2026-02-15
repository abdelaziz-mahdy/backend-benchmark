# Serverpod Performance Regression Analysis

## Summary
Performance regression identified in the Serverpod 2.x → 3.x rewrite.
The 3.x architecture rewrote the entire request handling pipeline (raw HttpServer → Relic-based),
adding overhead in session creation, logging, and response construction.

Relic (Serverpod's HTTP server library) was confirmed NOT the cause — bare Relic benchmarks
showed identical performance between v0.4.1 and v0.6.0 (~24,500 req/s).

## Back-to-Back Benchmark Results
All tests run sequentially on the same machine under consistent load conditions.
Config: 10,000 concurrent users, 120s runtime, 1 CPU limit.

### Serverpod 2.1.1 (Dart 3.3.0)
- **no_db_test**: 11215.6 req/s | avg 304.3ms | median 200.0ms | failures: 1972
- **db_test**: 905.0 req/s | avg 4969.2ms | median 4300.0ms | failures: 0

### Serverpod 3.0.0-alpha.1 (Dart 3.5.0) — Run 1
- **no_db_test**: 1803.3 req/s | avg 2663.2ms | median 2600.0ms | failures: 0
- **db_test**: 811.1 req/s | avg 5564.2ms | median 5300.0ms | failures: 0

### Serverpod 3.0.0-alpha.1 (Dart 3.5.0) — Run 2
- **no_db_test**: 1867.1 req/s | avg 2588.6ms | median 2600.0ms | failures: 0
- **db_test**: 870.8 req/s | avg 5162.4ms | median 4900.0ms | failures: 0

### Serverpod 3.3.1 (Dart 3.8.0)
- **no_db_test**: 1661.5 req/s | avg 2880.3ms | median 3000.0ms | failures: 0
- **db_test**: 753.4 req/s | avg 5921.7ms | median 5800.0ms | failures: 0
