#!/bin/bash

cd "${0%/*}"
python manage.py makemigrations
python manage.py migrate

# Determine the number of CPU cores
CPU_CORES=$(nproc)

# Gunicorn configuration for I/O-bound applications using gevent
WORKERS=$((CPU_CORES * 2 + 1))
# WORKER_CLASS="gevent"
THREADS=$((CPU_CORES * 2 + 1))
WORKER_CONNECTIONS=1000
BIND="0.0.0.0:8000"
LOG_LEVEL="info"


(trap 'kill 0' SIGINT; gunicorn benchmark.wsgi:application \
    --workers $WORKERS \
    --threads $THREADS \
    --worker-connections $WORKER_CONNECTIONS \
    --bind $BIND \
    --log-level $LOG_LEVEL \
 & wait)
