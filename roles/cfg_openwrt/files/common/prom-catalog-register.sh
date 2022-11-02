#!/bin/sh
# shellcheck shell=dash disable=SC2169,SC2181,SC3010,SC3014
log() {
    local msg="$1"
    logger -t prom-catalog-register -s "$msg"
    # for debugging on local machine
    #echo "$msg"
}

dec2hex() {
    local dec="$1"
    printf "%X" "$dec"
}


PORTS="9100"
URL="https://prometheus-catalog.freifunk.ninja/register"
hostname="$(cat /proc/sys/kernel/hostname)"
role="$1"
location="$2"

log "started. Registering with following labels: hostname: $hostname, role: $role, location: $location"

log "Retrieving IPv6 Address"

mgmtdev=$(ubus call network.interface.mgmt status | jsonfilter -e '@.l3_device')
mgmtip="$(ip -6 addr show "$mgmtdev" scope global | awk '{ match($0, /[0-9a-f:]+\/\d+/); ip = substr($0, RSTART, RLENGTH); print ip }' | grep . | head -n1 | cut -d'/' -f1)"

if [[ "$mgmtip" != "2001:bf7:*" ]]; then
  log "Public IPv6 is not part of freifunk berlin prefix"
  exit
fi

for _port in $PORTS; do
  # Todo: Check if something is listning on the port (/proc/net/tcp6)
  log "Registering [$mgmtip]:$_port with hostname $hostname"
  curl -d"{\"labels\":{\"hostname\":\"$hostname\",\"role\":\"$role\",\"location\":\"$location\"},\"targets\":[\"[$mgmtip]:$_port\"],\"hostname\":\"$hostname\"}" \
      -H'Content-Type: application/json' \
      "$URL"
  # Todo: Fix SC2181
  if [ $? -eq 0 ]; then
    log "..success"
  else
    log "Error while registering"
  exit
fi
done
