#!/bin/bash
# Bulletproof Cursor Trial Reset for Mac - Fixed & Complete (No Typos)
# Includes UUID refresh, optional MAC spoof, update disable. Run as-is.

set -e

echo "=== Bulletproof Cursor Trial Reset (Mac) ==="

# Kill Cursor safely
pkill -f Cursor || true
sleep 3
echo "Cursor closed."

# Paths
STORAGE_DIR="$HOME/Library/Application Support/Cursor/User/globalStorage"
STORAGE_FILE="$STORAGE_DIR/storage.json"
BACKUP_FILE="$STORAGE_DIR/storage.json.backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$STORAGE_DIR"

# Backup
if [ -f "$STORAGE_FILE" ]; then
    cp "$STORAGE_FILE" "$BACKUP_FILE"
    echo "Backup: $BACKUP_FILE"
else
    echo "No existing config; creating fresh."
fi

# Generate 4 new UUIDs (covers all telemetry trackers)
MACHINE_ID=$(uuidgen)
MAC_ID=$(uuidgen)
DEV_ID=$(uuidgen)
SQM_ID=$(uuidgen)

echo "Fresh UUIDs:"
echo "  machineId: $MACHINE_ID"
echo "  macMachineId: $MAC_ID"
echo "  devDeviceId: $DEV_ID"
echo "  sqmId: $SQM_ID"

# Write config (jq fallback if missing)
if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg m "$MACHINE_ID" --arg mac "$MAC_ID" --arg dev "$DEV_ID" --arg sqm "$SQM_ID" \
      '{telemetry: {machineId: $m, macMachineId: $mac, devDeviceId: $dev, sqmId: $sqm}}' > "$STORAGE_FILE"
    echo "Updated with jq."
else
    cat > "$STORAGE_FILE" << EOF
{
  "telemetry.machineId": "$MACHINE_ID",
  "telemetry.macMachineId": "$MAC_ID",
  "telemetry.devDeviceId": "$DEV_ID",
  "telemetry.sqmId": "$SQM_ID"
}
EOF
    echo "Updated with fallback."
fi

# Verify
if [ -f "$STORAGE_FILE" ] && grep -q "machineId" "$STORAGE_FILE"; then
    echo "Verified: New IDs in place."
    grep -E "(machineId|macMachineId)" "$STORAGE_FILE" | head -2
else
    echo "Error creating config! Check path: $STORAGE_FILE"
    exit 1
fi

# Optional MAC Spoof (clean prompt, no typos)
read -p "Spoof Wi-Fi MAC for extra reset? (y/N, may need Wi-Fi reconnect): " -n 1 choice
echo
if [[ $choice =~ ^[Yy]$ ]]; then
    IFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}' | head -1)
    if [ -n "$IFACE" ] && [ "$IFACE" != " " ]; then
        ORIG_MAC=$(ifconfig "$IFACE" 2>/dev/null | grep ether | awk '{print $2}' | head -1)
        if [ -n "$ORIG_MAC" ]; then
            echo "$IFACE:$ORIG_MAC" > ~/.cursor_mac_backup.txt
            NEW_MAC=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | tr 'a-f' 'A-F')
            echo "New MAC: $NEW_MAC | Original backed up to ~/.cursor_mac_backup.txt"
            echo "Applying... (sudo password if needed)"
            sudo ifconfig "$IFACE" ether "$NEW_MAC"
            echo "Done! Renew Wi-Fi lease if disconnected. Revert: sudo ifconfig $IFACE ether $ORIG_MAC"
        else
            echo "Couldn't read original MAC. Skipping."
        fi
    else
        echo "Wi-Fi interface not found (e.g., en0). Skipping."
    fi
else
    echo "MAC spoof skipped."
fi

# Disable auto-updates
echo "Disabling updates..."
CURSOR_RES="/Applications/Cursor.app/Contents/Resources"
if [ -d "$CURSOR_RES" ]; then
    pushd "$CURSOR_RES" >/dev/null
    if [ -f app-update.yml ]; then
        mv app-update.yml app-update.yml.bak
    fi
    touch app-update.yml
    chmod 444 app-update.yml
    popd >/dev/null
    echo "App update config locked."
else
    echo "Cursor.app not in /Applications; manual disable needed."
fi

CACHES_DIR="$HOME/Library/Application Support/Caches/cursor-updater"
rm -rf "$CACHES_DIR"
mkdir -p "$CACHES_DIR"
echo '{"mode": "none"}' > "$CACHES_DIR/update-config.json" 2>/dev/null || echo "Cache cleared (config write skipped)."

echo "Updates blocked. In Cursor: Settings > Application > Update > Mode: none"

echo "=== All Set! ==="
echo "Reopen Cursor, sign in—trials unlimited."
echo "Troubleshoot: cat $STORAGE_FILE | grep machineId"
echo "Restore: cp $BACKUP_FILE $STORAGE_FILE"
echo "MAC revert: cat ~/.cursor_mac_backup.txt + sudo ifconfig..."
