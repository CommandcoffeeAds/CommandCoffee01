#!/usr/bin/env bash
# Keeps the kiosk browser alive. Runs as a systemd user service (Restart=always
# handles the outer loop), this script just checks every 30s and relaunches
# Chromium if the process has died without systemd noticing yet.
set -u

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$APP_DIR/launch-kiosk.sh"

while true; do
  if ! pgrep -f "chromium.*kiosk" >/dev/null 2>&1; then
    echo "$(date): kiosk browser not running, launching..."
    export DISPLAY="${DISPLAY:-:0}"
    "$LAUNCHER" &
  fi
  sleep 30
done
