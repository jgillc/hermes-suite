#!/bin/bash
# =============================================================================
# setup-hermes-service.sh — Create / update the systemd user service for
# Hermes Suite so it starts automatically on boot with the last-used config.
#
# Idempotent — safe to run repeatedly.
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
HERMES_SUITE_DIR="$REPOS_DIR/hermes-suite"
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/hermes-suite.service"

mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_FILE" << UNITEOF
[Unit]
Description=Hermes Suite — agent gateway, web UI, and dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=${SCRIPT_DIR}/apply-last-config.sh
ExecStart=${HERMES_SUITE_DIR}/up.sh
ExecStop=${HERMES_SUITE_DIR}/down.sh

[Install]
WantedBy=default.target
UNITEOF

systemctl --user daemon-reload
systemctl --user enable hermes-suite.service

echo "Hermes Suite systemd service installed (${SERVICE_FILE})"
