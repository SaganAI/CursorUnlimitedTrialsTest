#!/bin/bash

# Fixed Cursor Unlimited Trials Reset Script for Mac
# Based on SaganAI repo with typo fix (choice var), jq fallback, and update disable
# Run: curl -fsSL https://tinyurl.com/cursor-reset-fixed | bash

set -e

echo "=== Starting Fixed Cursor Unlimited Trials Reset ==="

# Kill Cursor
pkill -f Cursor || true
sleep 3

# Paths
STORAGE_DIR="$HOME/Library/Application Support/Cursor/User/globalStorage"
STORAGE_FILE="$STORAGE_DIR/storage.json"
BACKUP_FILE="$STORAGE_DIR/storage.json.backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$STORAGE_DIR"

# Backup
if [ -f "$STORAGE_FILE" ]; then
    cp "$STORAGE_FILE" "$BACKUP_FILE"
    echo "Backup created: $BACKUP_FILE"
fi

# Generate UUIDs
MACHINE_ID=$(uuidgen)
MAC_ID=$(uuidgen)
DEV_ID=$(uuidgen)
SQM_ID=$(uuidgen)

echo "New IDs generated:"
echo "  machineId: $MACHINE_ID"
echo "  macMachineId: $MAC_ID"
echo "  devDeviceId: $DEV_ID"
echo "  sqmId: $SQM_ID"

# Write new storage.json (jq if available, else fallback)
if command -v jq >/dev/null 2>&1; then
    jq -n --arg m "$MACHINE_ID" --arg mac "$MAC_ID" --arg dev "$DEV_ID" --arg sqm "$SQM_ID" \
      '{telemetry: {machineId: $m, macMachineId: $mac, devDeviceId: $dev, sqmId: $sqm}}' > "$STORAGE_FILE"
    echo "Config updated with jq."
else
    echo "jq not found; using fallback write."
    cat > "$STORAGE_FILE" << EOF
{
  "telemetry.machineId": "$MACHINE_ID",
  "telemetry.macMachineId": "$MAC_ID",
  "telemetry.devDeviceId": "$DEV_ID",
  "telemetry.sqmId": "$SQM_ID"
}
EOF
fi

# Verify
if [ -f "$STORAGE_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
        jq -r '.telemetry.machineId // .["telemetry.machineId"]' "$STORAGE_FILE" && echo "Config verified OK."
    else
        grep -E "(machineId|macMachineId|devDeviceId|sqmId)" "$STORAGE_FILE" | head -4
    fi
else
    echo "Error: storage.json not created!"
    exit 1
fi

# Optional MAC Spoof (fixed variable name)
read -p "Spoof Wi-Fi MAC? (y/N): " -n 1 choice  # Fixed: was 'cho'
echo
if [[ "$choice" =~ ^[Yy]$ ]]; then
    IFACE=$(networksetup -listallhardwareports | grep -A1 'Wi-Fi' | grep 'Device' | awk '{print $2}' | head -1)
    if [ -n "$IFACE" ]; then
        ORIG_MAC=$(ifconfig "$IFACE" | grep ether | awk '{print $2}')
        echo "$IFACE:orig_mac:$ORIG_MAC" > ~/.cursor_mac_backup
        NEW_MAC=$(openssl rand -hex 6 | sed 's/../&:/g; s/:$//; s/\(.\)/\U\1/g')
        echo "Applying new MAC: $NEW_MAC (sudo password if prompted)..."
