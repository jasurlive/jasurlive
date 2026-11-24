#!/usr/bin/env bash

set -euo pipefail

IFACE="wlp1s0mon"
DIR="$HOME/hack"
FILE="$DIR/jasurscap.pcap"

mkdir -p "$DIR"

if ! ip link show "$IFACE" >/dev/null 2>&1; then
    echo "ERROR: $IFACE does not exist."
    exit 1
fi

echo "Interface: $IFACE"
echo "Saving to: $FILE"
echo "Starting live capture..."

sudo tshark \
    -i "$IFACE" \
    -w "$FILE"
