FROM python:3.12

WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt /app

RUN pip install -r requirements.txt

COPY . .



EXPOSE 8000
ENV PYTHONUNBUFFERED=1
ARG CACHEBUST=1 

CMD bash run_only_for_docker.sh