#!/bin/bash

# Script name: run_docker_build_and_run.sh
#!/bin/bash

# Default values
DEFAULT_RUNTIME=1000
DEFAULT_USERS=10000
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


cd ..
# Find all 'docker_build_and_run.sh' files and store them in an array
scripts=($(find . -name 'docker_build_and_run.sh'))

# Get total number of scripts and multiply by 2 for the two test types
total_scripts=$((${#scripts[@]} * 2))

# Initialize a counter
counter=1

# Define the test types
test_types=("db_test" "no_db_test")

# Loop through each script
for script in "${scripts[@]}"; do
    for test_type in "${test_types[@]}"; do
        echo "Running script $counter out of $total_scripts: $script with test_type=$test_type"
        export test_type=$test_type
        bash "$script"
        echo "Finished running: $script with test_type=$test_type"

        # Increment the counter
        ((counter++))
        echo "Sleeping for 5 seconds..."
        sleep 5
    done
done

cd scripts/graphs
bash create_graphs.sh