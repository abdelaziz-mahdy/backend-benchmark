cd "${0%/*}"
python manage.py makemigrations
python manage.py migrate
(trap 'kill 0' SIGINT; python manage.py runserver 0.0.0.0:8000 & wait)