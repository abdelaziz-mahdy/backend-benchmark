#!/bin/bash
cd "${0%/*}"

# Build and start services for Django-Python
docker compose build
docker compose up -d

# Wait for the tester to finish running
echo "Waiting for tester service to complete..."
while docker compose ps tester | grep "Up" > /dev/null; do
    sleep 5
done

# Check if the tester service has exited
if docker compose ps -a tester | grep "Exit" > /dev/null; then
    echo "Tester service has completed. Proceeding to shut down..."
    # Bring down the services and remove them
    docker compose down -v
    echo "Services shut down and volumes removed."
else
    echo "Tester service did not run or has not completed. No action taken."
fi

# Now, build and run the Docker image for graph generation
echo "Building and running graph generator Docker image..."

# Navigate to the graph generator directory
cd ../scripts/graphs

# Build the Docker image for graph generation
docker build -t graph_generator_image .

# Run the Docker container with the necessary volume mount
docker run -v "$(pwd)/../../django-python/tests/results:/mnt/data" graph_generator_image python graph_generator.py

echo "Graph generation completed."

