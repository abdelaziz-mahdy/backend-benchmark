#!/bin/sh
# Migrate, then serve with gunicorn: (2 x CPUs + 1) workers, 4 threads each.
set -e
python manage.py migrate --noinput
cpus="${BENCH_CPUS:-1}"
exec gunicorn benchmark.wsgi:application \
  --bind 0.0.0.0:8000 \
  --workers $((cpus * 2 + 1)) \
  --worker-class gthread \
  --threads 4 \
  --log-level warning
