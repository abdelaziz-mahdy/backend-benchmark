"""Minimal production settings for the benchmark: no admin, sessions or CSRF,
since the API is unauthenticated JSON."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "benchmark-only-not-secret")
DEBUG = False
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "notes",
]
MIDDLEWARE = [
    "django.middleware.common.CommonMiddleware",
]
ROOT_URLCONF = "benchmark.urls"
WSGI_APPLICATION = "benchmark.wsgi.application"
ASGI_APPLICATION = "benchmark.asgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.getenv("DATABASE_NAME", "postgres"),
        "USER": os.getenv("DATABASE_USER", "postgres"),
        "PASSWORD": os.getenv("DATABASE_PASSWORD", "postgres"),
        "HOST": os.getenv("DATABASE_HOST", "db"),
        "PORT": os.getenv("DATABASE_PORT", "5432"),
        # Async views cannot reuse persistent connections; PgBouncer pools them.
        "CONN_MAX_AGE": 0,
        # Required with PgBouncer in transaction mode.
        "DISABLE_SERVER_SIDE_CURSORS": True,
    }
}

USE_TZ = True
TIME_ZONE = "UTC"
DEFAULT_AUTO_FIELD = "django.db.models.AutoField"
