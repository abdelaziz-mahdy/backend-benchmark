#!/bin/bash

# Build and run the Docker image for graph generation using a base Node image
echo "Building and running data generator Docker image..."


# Run the Docker container with the necessary volume mount
docker run --rm -v "$(pwd)/../../:/mnt/data" node:18 /bin/sh -c "cd /mnt/data/benchmark-app && npm install && node processData.js"

echo "Data generation completed."
