#!/bin/bash

# Prints the ansible limit of the hosts to build for the changes compared
# with the base, or nothing if nothing has to be built.
#
# Pull requests are compared with their base branch (GITHUB_BASE_REF),
# pushes with the commit before them (BEFORE, github.event.before).

# Hosts that are built for changes which are not specific to any hosts
fallback_hosts="sama-core,sama-nord-5ghz,l105-gw"

if [ -n "$GITHUB_BASE_REF" ]; then
  base="origin/${GITHUB_BASE_REF#refs/heads/}"
elif git cat-file -e "$BEFORE^{commit}" 2>/dev/null; then
  base="$BEFORE"
else
  base="HEAD^"
fi
echo "Comparing with $base" >&2

mapfile -t changed_files < <(git diff --diff-filter=d --name-only "$base")

limit=()

# Changed host_vars
mapfile -t -O "${#limit[@]}" limit < <(printf '%s\n' "${changed_files[@]}" |
  grep -oP '^host_vars/\K[^/]+(?=/)' | sort -u)

# Changed locations, as group_vars or as a single file
mapfile -t -O "${#limit[@]}" limit < <(printf '%s\n' "${changed_files[@]}" |
  grep -oP '^group_vars/\Klocation_[^/]+(?=/)' | sort -u)
mapfile -t -O "${#limit[@]}" limit < <(printf '%s\n' "${changed_files[@]}" |
  grep -oP '^locations/\K.+(?=\.yml$)' | sed 's/^/location_/; s/-/_/g' | sort -u)

# One host of each changed model, role, target or version group
mapfile -t groups < <(printf '%s\n' "${changed_files[@]}" |
  grep -oP '^group_vars/\K(model|role|target|version)_[^/.]+' | sort -u | sed 's/$/[0]/')
if [ "${#groups[@]}" -gt 0 ]; then
  group_limit=$(IFS=,; echo "${groups[*]}")
  if ansible-playbook play.yml --list-hosts --limit "$group_limit" >/dev/null 2>&1; then
    limit+=("${groups[@]}")
  else
    echo "No hosts in the changed groups $group_limit" >&2
  fi
fi

# Changes that are not specific to any hosts
if [ "${#limit[@]}" -eq 0 ] && printf '%s\n' "${changed_files[@]}" |
  grep -qxP '(inventory|roles)/.+|group_vars/(all/.+|community_.+)'; then
  limit=("$fallback_hosts")
fi

(IFS=,; echo "${limit[*]}")
