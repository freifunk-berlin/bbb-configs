#!/bin/bash

# Initialize a variable to track if any errors are found
error_found=0

# If location files are passed as arguments, override the default location_files variable
if [ "$#" -gt 0 ]; then
  # Treat location_files as an array to handle multiple arguments
  location_files=("$@")
else
  # Use the default pattern if no arguments are passed
  location_files=("locations/*.yml")
fi

# Function to check for errors in password file paths
check() {
  local yq_query="$1"
  local file_pattern="$2"

  # Expand the file pattern to a list of files
  # shellcheck disable=SC2206
  files=($file_pattern)

  # Check if any files match the pattern
  if [ ${#files[@]} -eq 0 ]; then
    echo "No files matching pattern $file_pattern"
    return
  fi

  # Run the yq command with the expanded list of files
  pwd_paths=$(yq "$yq_query" "${files[@]}" | grep -v -- '---' | sed 's/["'\'']//g' | sort | uniq)

  # Iterate over each password path and check if it matches the required pattern
  for path in $pwd_paths; do
    if [[ ! "$path" =~ ^file:/[^[:space:]]+ ]]; then
      echo "Error: Password file path does not match file:/absolute-path/pwd-file and is invalid: $path"
      error_found=1
    fi
  done
}

# Check for issues across locations
echo "Checking $location_files"

# Check for password path issues
check 'select(.airos_dfs_reset != null) | .airos_dfs_reset[] | select(.password != null) | .password' "$location_files"
check 'select(.location__wireless_profiles__to_merge != null) | .location__wireless_profiles__to_merge[] | select(.ifaces != null) | .ifaces[] | select(.key != null) | .key' "$location_files"


# Exit with a non-zero status code if any errors were found
if [ "$error_found" -eq 1 ]; then
  exit 1
else
  echo "No errors found"
fi
