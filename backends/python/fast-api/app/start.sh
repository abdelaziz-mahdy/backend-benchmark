#!/bin/sh
# One uvicorn worker per CPU the benchmark assigns.
exec uvicorn main:app \
  --host 0.0.0.0 --port 8000 \
  --workers "${BENCH_CPUS:-1}" \
  --no-access-log --log-level warning
