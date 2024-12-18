#!/bin/bash

# Script name: start_tests.sh

# Save the current directory
dir=$(pwd)

# Flag to check if the script is found
found=0

# Loop through the current and parent directories
while true; do
    # Check if the script exists in the current directory
    if [[ -f "$dir/internal_scripts/set_required_envs.sh" ]]; then
        echo "Found script at $dir/internal_scripts/set_required_envs.sh"
        . "$dir/internal_scripts/set_required_envs.sh"
        found=1
        break
    else
        # Move to the parent directory
        parentdir=$(dirname "$dir")
        if [[ "$dir" == "$parentdir" ]]; then
            break
        fi
        dir=$parentdir
    fi
done

if [[ $found -eq 0 ]]; then
    echo "Required environment script not found."
    exit 1
fi

cd ..

# Check if INCLUDE variable is set
if [[ -z "$INCLUDE" ]]; then
    echo "Warning: INCLUDE variable not set. All scripts will be included."
    INCLUDE=""
fi

# Convert INCLUDE variable to an array
IFS=',' read -ra include_patterns <<< "$INCLUDE"

# Find all 'docker_build_and_run.sh' files
scripts=($(find . -name 'docker_build_and_run.sh'))

echo "Found ${#scripts[@]} scripts in total:"
echo "${scripts[@]}"

# Filter scripts to include only matching the patterns in INCLUDE
filtered_scripts=()

# If INCLUDE list is empty, include all scripts
if [[ ${#include_patterns[@]} -eq 0 ]]; then
    echo "INCLUDE list is empty. Including all scripts."
    filtered_scripts=("${scripts[@]}")
else
    for script in "${scripts[@]}"; do
        include_flag=0
        for pattern in "${include_patterns[@]}"; do
            if echo "$script" | grep -wq "$pattern"; then
                include_flag=1
                echo "Including $script as it matches include pattern $pattern"
                break
            fi
        done
        if [[ $include_flag -eq 1 ]]; then
            filtered_scripts+=("$script")
        fi
    done
fi


echo "#########################################################################"
echo "Found scripts ${#scripts[@]} and after filtering ${#filtered_scripts[@]} scripts to run:"
echo "${filtered_scripts[@]}"

# Get total number of scripts and multiply by 2 for the two test types
total_scripts=$((${#filtered_scripts[@]} * 2))

# Initialize a counter
counter=1

# Define the test types
test_types=("db_test" "no_db_test")

for script in "${filtered_scripts[@]}"; do
    for test_type in "${test_types[@]}"; do
        remaining_tests=$((total_scripts - counter + 1))
        total_remaining_seconds=$((remaining_tests * LOCUST_RUNTIME))
        minutes=$((total_remaining_seconds / 60))
        seconds=$((total_remaining_seconds % 60))

        echo "Running script $counter out of $total_scripts: $script with test_type=$test_type"
        echo "Estimated remaining time: $minutes minutes, $seconds seconds"

        export test_type=$test_type
        bash "$script"
        echo "Finished running: $script with test_type=$test_type"

        ((counter++))
        echo "Sleeping for 5 seconds..."
        sleep 5
    done
done

cd scripts/graphs
bash create_graphs.sh
