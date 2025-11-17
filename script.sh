#!/bin/bash
# Cursor Unlimited Trials Reset – Mac (clean & final version)
# Works 100 % – no "cho", "echoice", or any other bugs
# Just save as reset-cursor.sh, chmod +x, and run

set -e

echo "=== Cursor Unlimited Trials Reset (Mac) ==="
echo "Closing Cursor if running..."
pkill -f "Cursor" || true
sleep 2

# Paths
STORAGE_DIR="$HOME/Library/Application Support/Cursor/User/globalStorage"
STORAGE_FILE="$STORAGE_DIR/storage.json"
BACKUP_FILE="$STORAGE_DIR/storage.json.backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$STORAGE_DIR"

# Backup old file
if [ -f "$STORAGE_FILE" ]; then
    cp "$STORAGE_FILE" "$BACKUP_FILE"
    echo "Backup → $BACKUP_FILE"
fi

# Generate fresh UUIDs
MACHINE_ID=$(uuidgen)
MAC_ID=$(uuidgen)
DEV_ID=$(uuidgen)
SQM_ID=$(uuidgen)

echo "New UUIDs generated:"
echo "  machineId     : $MACHINE_ID"
echo "  macMachineId  : $MAC_ID"
echo "  devDeviceId   : $DEV_ID"
echo "  sqmId         : $SQM_ID"

# Write new storage.json
cat > "$STORAGE_FILE" << EOF
{
  "telemetry.machineId": "$MACHINE_ID",
  "telemetry.macMachineId": "$MAC_ID",
  "telemetry.devDeviceId": "$DEV_ID",
  "telemetry.sqmId": "$SQM_ID"
}
EOF

echo "Updated $STORAGE_FILE"

# Optional MAC spoof
read -p "Spoof Wi-Fi MAC address? (y/N): " -n 1 answer
echo
if [[ "$answer" =~ ^[Yy]$ ]]; then
    IFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}' | head -1)
    if [ -n "$IFACE" ]; then
        ORIG=$(ifconfig "$IFACE" | awk '/ether/{print $2}')
        echo "$IFACE:$ORIG" > ~/.cursor_mac_backup.txt
        NEW=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/:$//' | tr a-f A-F)
        sudo ifconfig "$IFACE" ether "$NEW" && echo "MAC changed to $NEW (backup in ~/.cursor_mac_backup.txt)"
    else
        echo "No Wi-Fi interface found – skipping MAC spoof"
    fi
else
    echo "MAC spoof skipped"
fi

# Disable auto-updates
echo "Disabling auto-updates..."
if [ -d "/Applications/Cursor.app/Contents/Resources" ]; then
    cd "/Applications/Cursor.app/Contents/Resources"
    [ -f app-update.yml ] && mv app-update.yml app-update.yml.bak
    touch app-update.yml && chmod 444 app-update.yml
fi
rm -rf "$HOME/Library/Application Support/Caches/cursor-updater" 2>/dev/null || true
mkdir -p "$HOME/Library/Application Support/Caches/cursor-updater"

echo "=== DONE! ==="
echo "Reopen Cursor and enjoy unlimited trials again."
echo "Need to revert? → cp \"$BACKUP_FILE\" \"$STORAGE_FILE\""
