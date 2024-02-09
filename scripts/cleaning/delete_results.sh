#!/bin/bash

# Navigate up the directory tree to find the 'backends' directory
dir=$(pwd)
while true; do
  if [[ -d "$dir/backends" ]]; then
    echo "Found 'backends' directory at $dir"
    cd "$dir/backends"
    break
  else
    parentdir=$(dirname "$dir")
    if [[ "$dir" == "$parentdir" ]]; then
      echo "'backends' directory not found. Exiting."
      exit 1
    fi
    dir=$parentdir
  fi
done

# Find all directories named 'results' within 'backends'
echo "Searching for 'results' directories in '$(pwd)':"
results_dirs=$(find . -type d -name 'results')

if [ -z "$results_dirs" ]; then
    echo "No 'results' directories found."
    exit 0
fi

echo "Found 'results' directories:"
echo "$results_dirs"

# Ask if user wants to delete all found 'results' directories
echo "Do you want to delete all these 'results' directories? [y/N]"
read -r answer
if [[ "$answer" == [Yy]* ]]; then
  echo "Deleting all 'results' directories..."
  echo "$results_dirs" | while read -r dir; do
    rm -rf "$dir"
    echo "Deleted '$dir'"
  done
  echo "All 'results' directories deleted."
else
  echo "Deletion aborted."
fi
