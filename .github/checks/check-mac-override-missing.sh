#!/bin/bash

# Initialize a variable to track if any errors are found
error_found=0

# Define patterns for location files and model files
location_files='locations/*.yml'
model_files='group_vars/model_*.yml'

# Find all models that require a mac_override
declare -A mac_override_required_models

for model_file_path in $model_files; do
  # Extract model name from file path
  model_file=$(basename "$model_file_path" .yml)
  model_name=${model_file#model_}

  # Check if the model requires mac_override
  requires_mac_override=$(yq '.requires_mac_override' "$model_file_path" | tr -d '"')

  # Store the result in the associative array
  mac_override_required_models["$model_name"]=$requires_mac_override
done

# Find all missing mac_overrides
for location_file in $location_files; do
  # Get hosts as a single YAML block to minimize calls to yq
  hosts=$(yq '.hosts' "$location_file")

  # Loop through each host entry
  for i in $(seq 0 $(($(echo "$hosts" | yq '. | length') - 1))); do
    hostname=$(echo "$hosts" | yq ".[$i].hostname" | tr -d '"')
    model=$(echo "$hosts" | yq ".[$i].model" | tr -d '"')
    mac_override=$(echo "$hosts" | yq ".[$i].mac_override" | tr -d '"')

    # Convert model name to match the model file format (underscore instead of hyphen)
    model_name=${model//-/_}

    # Check if the model requires mac_override using the associative array
    requires_mac_override=${mac_override_required_models["$model_name"]}

    if [ "$requires_mac_override" = "true" ]; then
      if [ "$mac_override" == "null" ]; then
        # Output the missing mac_override details immediately
        echo "Host $hostname (model: $model) in $location_file is missing mac_override."
        error_found=1
      fi
    fi
  done
done

# Exit with a non-zero status code if any errors were found
if [ "$error_found" -eq 1 ]; then
  exit 1
else
  echo "No MAC override issues found."
fi

