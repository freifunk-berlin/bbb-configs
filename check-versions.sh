#!/bin/bash
# shellcheck disable=SC2016

set -euo pipefail

WORK_DIR="tmp"
OPENWRT_REPO="$WORK_DIR/openwrt"
OUTPUT_FILE="$WORK_DIR/versions-$(date +%Y%m%d-%H%M%S).txt"
SSH_OPTS=(-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=1 -o ServerAliveCountMax=3)

LOCATION_FILTER=""
UPDATE_THRESHOLD_DAYS=0

usage() {
	echo "Usage: $0 [-l LOCATION] [-d DAYS] [-h]"
	echo ""
	echo "Options:"
	echo "  -l LOCATION   Filter hosts to a specific location (e.g., w38b)"
	echo "  -d DAYS       Only add hosts to update list if outdated by at least DAYS (default: 0)"
	echo "  -h            Show this help message"
	echo ""
	echo "Examples:"
	echo "  $0                Check all hosts"
	echo "  $0 -l w38b        Check only w38b hosts"
	echo "  $0 -d 7           Only add hosts outdated by 7+ days to update list"
	exit 1
}

while getopts "l:d:h" opt; do
	case $opt in
	l)
		LOCATION_FILTER="$OPTARG"
		;;
	d)
		UPDATE_THRESHOLD_DAYS="$OPTARG"
		;;
	h)
		usage
		;;
	*)
		usage
		;;
	esac
done

get_model_version() {
	local model="$1"
	local model_file="group_vars/model_${model//-/_}.yml"
	yq -r '.openwrt_version' "$model_file" 2>/dev/null || echo ""
}

check_host() {
	local hostname="$1"
	local model="$2"
	local ssh_host="${hostname}.ff"

	local version_info
	version_info=$(timeout 20 ssh "${SSH_OPTS[@]}" "root@$ssh_host" "cat /etc/openwrt_release" 2>/dev/null) || return 1

	local openwrt_version build_rev build_hash expected_version
	openwrt_version=$(echo "$version_info" | grep -E "^DISTRIB_RELEASE=" | cut -d"'" -f2)
	build_rev=$(echo "$version_info" | grep -E "^DISTRIB_REVISION=" | cut -d"'" -f2 | grep -oE "^r[0-9]+")
	build_hash=$(echo "$version_info" | grep -E "^DISTRIB_REVISION=" | cut -d"'" -f2 | grep -oE "[a-f0-9]+$")
	expected_version=$(get_model_version "$model")

	echo "$hostname|$openwrt_version|$expected_version|$build_rev|$build_hash"
}

clone_or_update_repo() {
	if [ -d "$OPENWRT_REPO/.git" ]; then
		echo "Updating OpenWRT repository..."
		git -C "$OPENWRT_REPO" fetch --quiet origin 'refs/heads/*:refs/remotes/origin/*'
	else
		echo "Cloning OpenWRT repository..."
		mkdir -p "$WORK_DIR"
		git clone --quiet git@github.com:openwrt/openwrt.git "$OPENWRT_REPO"
		git -C "$OPENWRT_REPO" fetch --quiet origin 'refs/heads/*:refs/remotes/origin/*'
	fi
}

init_output() {
	mkdir -p "$(dirname "$OUTPUT_FILE")"
	: >"$OUTPUT_FILE"
}

log() {
	echo "$@" | tee -a "$OUTPUT_FILE"
}

version_to_branch() {
	local version="$1"
	local major minor
	version=$(echo "$version" | sed 's/-SNAPSHOT//' | sed 's/-.*//')
	major=$(echo "$version" | cut -d. -f1)
	minor=$(echo "$version" | cut -d. -f2)
	if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$minor" =~ ^[0-9]+$ ]]; then
		echo "openwrt-$major.$minor"
	else
		echo "main"
	fi
}

get_commit_date() {
	local repo="$1"
	local hash="$2"
	git -C "$repo" log -1 --format="%ct" "$hash" 2>/dev/null
}

get_branch_tip() {
	local repo="$1"
	local branch="$2"
	git -C "$repo" rev-parse "origin/$branch" 2>/dev/null || git -C "$repo" rev-parse "$branch" 2>/dev/null
}

