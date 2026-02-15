#!/bin/bash
# version_benchmark.sh - Test a specific Serverpod version for regression analysis
# Usage: bash scripts/version_benchmark.sh <serverpod_version> <dart_sdk_version>
# Example: bash scripts/version_benchmark.sh 3.0.0 3.8.0

set -e

SERVERPOD_VERSION="$1"
DART_SDK="$2"

if [ -z "$SERVERPOD_VERSION" ] || [ -z "$DART_SDK" ]; then
    echo "Usage: bash scripts/version_benchmark.sh <serverpod_version> <dart_sdk_version>"
    echo "Example: bash scripts/version_benchmark.sh 3.0.0 3.8.0"
    exit 1
fi

echo "========================================"
echo "Testing Serverpod $SERVERPOD_VERSION with Dart $DART_SDK"
echo "========================================"

# Resolve repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SP_DIR="$REPO_ROOT/backends/dart/server-pod"
SERVER_DIR="$SP_DIR/benchmark_server"
CLIENT_DIR="$SP_DIR/benchmark_client"
FLUTTER_DIR="$SP_DIR/benchmark_flutter"
RESULTS_FILE="$SP_DIR/REGRESSION_RESULTS.md"

# Determine SDK constraint based on version
if echo "$DART_SDK" | grep -q "^3\.5"; then
    SDK_CONSTRAINT="'>=3.5.0 <4.0.0'"
else
    SDK_CONSTRAINT="'^${DART_SDK}'"
fi

echo "Step 1: Updating pubspec.yaml files..."

# Update benchmark_server/pubspec.yaml
sed -i '' "s/sdk: .*$/sdk: ${SDK_CONSTRAINT}/" "$SERVER_DIR/pubspec.yaml"
sed -i '' "s/serverpod: .*/serverpod: ${SERVERPOD_VERSION}/" "$SERVER_DIR/pubspec.yaml"

# Update benchmark_client/pubspec.yaml
sed -i '' "s/sdk: .*$/sdk: ${SDK_CONSTRAINT}/" "$CLIENT_DIR/pubspec.yaml"
sed -i '' "s/serverpod_client: .*/serverpod_client: ${SERVERPOD_VERSION}/" "$CLIENT_DIR/pubspec.yaml"

# Update benchmark_flutter/pubspec.yaml - SDK constraint under environment
sed -i '' "/^environment:/,/^[^ ]/ s/sdk: .*$/sdk: ${SDK_CONSTRAINT}/" "$FLUTTER_DIR/pubspec.yaml"
sed -i '' "s/serverpod_flutter: .*/serverpod_flutter: ${SERVERPOD_VERSION}/" "$FLUTTER_DIR/pubspec.yaml"

echo "Step 2: Updating Dockerfile Dart SDK version..."
sed -i '' "s/FROM dart:.* AS build/FROM dart:${DART_SDK} AS build/" "$SERVER_DIR/Dockerfile"

echo "Step 3: Installing serverpod_cli $SERVERPOD_VERSION..."
dart pub global activate serverpod_cli "$SERVERPOD_VERSION"

echo "Step 3b: Writing cross-version compatible server.dart..."
cat > "$SERVER_DIR/lib/server.dart" << 'DART_EOF'
import 'package:serverpod/serverpod.dart';

import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';

void run(List<String> args) async {
  final pod = Serverpod(args, Protocol(), Endpoints());
  await pod.start();
}
DART_EOF

echo "Step 3c: Updating health check to not require web route..."
# Use a simple TCP-based check since we removed web routes
sed -i '' 's|test: "curl --fail --silent.*|test: "curl --silent --output /dev/null http://127.0.0.1:8000/ \|\| exit 1"|' "$SP_DIR/docker-compose.yaml"

echo "Step 4: Dropping old migrations and regenerating..."
rm -rf "$SERVER_DIR/migrations"
mkdir -p "$SERVER_DIR/migrations"
cd "$SERVER_DIR"
dart pub get
serverpod generate
echo "Creating fresh migration..."
serverpod create-migration --force

