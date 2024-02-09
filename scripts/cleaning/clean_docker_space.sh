#!/bin/bash

# Remove stopped containers
docker container prune -f

# Remove unused networks
docker network prune -f

# Remove dangling and unused images
docker image prune -a -f

# Remove build cache
docker builder prune -a -f

# Remove unused volume
docker volume prune -f
