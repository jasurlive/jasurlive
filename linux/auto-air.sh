
#!/usr/bin/env bash
set -Eeuo pipefail

IFACE="${1:-wlp1s0}"
OUT="$HOME/temp"
SESSION="$OUT/$(date +%Y%m%d-%H%M%S)"
MON_IFACE=""
TMP=""
CAPTURE=""

mkdir -p "$SESSION"/{captures,converted,results}

log() {
    printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$1"
}

cleanup() {
    [[ -n "$TMP" ]] && rm -f "$TMP" "$TMP"-01.csv
    if [[ -n "$MON_IFACE" ]]; then
        log "Restoring wireless interface..."
        sudo airmon-ng stop "$MON_IFACE" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM

for cmd in sudo airmon-ng airodump-ng rofi editcap hcxpcapngtool; do
    command -v "$cmd" >/dev/null || {
        echo "Missing dependency: $cmd"
        exit 1
    }
done

[[ -e "/sys/class/net/$IFACE" ]] || {
    echo "Interface not found: $IFACE"
    exit 1
}

log "Enabling monitor mode..."
sudo airmon-ng start "$IFACE"

MON_IFACE="${IFACE}mon"

[[ -e "/sys/class/net/$MON_IFACE" ]] || {
    echo "Monitor interface not found: $MON_IFACE"
    exit 1
}

log "Scanning available networks..."

TMP=$(mktemp)

sudo timeout 15 airodump-ng \
    --output-format csv \
    --write "$TMP" \
    "$MON_IFACE" >/dev/null 2>&1 || true

CSV="$TMP-01.csv"

[[ -s "$CSV" ]] || {
    echo "No scan results."
    exit 1
}

NETWORKS=$(awk -F',' '
/Station MAC/ { exit }
NF >= 14 && $1 ~ /:/ {
    for (i=1; i<=14; i++) gsub(/^ +| +$/, "", $i)
    if ($1 != "" && $4 ~ /^[0-9]+$/)
        printf "%s | CH:%s | %s | %s\n", $1, $4, $6, $14
}' "$CSV")

[[ -n "$NETWORKS" ]] || {
    echo "No networks found."
    exit 1
}

NETWORK=$(printf '%s\n' "$NETWORKS" |
    rofi -dmenu -i -p "Select your router")

[[ -n "$NETWORK" ]] || exit 0

BSSID=$(cut -d'|' -f1 <<< "$NETWORK" | xargs)
CHANNEL=$(sed -n 's/.*CH:\([0-9]*\).*/\1/p' <<< "$NETWORK")

[[ -n "$BSSID" && -n "$CHANNEL" ]] || {
    echo "Invalid selection."
    exit 1
}

log "Selected $BSSID on channel $CHANNEL"

CAPTURE="$SESSION/captures/wifi"

log "Starting passive capture..."
echo "Press Ctrl+C when finished."

sudo airodump-ng \
    --bssid "$BSSID" \
    --channel "$CHANNEL" \
    --write "$CAPTURE" \
    --output-format pcap \
    "$MON_IFACE" || true

PCAP="${CAPTURE}-01.cap"

[[ -s "$PCAP" ]] || {
    echo "No capture file generated."
    exit 1
}

log "Converting capture to PCAPNG..."

PCAPNG="$SESSION/converted/wifi.pcapng"

editcap -F pcapng "$PCAP" "$PCAPNG"

log "Extracting supported handshake data..."

HC22000="$SESSION/results/wifi.hc22000"

hcxpcapngtool -o "$HC22000" "$PCAPNG"

if [[ -s "$HC22000" ]]; then
    log "HC22000 file created successfully."
else
    rm -f "$HC22000"
    log "No supported handshake data found in capture."
fi

log "Audit completed."

printf '\nResults:\n%s\n' "$SESSION"
find "$SESSION" -type f -printf '%p (%s bytes)\n'
