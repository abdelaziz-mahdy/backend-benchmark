# Now, build and run the Docker image for graph generation
echo "Building and running graph generator Docker image..."


# Build the Docker image for graph generation
docker build -t graph_generator_image .

# Run the Docker container with the necessary volume mount
docker run --rm -v "$(pwd)/../../:/mnt/data" -v "$(pwd)/:/usr/src/app" graph_generator_image python graph_generator.py

echo "Graph generation completed."