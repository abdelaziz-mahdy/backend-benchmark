#!/bin/bash
cd "${0%/*}"

# Build and start services for Django-Python
# cd benchmark
# bash update_requirements.sh
# cd ..
#!/bin/bash

# Default values
DEFAULT_RUNTIME=500
DEFAULT_USERS=5000
DEFAULT_SPAWN_RATE=10

# Check for LOCUST_RUNTIME
if [ -z "$LOCUST_RUNTIME" ]; then
    echo "Warning: LOCUST_RUNTIME is not set. Using default value: $DEFAULT_RUNTIME"
    export LOCUST_RUNTIME=$DEFAULT_RUNTIME
else
    echo "LOCUST_RUNTIME is set to $LOCUST_RUNTIME"
fi

# Check for LOCUST_USERS
if [ -z "$LOCUST_USERS" ]; then
    echo "Warning: LOCUST_USERS is not set. Using default value: $DEFAULT_USERS"
    export LOCUST_USERS=$DEFAULT_USERS
else
    echo "LOCUST_USERS is set to $LOCUST_USERS"
fi

# Check for LOCUST_SPAWN_RATE
if [ -z "$LOCUST_SPAWN_RATE" ]; then
    echo "Warning: LOCUST_SPAWN_RATE is not set. Using default value: $DEFAULT_SPAWN_RATE"
    export LOCUST_SPAWN_RATE=$DEFAULT_SPAWN_RATE
else
    echo "LOCUST_SPAWN_RATE is set to $LOCUST_SPAWN_RATE"
fi

# Rest of the script...



# cd benchmark_server
# serverpod create-migration
# cd ..

# docker compose down -v

docker compose build 
docker compose up -d

# File to store the CPU usage data
output_file="tests/results/cpu_usage.csv"

# Ensure the results directory exists
mkdir -p results

# Write header to the CSV file
echo "timestamp,cpu_usage" > "$output_file"

# Function to record CPU usage
record_cpu_usage() {
    while :; do
        # Check if Docker services are still running
        if ! docker compose ps | grep "Up" > /dev/null; then
            echo "Docker services are down. Stopping CPU usage tracking."
            break
        fi

        # Get CPU usage of the 'benchmark' service
        cpu_usage=$(docker stats --no-stream --format "{{.Name}},{{.CPUPerc}}" | grep "benchmark" | cut -d ',' -f2)

        # Get the current timestamp
        timestamp=$(date +%s)

        # Append the data to the file
        echo "$timestamp,$cpu_usage" >> "$output_file"

        # Wait for 1 second
        sleep 1
    done
}

# Run the function in the background
record_cpu_usage &
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

