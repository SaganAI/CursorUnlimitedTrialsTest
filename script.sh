#!/bin/bash

# Cursor Trial Reset Script for Mac - Automates Quick Reset (Solution 1)
# Based on https://github.com/yuaotian/go-cursor-help
# Run with: copy-paste into Terminal. Requires sudo for optional MAC spoof.

set -e  # Exit on error

echo "=== Cursor Trial Reset Script (Mac) ==="
echo "Closing Cursor if running..."

# Kill Cursor processes safely
pkill -f "Cursor" || true
sleep 2  # Wait for full quit

# Config paths
STORAGE_DIR="$HOME/Library/Application Support/Cursor/User/globalStorage"
STORAGE_FILE="$STORAGE_DIR/storage.json"
BACKUP_FILE="$STORAGE_DIR/storage.json.backup"

# Create dir if missing
mkdir -p "$STORAGE_DIR"

# Backup existing storage.json
if [ -f "$STORAGE_FILE" ]; then
    cp "$STORAGE_FILE" "$BACKUP_FILE"
    echo "Backed up $STORAGE_FILE to $BACKUP_FILE"
else
    echo "No existing storage.json found; will create new."
fi

# Generate new UUIDs for all telemetry fields
UUID_MACHINE=$(uuidgen)
UUID_MAC=$(uuidgen)
UUID_DEV=$(uuidgen)
UUID_SQM=$(uuidgen)

echo "Generated new UUIDs:"
echo "- machineId: $UUID_MACHINE"
echo "- macMachineId: $UUID_MAC"
echo "- devDeviceId: $UUID_DEV"
echo "- sqmId: $UUID_SQM"

# Create/update storage.json with new IDs
cat > "$STORAGE_FILE" << EOF
{
  "telemetry.machineId": "$UUID_MACHINE",
  "telemetry.macMachineId": "$UUID_MAC",
  "telemetry.devDeviceId": "$UUID_DEV",
  "telemetry.sqmId": "$UUID_SQM"
}
EOF

echo "Updated $STORAGE_FILE with new IDs."

# Optional: MAC Address Spoof (for extra reset; skips if n)
read -p "Spoof Wi-Fi MAC address for full anonymity? (y/n, recommended but may disrupt network temporarily): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Finding Wi-Fi interface..."
    WIFI_IFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}' | head -1)
    if [ -z "$WIFI_IFACE" ]; then
        echo "Error: No Wi-Fi interface found (e.g., en0). Skipping MAC spoof."
    else
        echo "Wi-Fi interface: $WIFI_IFACE"
        
        # Backup original MAC
        ORIGINAL_MAC=$(ifconfig "$WIFI_IFACE" | grep ether | awk '{print $2}')
        BACKUP_MAC_FILE="$HOME/.cursor_mac_backup.txt"
        echo "$WIFI_IFACE:$ORIGINAL_MAC" > "$BACKUP_MAC_FILE"
        echo "Backed up original MAC to $BACKUP_MAC_FILE"
        
        # Generate random MAC (6 random bytes)
        NEW_MAC=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | tr '[:lower:]' '[:upper:]')
        
        # Apply new MAC (requires sudo)
        echo "Applying new MAC: $NEW_MAC (enter sudo password if prompted)..."
        sudo ifconfig "$WIFI_IFACE" ether "$NEW_MAC"
        
        echo "MAC spoof applied! Reconnect Wi-Fi if needed (System Settings > Network > Wi-Fi > Renew DHCP)."
        echo "To revert: sudo ifconfig $WIFI_IFACE ether $ORIGINAL_MAC"
    fi
else
    echo "Skipping MAC spoof."
fi

# Disable auto-updates (per repo; for v0.45.11 and below)
echo "Disabling auto-updates..."
cd /Applications/Cursor.app/Contents/Resources || { echo "Cursor.app not found in /Applications; skipping update disable."; }
if [ -f "app-update.yml" ]; then
    mv app-update.yml app-update.yml.bak
fi
touch app-update.yml
chmod 444 app-update.yml
rm -rf "$HOME/Library/Application Support/Caches/cursor-updater"
touch "$HOME/Library/Application Support/Caches/cursor-updater"
echo "Auto-update disabled (set Mode to 'none' in Cursor Settings > Application > Update after reopening)."

# Verify
echo "Verification:"
if [ -f "$STORAGE_FILE" ]; then
    grep -E "(machineId|macMachineId|devDeviceId|sqmId)" "$STORAGE_FILE" | head -4
else
    echo "Error: storage.json not created!"
    exit 1
fi

echo ""
echo "=== Done! ==="
echo "Reopen Cursor, sign in, and enjoy unlimited trials."
echo "If issues: Restore backup with 'cp $BACKUP_FILE $STORAGE_FILE' or reply with errors."
echo "For MAC revert: See backup file or reboot."
