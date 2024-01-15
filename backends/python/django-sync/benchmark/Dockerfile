FROM python:3.12

WORKDIR /app

# Copy the requirements file into the container at /app
COPY poetry.lock pyproject.toml /app/

# Install Poetry and project dependencies
RUN pip install poetry && \
    poetry config virtualenvs.create false && \
    poetry lock && poetry install --no-dev --no-root

COPY . .


EXPOSE 8000
ENV PYTHONUNBUFFERED=1
ARG CACHEBUST=1 

CMD bash run_only_for_docker.sh