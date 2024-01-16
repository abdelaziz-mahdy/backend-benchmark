#!/bin/bash

# Script name: run_docker_build_and_run.sh
export LOCUST_RUNTIME=500
export LOCUST_USERS=1000
export LOCUST_SPAWN_RATE=10

cd ..
# Find and execute all docker_build_and_run.sh scripts in the current and subdirectories
find . -name 'docker_build_and_run.sh' | while read script; do
    echo "Running script: $script"
    bash "$script"
    echo "Finished running: $script"
done

cd scripts/graphs
bash create_graphs.sh