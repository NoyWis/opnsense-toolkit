#!/bin/sh
MGMT_HOST="${MGMT_HOST:?set MGMT_HOST}"
echo "=== block rules for mgmt ports (want: block ... from ! $MGMT_HOST ... to (self) port = ssh/https) ==="
pfctl -sr 2>/dev/null | grep -nE "to \(self\) port = (ssh|https)"
echo
echo "=== lines with source negation of host ==="
pfctl -sr 2>/dev/null | grep -n "! $MGMT_HOST"
echo
echo "=== ssh service state ==="
service sshd status 2>/dev/null; sockstat -4 -l 2>/dev/null | grep -E "sshd|:22|\.22"
echo "=== END ==="
