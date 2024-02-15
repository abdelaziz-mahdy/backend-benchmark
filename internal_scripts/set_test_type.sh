# Function to get user input for test_type
get_user_test_type_selection() {
    echo "Please enter the number corresponding to the test type:"
    select choice in "db_test" "no_db_test"; do
        case $choice in
            db_test )
                # Use 'return' to indicate the choice by an exit status code
                return 1
                ;;
            no_db_test )
                # Different exit status code for no_db_test
                return 2
                ;;
            * )
                echo "Invalid selection. Please enter 1 for db_test or 2 for no_db_test."
                ;;
        esac
    done
}

# Check if test_type is already set
if [ -z "$test_type" ]; then
    # test_type is not set, ask the user to select
    echo "test_type is not set. Please select one."
    get_user_test_type_selection
    result=$?
    if [ $result -eq 1 ]; then
        test_type="db_test"
    elif [ $result -eq 2 ]; then
        test_type="no_db_test"
    fi
    export test_type
else
    # test_type is set, just echo the value
    echo "test_type is set to $test_type."
fi

echo "test_type is now set to $test_type."

results_dir="tests/results/$test_type"
mkdir -p $results_dir