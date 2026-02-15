# Serverpod Performance Regression: Binary Search Results

## Goal
Identify the exact Serverpod version where performance regressed between 3.0.0-alpha.1 (fast) and 3.3.1 (slow).

## Known Baselines

### Serverpod 3.0.0-alpha.1 (Dart 3.5.0) - KNOWN FAST
- **no_db_test**: 16,421.0 req/s | avg 218.0ms | median 110.0ms | failures: 0
- **db_test**: 1,774.0 req/s | avg 2,713.0ms | median 2,200.0ms | failures: 0

### Serverpod 3.3.1 (Dart 3.8.0) - KNOWN SLOW
- **no_db_test**: 1,614.6 req/s | avg 2,959.1ms | median 3,000.0ms | failures: 0
- **db_test**: 745.5 req/s | avg 6,180.5ms | median 6,400.0ms | failures: 0

## Binary Search Progress

| Round | Version | Dart SDK | no_db req/s | db req/s | Verdict |
|-------|---------|----------|-------------|----------|---------|
| base  | 3.0.0-alpha.1 | 3.5.0 | 16,421 | 1,774 | FAST |
| base  | 3.3.1 | 3.8.0 | 1,615 | 745 | SLOW |
| 1     | 3.0.0 | 3.8.0 | 1,618 | 725 | SLOW |
| 2     | 3.0.0-rc.1 | 3.8.0 | 1,747 | 818 | SLOW |
| 3     | 3.0.0-alpha.2 | 3.5.0 | 1,791 | 856 | SLOW |

## Conclusion

**The regression was introduced between 3.0.0-alpha.1 and 3.0.0-alpha.2.**

- NOT a Dart SDK issue (alpha.2 uses the same Dart 3.5.0 as alpha.1)
- Both no_db_test and db_test regress at the same version boundary (~10x for no_db, ~2x for db)
- The 10x no_db regression means per-request framework overhead went from ~0.06ms to ~0.56ms

## Root Cause Analysis

### Commits between alpha.1 and alpha.2
Only 7 commits (`git log --oneline 3.0.0-alpha.1..3.0.0-alpha.2`):
- `e3a0d049c` - **Bump relic from ^0.4.1 to ^0.6.0** (the only meaningful change)
- `c840271bc` - Gracefully handle file match misses (web_server.dart only, port 8080)
- `c0eaf63e2` - Auth server fixes (LICENSE/pubspec only)
- `50f5fd933` - Version bump to alpha.2
- `d2cdceea0` - Remove pub get all
- `26b609d24` - Add version
- `8640fbc1c` - Add missing dependency (auth migration client only)

### The Relic dependency bump
The **only change that could affect API server performance** is `relic: ^0.4.1` → `relic: ^0.6.0`.

All other Serverpod code changes are API renames to match Relic 0.6.0's new API:
- `withResponse()` → `respond()`
- `RequestMethod` → `Method`

### Relic v0.4.1 vs v0.6.0 analysis
Thorough diff analysis of Relic's hot path (request processing pipeline) shows the code is **virtually identical**:
- `RelicServer._handleRequest()` - identical (except removed X-Powered-By header, which should be faster)
- `IOAdapter.respond()` - identical
- `fromHttpRequest()` - identical (minus unused parameters)
- `Request` constructor - identical (type rename only)
- `Headers` / `MutableHeaders` - identical
- `Response.copyWith` - identical

### Known Relic changes (NOT in hot path)
- **Static route cache removed** (PR #172) - but Serverpod's API server doesn't use Relic's Router (confirmed by `// TODO: Use Router instead of manual dispatch on path and verb` comment in server.dart)
- New HostHeader class replacing Uri for host parsing - but headers are parsed lazily
- Router returns sealed class hierarchy - irrelevant for API server

### Possible root causes (unconfirmed)
Since the hot path code is functionally identical, the regression may be caused by:
1. **Transitive dependency version changes** - relic 0.6.0 adds `crypto: ^3.0.0` and may pull different versions of shared deps
2. **Dart AOT compilation behavior** - The larger relic 0.6.0 codebase (even if unused code) may affect tree-shaking, inlining decisions, or code layout in `dart compile exe`
3. **CPU cache effects** - Larger binary from more compiled code could reduce instruction cache hit rates under high load

### Suggested next steps
1. **File issue with Serverpod team** - They maintain both repos and can profile at the Dart VM level
2. **Compare compiled binary sizes** - alpha.1 vs alpha.2 server binary
3. **Profile with Dart observatory** - Compare allocation rates and CPU hotspots
4. **Test relic 0.4.1 with alpha.2 code** - Override relic version using `dependency_overrides` in pubspec.yaml (requires API compatibility shim)
5. **Check Relic issue #109** - "Build Echo Server Benchmark: dart:io vs. Relic Overhead" tracks exactly this concern

## Detailed Results

### Round 1: Serverpod 3.0.0 (Dart 3.8.0)
- **no_db_test**: 1,618.4 req/s | avg 2,944.9ms | median 3,000.0ms | failures: 0
- **db_test**: 724.9 req/s | avg 6,092.2ms | median 5,400.0ms | failures: 0
- **Verdict**: SLOW - regression exists before 3.0.0, narrowing to alpha/RC range

### Serverpod 3.0.0-rc.1 (Dart 3.8.0)
- **no_db_test**: 1746.7 req/s | avg 2749.9ms | median 2700.0ms | failures: 0
- **db_test**: 818.1 req/s | avg 5559.0ms | median 5400.0ms | failures: 0

### Serverpod 3.0.0-alpha.2 (Dart 3.5.0)
- **no_db_test**: 1790.6 req/s | avg 2676.4ms | median 2600.0ms | failures: 0
- **db_test**: 855.7 req/s | avg 5279.2ms | median 5100.0ms | failures: 0