echo "Step 5: Clearing test caches and stale Docker images..."
rm -f "$SP_DIR/tests/results/no_db_test/env_vars_and_hashes.txt"
rm -f "$SP_DIR/tests/results/db_test/env_vars_and_hashes.txt"
docker rmi server-pod-benchmark 2>/dev/null || true

echo "Step 6: Running benchmarks (both db_test and no_db_test)..."
cd "$REPO_ROOT"
INCLUDE="server-pod" bash scripts/start_tests.sh

echo "Step 7: Extracting results..."

# Extract results from benchmark_stats.csv files
NO_DB_CSV="$SP_DIR/tests/results/no_db_test/benchmark_stats.csv"
DB_CSV="$SP_DIR/tests/results/db_test/benchmark_stats.csv"

extract_aggregated() {
    local csv_file="$1"
    if [ -f "$csv_file" ]; then
        # Get the Aggregated row
        local agg_line=$(grep "^,Aggregated" "$csv_file")
        if [ -n "$agg_line" ]; then
            local req_s=$(echo "$agg_line" | cut -d',' -f10)
            local avg_resp=$(echo "$agg_line" | cut -d',' -f6)
            local median=$(echo "$agg_line" | cut -d',' -f5)
            local failures=$(echo "$agg_line" | cut -d',' -f4)
            echo "${req_s}|${avg_resp}|${median}|${failures}"
        else
            echo "N/A|N/A|N/A|N/A"
        fi
    else
        echo "N/A|N/A|N/A|N/A"
    fi
}

NO_DB_RESULT=$(extract_aggregated "$NO_DB_CSV")
DB_RESULT=$(extract_aggregated "$DB_CSV")

NO_DB_RPS=$(echo "$NO_DB_RESULT" | cut -d'|' -f1)
NO_DB_AVG=$(echo "$NO_DB_RESULT" | cut -d'|' -f2)
NO_DB_MED=$(echo "$NO_DB_RESULT" | cut -d'|' -f3)
NO_DB_FAIL=$(echo "$NO_DB_RESULT" | cut -d'|' -f4)

DB_RPS=$(echo "$DB_RESULT" | cut -d'|' -f1)
DB_AVG=$(echo "$DB_RESULT" | cut -d'|' -f2)
DB_MED=$(echo "$DB_RESULT" | cut -d'|' -f3)
DB_FAIL=$(echo "$DB_RESULT" | cut -d'|' -f4)

# Format numbers for display
format_num() {
    printf "%.1f" "$1" 2>/dev/null || echo "$1"
}

NO_DB_RPS_FMT=$(format_num "$NO_DB_RPS")
NO_DB_AVG_FMT=$(format_num "$NO_DB_AVG")
NO_DB_MED_FMT=$(format_num "$NO_DB_MED")
DB_RPS_FMT=$(format_num "$DB_RPS")
DB_AVG_FMT=$(format_num "$DB_AVG")
DB_MED_FMT=$(format_num "$DB_MED")

echo ""
echo "========================================"
echo "Results for Serverpod $SERVERPOD_VERSION (Dart $DART_SDK)"
echo "========================================"
echo "no_db_test: ${NO_DB_RPS_FMT} req/s, avg ${NO_DB_AVG_FMT}ms, median ${NO_DB_MED_FMT}ms, failures: ${NO_DB_FAIL}"
echo "db_test:    ${DB_RPS_FMT} req/s, avg ${DB_AVG_FMT}ms, median ${DB_MED_FMT}ms, failures: ${DB_FAIL}"
echo "========================================"

# Append results to summary file
echo "" >> "$RESULTS_FILE"
echo "### Serverpod $SERVERPOD_VERSION (Dart $DART_SDK)" >> "$RESULTS_FILE"
echo "- **no_db_test**: ${NO_DB_RPS_FMT} req/s | avg ${NO_DB_AVG_FMT}ms | median ${NO_DB_MED_FMT}ms | failures: ${NO_DB_FAIL}" >> "$RESULTS_FILE"
echo "- **db_test**: ${DB_RPS_FMT} req/s | avg ${DB_AVG_FMT}ms | median ${DB_MED_FMT}ms | failures: ${DB_FAIL}" >> "$RESULTS_FILE"

echo ""
echo "Results appended to $RESULTS_FILE"
echo "Done!"
