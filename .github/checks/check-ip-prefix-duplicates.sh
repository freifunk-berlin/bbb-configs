#!/bin/bash

# Change to the locations directory
cd locations || exit 1

# Check for IPv4 duplicates
ipv4_duplicates=$(sed -nE 's/^\s*prefix:\s*["'\''"]?([^"'\''\s#]+)["'\''"]?/\1/p' ./*.yml | sort | uniq -cd)

# Check for IPv6 duplicates
ipv6_duplicates=$(sed -nE 's/^\s*ipv6_prefix:\s*["'\''"]?([0-9a-fA-F:]+\/[0-9]+)["'\''"]?/\1/p' ./*.yml | sort | uniq -cd)


if [ -n "$ipv4_duplicates" ] || [ -n "$ipv6_duplicates" ]; then
  if [ -n "$ipv4_duplicates" ]; then
    echo "Duplicate IPv4 prefixes found:"
    echo "$ipv4_duplicates"
  fi
  if [ -n "$ipv6_duplicates" ]; then
    echo "Duplicate IPv6 prefixes found:"
    echo "$ipv6_duplicates"
  fi
  exit 1
else
  echo "No duplicate prefixes found."
fi
