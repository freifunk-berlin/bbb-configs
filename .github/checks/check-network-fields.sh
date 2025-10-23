#!/bin/bash

# Check networks (role: mesh|dhcp|mgmt) for missing prefix or ipv6_subprefix

if [ "$#" -gt 0 ]; then
  location_files=("$@")
else
  # default to all location files
  location_files=(locations/*.yml)
fi

error_found=0

for file in "${location_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "File $file does not exist, skipping."
    continue
  fi

  # Query relevant networks (mesh|dhcp|mgmt) once and produce TSV: role,vid,prefix,ipv6_subprefix
  mapfile -t rows < <(yq -r '.networks[] | select(.role=="mesh" or .role=="dhcp" or .role=="mgmt") | "\(.role)\t\(.vid // "")\t\(.prefix // "null")\t\(.ipv6_subprefix // "null")"' "$file" 2>/dev/null || true)

  if [ ${#rows[@]} -eq 0 ]; then
    continue
  fi

  for row in "${rows[@]}"; do
    IFS=$'\t' read -r role vid prefix ipv6 <<< "$row"
    # normalize null/empty
    [ -z "$prefix" ] && prefix="null"
    [ -z "$ipv6" ] && ipv6="null"

    if [ "$prefix" = "null" ]; then
      echo "Error: $file (role=$role vid=$vid) missing 'prefix'"
      error_found=1
    fi

    if [ "$ipv6" = "null" ]; then
      echo "Error: $file (role=$role vid=$vid) missing 'ipv6_subprefix'"
      error_found=1
    fi
  done
done

if [ "$error_found" -eq 1 ]; then
  exit 1
else
  echo "No missing network fields found"
fi
