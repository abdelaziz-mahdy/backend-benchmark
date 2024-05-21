cd "${0%/*}"
python manage.py makemigrations
python manage.py migrate
(trap 'kill 0' SIGINT; gunicorn benchmark.wsgi & wait)