#!/usr/bin/env bash
# Entry point for the benchmark runner. Needs Docker and Python 3.10+ with
# PyYAML; uses uv to provide PyYAML when it is installed.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
if command -v uv >/dev/null 2>&1; then
  exec uv run --quiet --with pyyaml python "$here/bench.py" "$@"
fi
exec python3 "$here/bench.py" "$@"
