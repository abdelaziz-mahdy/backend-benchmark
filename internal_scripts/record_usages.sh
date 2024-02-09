
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

    # Echo the remaining time, overwriting the previous line
    echo -ne "Remaining time: $remaining_time seconds\r"
    sleep 5
done
echo -e "\nTester service is no longer running."


# Check if the tester service has exited
if docker compose ps -a tester | grep "Exit" > /dev/null; then
    echo "Tester service has completed. Proceeding to shut down..."
    # Bring down the services and remove them
    docker compose down -v
    echo "Services shut down and volumes removed."
else
    echo "Tester service did not run or has not completed. No action taken."
fi
