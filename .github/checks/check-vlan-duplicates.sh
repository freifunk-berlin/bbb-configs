#!/bin/bash

# Change to the locations directory
cd locations || exit 1

# Variable to accumulate duplicate findings
all_duplicates=""

# Iterate over each file in the directory
for file in ./*; do
  # Check if it is a file
  if [ -f "$file" ]; then
    # Extract VIDs / VLAN names, sort, and find duplicates
    duplicates_vid=$(yq 'select(.networks != null) | .networks[].vid' "$file" | grep -v 'null' |  sed 's/["'\'']//g' | sort | uniq -cd)
    duplicates_name=$(yq 'select(.networks != null) | .networks[].name' "$file" | grep -v 'null' | sed 's/["'\'']//g' | sort | uniq -cd)
    # Accumulate duplicates if found
    if [ -n "$duplicates_vid" ]; then
      all_duplicates+="\nDuplicate VIDs found in $file:\n$duplicates_vid"
    fi
    if [ -n "$duplicates_name" ]; then
      all_duplicates+="\nDuplicate VLAN names found in $file:\n$duplicates_name"
    fi
  fi
done

# Check if there were any duplicates found
if [ -n "$all_duplicates" ]; then
  echo -e "Duplicates VIDs or VLAN names found:$all_duplicates"
  exit 1
else
  echo "No duplicate VIDs or VLAN names found."
fi
