#!/bin/bash

# Locations pattern
location_files="locations/*.yml"

# Initialize a variable to track if any errors are found
error_found=0

# Function to check for duplicates
check_duplicates() {
  local yq_query="$1"
  local description="$2"
  local file_pattern="$3"

  # Expand the file pattern to a list of files
  # shellcheck disable=SC2206
  files=($file_pattern)

  # Check if any files match the pattern
  if [ ${#files[@]} -eq 0 ]; then
    echo "No files matching pattern $file_pattern"
    return
  fi

  # Run the yq command with the expanded list of files
  duplicates=$(yq "$yq_query" "${files[@]}" | grep -v -- '---' | tr '[:upper:]' '[:lower:]' | sed 's/["'\'']//g' | sort | uniq -cd)
  if [ -n "$duplicates" ]; then
    echo "Duplicate $description found:"
    echo "$duplicates"
    error_found=1
  fi
}

# Check for duplicates accross all locations
echo "Checking $location_files"

# Check for hostname duplicates within hosts
check_duplicates 'select(.hosts != null) | .hosts[].hostname' "hostnames within hosts" "$location_files"

# Check for mac_override duplicates within hosts
check_duplicates 'select(.hosts != null) | .hosts[].mac_override | select(. != null) | to_entries[] | .value' "mac_overrides within hosts" "$location_files"

# Check for hostname duplicates within snmp_devices
check_duplicates 'select(.snmp_devices != null) | .snmp_devices[].hostname' "hostnames within snmp_devices" "$location_files"

# Check for address duplicates within snmp_devices
check_duplicates 'select(.snmp_devices != null) | .snmp_devices[].address' "addresses within snmp_devices" "$location_files"

# Check for ipv6_prefix duplicates
check_duplicates 'select(.ipv6_prefix != null) | .ipv6_prefix' "ipv6_prefixes" "$location_files"

# Check for ipv4_prefix duplicates within networks
check_duplicates 'select(.networks != null) | .networks[] | select(.prefix != null) | .prefix' "prefix within networks" "$location_files"

# Check for duplicate hosts within 11a channel assignments
check_duplicates 'select(.location__channel_assignments_11a_standard__to_merge != null) | .location__channel_assignments_11a_standard__to_merge | keys[]' "hosts within 11a channel assignments" "$location_files"

# Check for duplicate hosts within 11g channel assignments
check_duplicates 'select(.location__channel_assignments_11g_standard__to_merge != null) | .location__channel_assignments_11g_standard__to_merge | keys[]' "hosts within 11g channel assignments" "$location_files"

# Check for duplicates within a single location
for file in $location_files; do
  echo "Checking $file"

  # Check for VID duplicates within networks
  check_duplicates 'select(.networks != null) | .networks[] | select(.vid != null) | .vid' "VID within networks" "$file"

  # Check for name duplicates within networks
  check_duplicates 'select(.networks != null) | .networks[] | select(.name != null) | .name' "name within networks" "$file"

done

# Exit with a non-zero status code if any errors were found
if [ "$error_found" -eq 1 ]; then
  exit 1
else
  echo "No duplicates found"
fi
