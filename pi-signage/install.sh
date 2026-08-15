#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# pi-signage installer
# Run this ON the Raspberry Pi (Raspberry Pi OS with Desktop, X11 or Wayfire).
#
#   chmod +x install.sh
#   ./install.sh
#
# What it does:
#   1. Installs Chromium if missing
#   2. Copies the player into ~/pi-signage
#   3. Creates an XDG autostart entry so Chromium launches in kiosk mode
#      on every boot/login
#   4. Installs a watchdog service that relaunches Chromium if it crashes
# ---------------------------------------------------------------------------
set -euo pipefail

APP_DIR="$HOME/pi-signage"
AUTOSTART_DIR="$HOME/.config/autostart"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Chromium (if needed)..."
if ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium
fi

CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium)"
echo "==> Using browser: $CHROMIUM_BIN"

echo "==> Deploying player to $APP_DIR"
mkdir -p "$APP_DIR"
cp -r "$SCRIPT_DIR/index.html" "$SCRIPT_DIR/config.json" "$APP_DIR/"

if [ ! -f "$APP_DIR/config.json" ]; then
  echo "WARNING: config.json missing — edit $APP_DIR/config.json before starting."
fi

echo "==> Disabling screen blanking / power saving"
mkdir -p "$HOME/.config/lxsession/LXDE-pi" 2>/dev/null || true
if [ -d "$HOME/.config/lxsession/LXDE-pi" ]; then
  AUTOSTART_LXDE="$HOME/.config/lxsession/LXDE-pi/autostart"
  touch "$AUTOSTART_LXDE"
  grep -qxF '@xset s off' "$AUTOSTART_LXDE" || echo '@xset s off' >> "$AUTOSTART_LXDE"
  grep -qxF '@xset -dpms' "$AUTOSTART_LXDE" || echo '@xset -dpms' >> "$AUTOSTART_LXDE"
  grep -qxF '@xset s noblank' "$AUTOSTART_LXDE" || echo '@xset s noblank' >> "$AUTOSTART_LXDE"
fi

echo "==> Creating launcher script"
cat > "$APP_DIR/launch-kiosk.sh" <<EOF
#!/usr/bin/env bash
# Waits for network, then launches Chromium in kiosk mode pointed at the player.
sleep 5
exec "$CHROMIUM_BIN" \\
  --kiosk \\
  --noerrdialogs \\
  --disable-infobars \\
  --disable-session-crashed-bubble \\
  --disable-features=TranslateUI \\
  --autoplay-policy=no-user-gesture-required \\
  --incognito \\
  --check-for-update-interval=1 \\
  "file://$APP_DIR/index.html"
EOF
chmod +x "$APP_DIR/launch-kiosk.sh"

echo "==> Installing XDG autostart entry"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/pi-signage.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Pi Signage
Exec=$APP_DIR/launch-kiosk.sh
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF

echo "==> Installing watchdog (systemd user service)"
mkdir -p "$SYSTEMD_USER_DIR"
cp "$SCRIPT_DIR/pi-signage-watchdog.sh" "$APP_DIR/"
chmod +x "$APP_DIR/pi-signage-watchdog.sh"
cat > "$SYSTEMD_USER_DIR/pi-signage-watchdog.service" <<EOF
[Unit]
Description=Pi Signage Watchdog (relaunches kiosk browser if it dies)
After=graphical-session.target

[Service]
ExecStart=$APP_DIR/pi-signage-watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable pi-signage-watchdog.service
systemctl --user start pi-signage-watchdog.service || true

echo ""
echo "============================================================"
echo " Install complete."
echo ""
echo " 1. Edit $APP_DIR/config.json and set 'manifestUrl' to wherever"
echo "    you're hosting your manifest.json (GitHub raw file, your"
echo "    own web server, S3 bucket, etc.)"
echo ""
echo " 2. Make sure the Pi is set to auto-login to the desktop:"
echo "    sudo raspi-config -> System Options -> Boot / Auto Login"
echo "    -> Desktop Autologin"
echo ""
echo " 3. Reboot to test:  sudo reboot"
echo "============================================================"
