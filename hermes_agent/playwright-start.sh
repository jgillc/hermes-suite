#!/bin/bash
# Startup script for the self-hosted Playwright/CDP browser container.
# Replaces the default `npx playwright run-server` command so the container
# exposes Chrome/Chromium's DevTools Protocol (CDP) for Hermes browser tools.
#
# Usage (podman run):
#   -v ./playwright-start.sh:/start.sh:Z   \
#   --entrypoint /start.sh                  \

set -euo pipefail

CHROME_BIN=$(find /ms-playwright -name chrome -type f -path '*/chrome-linux/chrome' 2>/dev/null | head -1)

if [ -z "$CHROME_BIN" ]; then
  echo "ERROR: No Chrome binary found under /ms-playwright"
  exit 1
fi

echo "Starting Chrome (CDP) from: $CHROME_BIN"

# Start Chrome headless with remote debugging on port 9222.
# Chrome ignores --remote-debugging-address in headless mode and binds to
# 127.0.0.1, so we use a Python TCP proxy to forward from 0.0.0.0:9223.
"$CHROME_BIN" \
  --headless \
  --disable-gpu \
  --no-sandbox \
  --disable-dev-shm-usage \
  --remote-debugging-port=9222 \
  --no-first-run \
  --hide-scrollbars \
  --window-size=1280,720 \
  --user-data-dir=/tmp/chrome-cdp-data &

CHROME_PID=$!
echo "Chrome PID: $CHROME_PID"

# Wait for Chrome to start listening
for i in $(seq 1 10); do
  if curl -sf http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
    echo "Chrome CDP ready on 127.0.0.1:9222"
    break
  fi
  sleep 1
done

# Forward 0.0.0.0:9223 → 127.0.0.1:9222 so other containers can reach it.
# Install socat (cached by apt after first run) for a clean TCP forward.
echo "Setting up TCP forward: 0.0.0.0:9223 → 127.0.0.1:9222"
apt-get update -qq && apt-get install -y -qq --no-install-recommends socat >/dev/null 2>&1
exec socat TCP-LISTEN:9223,fork,reuseaddr TCP:127.0.0.1:9222
