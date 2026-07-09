#!/bin/sh

IFACE="$1"

while sleep 60; do

line="$(iwinfo "$IFACE" info 2>/dev/null | awk '/Channel:/ {print; exit}')"
[ -n "$line" ] || exit 0

CH="$(echo "$line" | sed -n 's/.*Channel:[[:space:]]*\([0-9]\+\).*/\1/p')"
inside="$(echo "$line" | sed -n 's/.*( *\([^)]*\) *).*/\1/p')"  # e.g. "5.300 GHz"
NUM="$(echo "$inside" | awk '{print $1}')"
UNIT="$(echo "$inside" | awk '{print $2}')"

MHZ=""
case "$UNIT" in
  GHz) MHZ="$(awk -v n="$NUM" 'BEGIN{printf "%.3f", n*1000}')";;
  MHz) MHZ="$(awk -v n="$NUM" 'BEGIN{printf "%.3f", n}')";;
  Khz|KHz) MHZ="$(awk -v n="$NUM" 'BEGIN{printf "%.3f", n/1000}')";;
  Hz) MHZ="$(awk -v n="$NUM" 'BEGIN{printf "%.3f", n/1000000}')";;
esac

[ -n "$CH" ] && [ -n "$MHZ" ] || exit 0

HOST="$(/bin/hostname -s 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null)"
[ -n "$HOST" ] || HOST="localhost"

echo "PUTVAL \"${HOST}/iwinfo-${IFACE}/gauge-channel\" N:${CH}"
echo "PUTVAL \"${HOST}/iwinfo-${IFACE}/gauge-frequency_mhz\" N:${MHZ}"

done
