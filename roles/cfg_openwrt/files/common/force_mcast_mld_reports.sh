#!/bin/sh

# This hack toggles multicast flag on all configured interfaces except loopback
# in order to generate new MLD reports. Those are required, if there is no 
# multicast querier within the network and a switch has igmp_snooping enabled.
# 
# Ubiquiti Wave Series for instance have snooping enabled, which leads to
# frequent multicast group timeouts
#
# This script is running in infinite loop and called by rc.local

while sleep 120; do
  INTERFACES=$(grep -A1 "config interface" /etc/config/network | grep device | cut -d \' -f2 | grep -v 'lo')
  for i in $INTERFACES; do
    ip link set dev "$i" multicast off
    ip link set dev "$i" multicast on
  done
done

