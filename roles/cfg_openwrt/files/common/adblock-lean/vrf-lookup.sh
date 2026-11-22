#!/bin/sh
# shellcheck disable=SC3043  # busybox ash supports local
# Sourced by adblock-lean, see custom_script in /etc/adblock-lean/config.
#
# A dnsmasq instance in a VRF can only be reached from inside the VRF, so
# run the lookups which test such an instance there.

nslookup() {
	local dev vrf

	dev=$(ip -o addr show to "$2" 2>/dev/null | awk '{ print $2; exit }')
	[ -n "$dev" ] && ip -o -d link show dev "$dev" 2>/dev/null | grep -q ' vrf_slave ' &&
		vrf=$(ip -o link show dev "$dev" | sed -n 's/.* master \([^ ]*\).*/\1/p')

	if [ -n "$vrf" ]; then
		ip vrf exec "$vrf" busybox nslookup "$@"
	else
		busybox nslookup "$@"
	fi
}
