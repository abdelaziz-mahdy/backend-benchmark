cd "${0%/*}"
alembic init alembic

alembic revision --autogenerate -m "Initial migration"
alembic upgrade head

(trap 'kill 0' SIGINT; uvicorn main:app --host 0.0.0.0 --port 8000 & wait)