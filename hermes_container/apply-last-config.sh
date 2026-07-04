#!/bin/bash
# =============================================================================
# apply-last-config.sh — Copies the last-used hermes config into place
# Called by the systemd service ExecStartPre so the correct config tier
# (free/cheap/normal) is used after a reboot.
# =============================================================================
LAST_CONFIG_FILE="${HOME}/.hermes/.last_config"
TARGET_CONFIG="${HOME}/.hermes/config.yaml"

if [ ! -f "$LAST_CONFIG_FILE" ]; then
    exit 0
fi

SOURCE_CONFIG=$(cat "$LAST_CONFIG_FILE" 2>/dev/null)

if [ -z "$SOURCE_CONFIG" ] || [ ! -f "$SOURCE_CONFIG" ]; then
    exit 0
fi

mkdir -p "$(dirname "$TARGET_CONFIG")"
cp "$SOURCE_CONFIG" "$TARGET_CONFIG"
