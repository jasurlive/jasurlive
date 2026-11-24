
#!/usr/bin/env bash
set -Eeuo pipefail

IFACE="${1:-wlp1s0}"
OUT="$HOME/temp"
MON_IFACE=""
TMP=""

cleanup() {
    [[ -n "$TMP" ]] && rm -f "$TMP" "$TMP"-01.csv

    if [[ -n "$MON_IFACE" ]]; then
        sudo airmon-ng stop "$MON_IFACE" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM

for cmd in sudo airmon-ng airodump-ng rofi; do
    command -v "$cmd" >/dev/null || {
        echo "Missing dependency: $cmd"
        exit 1
    }
done

[[ -e "/sys/class/net/$IFACE" ]] || {
    echo "Interface not found: $IFACE"
    exit 1
}

mkdir -p "$OUT"

echo "Enabling monitor mode..."
sudo airmon-ng start "$IFACE"

MON_IFACE="${IFACE}mon"

[[ -e "/sys/class/net/$MON_IFACE" ]] || {
    echo "Monitor interface not found."
    exit 1
}

echo "Scanning networks..."

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
    rofi -dmenu -i -p "Select network")

[[ -n "$NETWORK" ]] || exit 0

BSSID=$(cut -d'|' -f1 <<< "$NETWORK" | xargs)
CHANNEL=$(sed -n 's/.*CH:\([0-9]*\).*/\1/p' <<< "$NETWORK")
NAME=$(awk -F'|' '{print $4}' <<< "$NETWORK" | xargs)

NAME=$(tr -cd '[:alnum:]_.-' <<< "$NAME")
NAME="${NAME:-Unknown}"

SESSION="$OUT/${NAME}_$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION"

echo "Selected: $NAME"
echo "BSSID: $BSSID"
echo "Channel: $CHANNEL"
echo "Folder: $SESSION"