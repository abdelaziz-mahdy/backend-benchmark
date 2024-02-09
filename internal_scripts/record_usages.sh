
#!/bin/bash

# Variables
env_file="$results_dir/env_vars_and_hashes.txt"

# Ensure the results directory exists
mkdir -p "$results_dir"

# Function to get Docker image hash
get_image_hash() {
    docker image ls --no-trunc | grep "$1" | awk '{print $3}' | head -n 1
}

# Function to record Docker image hashes and environment variables
record_env_and_hashes() {
    # Get image hashes
    benchmark_hash=$(get_image_hash "benchmark")
    db_hash=$(get_image_hash "db")
    # tester_hash=$(get_image_hash "tester")

    # Record environment variables and hashes
    echo "BENCHMARK_HASH=$benchmark_hash" > "$env_file"
    echo "DB_HASH=$db_hash" >> "$env_file"
    # echo "TESTER_HASH=$tester_hash" >> "$env_file"
    echo "LOCUST_ARGS='$LOCUST_ARGS'" >> "$env_file"
    echo "LOCUST_RUNTIME='$LOCUST_RUNTIME'" >> "$env_file"
    echo "LOCUST_USERS='$LOCUST_USERS'" >> "$env_file"
    echo "LOCUST_SPAWN_RATE='$LOCUST_SPAWN_RATE'" >> "$env_file"
}

# Function to check if the current environment and hashes match the recorded ones
check_env_and_hashes() {
    if [ -f "$env_file" ]; then
        source "$env_file"

        current_benchmark_hash=$(get_image_hash "benchmark")
        current_db_hash=$(get_image_hash "db")
        # current_tester_hash=$(get_image_hash "tester")

        # if [ "$BENCHMARK_HASH" == "$current_benchmark_hash" ] && [ "$DB_HASH" == "$current_db_hash" ] && [ "$TESTER_HASH" == "$current_tester_hash" ] && [ "$LOCUST_ARGS" == "$LOCUST_ARGS" ] && [ "$LOCUST_RUNTIME" == "$LOCUST_RUNTIME" ] && [ "$LOCUST_USERS" == "$LOCUST_USERS" ] && [ "$LOCUST_SPAWN_RATE" == "$LOCUST_SPAWN_RATE" ]; then
        if [ "$BENCHMARK_HASH" == "$current_benchmark_hash" ] && [ "$DB_HASH" == "$current_db_hash" ] && [ "$LOCUST_ARGS" == "$LOCUST_ARGS" ] && [ "$LOCUST_RUNTIME" == "$LOCUST_RUNTIME" ] && [ "$LOCUST_USERS" == "$LOCUST_USERS" ] && [ "$LOCUST_SPAWN_RATE" == "$LOCUST_SPAWN_RATE" ]; then

            echo "Environment and variables match the previous run. Skipping certain actions."
            return 0
        else
            echo "Environment or variables have changed. Proceeding with the script."
            return 1
        fi
    else
        echo "No previous environment recorded. Proceeding with the script."
        return 1
    fi
}

# Check the environment and hashes at the beginning of the script
if check_env_and_hashes; then
    # If the function returns 0, skip to the end or perform only the required actions
    exit 0
fi

docker compose build
docker compose up -d
#!/bin/bash

# File to store the CPU usage data
output_file="$results_dir/cpu_usage.csv"

# Ensure the results directory exists
mkdir -p results


# Write header to the CSV file with added memory usage columns
echo "timestamp,benchmark_cpu_usage,benchmark_mem_usage,db_cpu_usage,db_mem_usage" > "$output_file"

# Function to record CPU and memory usage for both benchmark and database services
record_cpu_mem_usage() {
    while :; do
        # Check if Docker services are still running
        if ! docker compose ps | grep "Up" > /dev/null; then
            echo "Docker services are down. Stopping CPU and memory usage tracking."
            break
        fi

        # Get CPU and memory usage of the 'benchmark' service
        benchmark_stats=$(docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemPerc}}" | grep "benchmark" | cut -d ',' -f2,3)
        benchmark_cpu_usage=$(echo $benchmark_stats | cut -d ',' -f1)
        benchmark_mem_usage=$(echo $benchmark_stats | cut -d ',' -f2)

        # Get CPU and memory usage of the database service
        db_stats=$(docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemPerc}}" | grep "db" | cut -d ',' -f2,3)
        db_cpu_usage=$(echo $db_stats | cut -d ',' -f1)
        db_mem_usage=$(echo $db_stats | cut -d ',' -f2)

        # Get the current timestamp
        timestamp=$(date +%s)

        # Append the data to the file
        echo "$timestamp,$benchmark_cpu_usage,$benchmark_mem_usage,$db_cpu_usage,$db_mem_usage" >> "$output_file"

        # Wait for 1 second
        sleep 1
    done
}

# Run the function in the background
record_cpu_mem_usage &


echo "Waiting for tester service to start..."
# Loop until the tester service starts
while ! docker compose ps tester | grep "Up" > /dev/null; do
    sleep 1
done

# Set the start time when the tester service starts
start_time=$(date +%s)
echo "Tester service started. Monitoring runtime..."

# Wait for the tester to finish running
while docker compose ps tester | grep "Up" > /dev/null; do
    # Calculate the elapsed time
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    # Calculate remaining time
    remaining_time=$((LOCUST_RUNTIME - elapsed_time))
    if [ $remaining_time -le 0 ]; then
        remaining_time=0
    fi

    # Assuming remaining_time is in seconds
    minutes=$((remaining_time / 60))
    seconds=$((remaining_time % 60))

    # Display the remaining time in minutes and seconds, overwriting the previous line
    echo -ne "Remaining time: $minutes minutes, $seconds seconds\r"

    sleep 5
done
echo -e "\nTester service is no longer running."


# Check if the tester service has exited
if docker compose ps -a tester | grep "Exit" > /dev/null; then
    echo "Tester service has completed. Proceeding to shut down..."
    record_env_and_hashes
    # Bring down the services and remove them
    docker compose down -v
    echo "Services shut down and volumes removed."
else
    echo "Tester service did not run or has not completed. No action taken."
fi
