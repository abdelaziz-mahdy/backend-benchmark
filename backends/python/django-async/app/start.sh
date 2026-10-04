#!/bin/sh
# Migrate, then serve the ASGI app with one uvicorn worker per CPU.
set -e
python manage.py migrate --noinput
exec uvicorn benchmark.asgi:application \
  --host 0.0.0.0 --port 8000 \
  --workers "${BENCH_CPUS:-1}" \
  --no-access-log --log-level warning
