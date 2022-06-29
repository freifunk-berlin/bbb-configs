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

ownip="$(wget -qO- https://ipv6.icanhazip.com)"

# Todo: Fix SC2181
if [ $? -ne 0 ]; then
  log "Error while retrieving IPv6 Address - Check Connectivity?!"
  exit
fi

if [[ "$ownip" != "2001:bf7:*" ]]; then
  log "Public IPv6 is not part of freifunk berlin prefix"
  exit
fi

for _port in $PORTS; do
  # Todo: Check if something is listning on the port (/proc/net/tcp6)
  log "Registering [$ownip]:$_port with hostname $hostname"
  curl -d"{\"labels\":{\"hostname\":\"$hostname\",\"role\":\"$role\",\"location\":\"$location\"},\"targets\":[\"[$ownip]:$_port\"],\"hostname\":\"$hostname\"}" \
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
