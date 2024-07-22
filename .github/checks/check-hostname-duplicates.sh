#!/bin/bash

# Change to the locations directory
cd locations || exit 1

# Variable to accumulate duplicate findings
all_duplicates=""

# Iterate over each file in the directory
for file in ./*; do
  # Check if it is a file
  if [ -f "$file" ]; then
    # Extract hostnames, sort, and find duplicates
    duplicates=$(sed -nE 's/^\s*-\s*hostname:\s*["'\'']{0,1}([a-zA-Z0-9-]+)["'\''#]?([\s].*)?$/\1/p' "$file" | sort | uniq -cd)

    # Accumulate duplicates if found
    if [ -n "$duplicates" ]; then
      all_duplicates+="\n$duplicates"
    fi
  fi
done

# Check if there were any duplicates found
if [ -n "$all_duplicates" ]; then
  echo -e "Duplicate hostnames found:$all_duplicates"
  exit 1
else
  echo "No duplicate hostnames found."
fi
