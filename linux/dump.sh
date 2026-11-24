#!/usr/bin/env bash

set -euo pipefail

IFACE="wlp1s0"
DIR="$HOME/hack"

mkdir -p "$DIR"

echo "Wireless interface:"
iw dev

echo
echo "Starting packet capture..."
echo "Press Ctrl+C to stop."

sudo tcpdump -i "$IFACE" -s 0 \
    -w "$DIR/jascapture.pcap"
