#!/bin/bash
cd "${0%/*}"

# Build and start services for Django-Python
# cd benchmark
# bash update_requirements.sh
# cd ..

#!/bin/bash

# Save the current directory
dir=$(pwd)

# Flag to check if the script is found
found=0

# Loop through the current and parent directories
while true; do
  # Check if the script exists in the current directory
  if [[ -f "$dir/internal_scripts/set_required_envs.sh" ]]; then
    # Script found, execute it
    echo "Found script at $dir/internal_scripts/set_required_envs.sh"
    . "$dir/internal_scripts/set_required_envs.sh"

    found=1
    break
  else
    # Move to the parent directory
    parentdir=$(dirname "$dir")
    # Check if we have reached the root directory
    if [[ "$dir" == "$parentdir" ]]; then
      break
    fi
    dir=$parentdir
  fi
done

# Check if script was not found
if [[ $found -eq 0 ]]; then
  echo "Script not found."
  exit 1
fi

. "$dir/internal_scripts/set_test_type.sh"

# Rest of the script...
. "$dir/internal_scripts/record_usages.sh"