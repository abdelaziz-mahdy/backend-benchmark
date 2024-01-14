# Now, build and run the Docker image for graph generation
echo "Building and running graph generator Docker image..."

# Navigate to the graph generator directory
cd ../scripts/graphs

# Build the Docker image for graph generation
docker build -t graph_generator_image .

# Run the Docker container with the necessary volume mount
docker run -v "$(pwd)/../../django-python/tests/results:/mnt/data" graph_generator_image python graph_generator.py

echo "Graph generation completed."