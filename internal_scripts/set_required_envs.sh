# Default values
DEFAULT_RUNTIME=1000
DEFAULT_USERS=10000
DEFAULT_SPAWN_RATE=10
DEFAULT_LOCUST_ARGS="--processes -1"

# Check for LOCUST_ARGS
if [ -z "$LOCUST_ARGS" ]; then
    echo "Warning: LOCUST_ARGS is not set. Using default value: $DEFAULT_LOCUST_ARGS"
    export LOCUST_ARGS=$DEFAULT_LOCUST_ARGS
else
    echo "LOCUST_ARGS is set to $LOCUST_ARGS"
fi

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