time_ago() {
	local seconds="$1"
	local minutes hours days weeks months years

	seconds=${seconds#-}

	if [ "$seconds" -eq 0 ]; then
		echo "up-to-date"
		return
	fi

	if [ "$seconds" -lt 60 ]; then
		echo "${seconds}s ago"
		return
	fi

	minutes=$((seconds / 60))
	if [ "$minutes" -lt 60 ]; then
		echo "${minutes}m ago"
		return
	fi

	hours=$((minutes / 60))
	if [ "$hours" -lt 24 ]; then
		echo "${hours}h ago"
		return
	fi

	days=$((hours / 24))
	if [ "$days" -lt 30 ]; then
		echo "${days}d ago"
		return
	fi

	weeks=$((days / 7))
	if [ "$weeks" -lt 12 ]; then
		echo "${weeks}w ago"
		return
	fi

	months=$((days / 30))
	if [ "$months" -lt 12 ]; then
		echo "${months}mo ago"
		return
	fi

	years=$((days / 365))
	echo "${years}y ago"
}

check_outdated() {
	local repo="$1"
	local hash="$2"
	local branch="$3"

	local local_date tip_hash tip_date
	local_date=$(get_commit_date "$repo" "$hash")
	tip_hash=$(get_branch_tip "$repo" "$branch")

	if [ -z "$local_date" ] || [ -z "$tip_hash" ]; then
		echo "?|0"
		return
	fi

	if [ "${tip_hash:0:${#hash}}" = "$hash" ]; then
		echo "OK|0"
		return
	fi

	tip_date=$(get_commit_date "$repo" "$tip_hash")
	if [ -z "$tip_date" ]; then
		echo "?|0"
		return
	fi

	local diff=$((tip_date - local_date))
	echo "$(time_ago $diff)|$diff"
}

init_output

echo "Extracting hosts from location files..."
if [ -n "$LOCATION_FILTER" ]; then
	mapfile -t HOSTS < <(yq -r '.model as $loc_model | .hosts[] | "\(.hostname)\t\(.model // $loc_model)"' "locations/${LOCATION_FILTER}.yml" 2>/dev/null)
else
	mapfile -t HOSTS < <(yq -r '.model as $loc_model | .hosts[] | "\(.hostname)\t\(.model // $loc_model)"' locations/*.yml 2>/dev/null)
fi

log "Checking ${#HOSTS[@]} hosts..."
log ""

results=()
unreachable=()

for entry in "${HOSTS[@]}"; do
	hostname="${entry%%$'\t'*}"
	model="${entry##*$'\t'}"
	if result=$(check_host "$hostname" "$model"); then
		results+=("$result")
		log "$hostname OK"
	else
		unreachable+=("$hostname")
		log "$hostname unreachable"
	fi
done

if [ ${#results[@]} -eq 0 ]; then
	echo "No reachable hosts found."
	exit 0
fi

log ""
log "Updating OpenWRT repository..."
clone_or_update_repo

declare -A branch_cache
for result in "${results[@]}"; do
	ver=$(echo "$result" | cut -d'|' -f2)
	if [ -z "${branch_cache[$ver]:-}" ]; then
		branch_cache[$ver]=$(version_to_branch "$ver")
	fi
done

UPDATE_TMP="$WORK_DIR/update.tmp"
UPDATE_FILE="$WORK_DIR/update.txt"
: >"$UPDATE_TMP"

UPDATE_THRESHOLD_SECONDS=$((UPDATE_THRESHOLD_DAYS * 86400))

log ""
log "========================================"
log ""

log "$(printf '| %-64s | %-14s | %-14s | %-9s | %-9s | %-26s |' 'HOST' 'OPENWRT' 'EXPECTED' 'BUILD_REV' 'BUILD_HASH' 'STATUS')"
log '| :--------------------------------------------------------------- | :------------- | :------------- | --------: | :--------- | :------------------------- |'

printf '%s\n' "${results[@]}" | sort -t'|' -k2,2V -k3,3V -k4,4V -k5,5V -k1,1 | while IFS='|' read -r host ver expected rev hash; do
	branch="${branch_cache[$ver]}"
	status_info=$(check_outdated "$OPENWRT_REPO" "$hash" "$branch")
	status="${status_info%|*}"
	age_seconds="${status_info#*|}"
	if [ "$ver" != "$expected" ]; then
		display_expected="$expected"
	else
		display_expected=""
	fi
	if [[ "$expected" == 24.10* ]] || [[ "$expected" == 25.12* ]] || [[ "$expected" == "SNAPSHOT" ]]; then
		if [ "$status" != "OK" ] && [ "$age_seconds" -ge "$UPDATE_THRESHOLD_SECONDS" ]; then
			echo "$host" >>"$UPDATE_TMP"
		fi
	fi
	log "$(printf '| %-64s | %-14s | %-14s | %9s | %-9s | %-26s |' "$host" "$ver" "$display_expected" "$rev" "$hash" "$status")"
done

sort -u "$UPDATE_TMP" >"$UPDATE_FILE"
rm -f "$UPDATE_TMP"
update_count=$(wc -l <"$UPDATE_FILE")
echo "Update list saved to: $UPDATE_FILE ($update_count hosts)"

log ""
log "========================================"
log ""
log "Summary: ${#results[@]} reachable, ${#unreachable[@]} unreachable"

if [ ${#unreachable[@]} -gt 0 ]; then
	log ""
	log "Unreachable hosts:"
	for h in "${unreachable[@]}"; do
		log "  - $h"
	done
fi

echo ""
echo "Output saved to: $OUTPUT_FILE"
