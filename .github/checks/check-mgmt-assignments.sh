#!/bin/bash

# Ensure all hosts have an assignment in the mgmt network (role: mgmt)

if [ "$#" -gt 0 ]; then
  location_files=("$@")
else
  location_files=(locations/*.yml)
fi

error_found=0

for file in "${location_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "File $file does not exist, skipping."
    continue
  fi

  # collect hostnames
  hostnames=$(yq 'select(.hosts != null) | .hosts[] | .hostname' "$file" | sed 's/"//g' | tr -d '\r' || true)
  if [ -z "$hostnames" ]; then
    continue
  fi

  # detect if location is a gateway (any host with role gateway)
  has_gateway=$(yq 'select(.hosts != null) | .hosts[] | select(.role=="gateway") | .hostname' "$file" | sed 's/"//g' || true)
  is_gateway=0
  if [ -n "$has_gateway" ]; then
    is_gateway=1
  fi
  if [ "$is_gateway" -eq 1 ]; then
    # skip mgmt assignment check for gateway locations
    echo "Skipping mgmt-assignment check for gateway location: $file"
    continue
  fi

  # non-gateway locations: only perform check if a network with role 'mgmt' exists
  mgmt_exists=$(yq 'select(.networks != null) | .networks[] | select(.role=="mgmt")' "$file")
  if [ -z "$mgmt_exists" ]; then
    # no mgmt network defined -> allowed, nothing to verify
    echo "Skipping mgmt-assignment check for location without network with mgmt role: $file"
    continue
  fi
  assignments=$(yq 'select(.networks != null) | .networks[] | select(.role=="mgmt") | .assignments // {} | keys[]' "$file" | sed 's/"//g' || true)

  for h in $hostnames; do
    if ! echo "$assignments" | grep -xq "$h"; then
      echo "Error: Host $h in $file is not present in mgmt assignments"
      error_found=1
    fi
  done
done

if [ "$error_found" -eq 1 ]; then
  exit 1
else
  echo "All hosts have mgmt assignments"
fi
