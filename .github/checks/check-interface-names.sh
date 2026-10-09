#!/bin/bash

# If location files are passed as arguments, check them instead of all locations
if [ "$#" -gt 0 ]; then
  location_files=("$@")
else
  location_files=(locations/*.yml)
fi

# Initialize a variable to track if any errors are found
error_found=0

# Function to check for errors in interface names
check() {
  local yq_query="$1"
  shift
  local files=("$@")

  # Run the yq command with the expanded list of files
  ifnames=$(yq "$yq_query" "${files[@]}" | grep -v -- '---' | sed 's/["'\'']//g' | sort | uniq)

  # Iterate over each interface name and check if it matches the allowed pattern
  for ifname in $ifnames; do
    if [[ ! "$ifname" =~ ^[a-z0-9_]+$ ]]; then
      echo "Error: Interface name does not match allowed pattern [0-9a-z_]: $ifname"
      error_found=1
    fi
  done
}

# Check for issues across locations
echo "Checking ${location_files[*]}"

# Check for interface name issues
check 'select(.networks != null) | .networks[] | select(.name != null) | .name' "${location_files[@]}"

# Exit with a non-zero status code if any errors were found
if [ "$error_found" -eq 1 ]; then
  exit 1
else
  echo "No errors found"
fi
