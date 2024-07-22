#!/bin/bash

# Change to the locations directory
cd locations || exit 1

# Check for address duplicates
duplicates=$(sed -nE 's/^\s*address:\s*["'\''"]?([^"'\''\s#]+)["'\''"]?/\1/p' ./*.yml | sort | uniq -cd)

if [ -n "$duplicates" ]; then
  echo "Duplicate addresses found:"
  echo "$duplicates"
  exit 1
else
  echo "No duplicate addresses found."
fi
