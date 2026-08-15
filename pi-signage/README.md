# Pi Signage

A minimal digital signage / ad-loop player for Raspberry Pi. It's just a
Chromium browser in kiosk mode, showing a slideshow driven by a JSON
manifest that you host anywhere. **Updating the ads just means editing that
JSON file** — you never need to touch the Pi again after setup.

## How it works

- `index.html` — the player. Full-screen slideshow of images/videos.
- `config.json` — lives on the Pi, tells the player where to find your
  remote manifest and how often to check for changes.
- `manifest.json` — **hosted remotely by you** (GitHub, S3, your own
  server — anywhere reachable over HTTPS). Lists the slides to show.
- The player fetches the manifest on startup and re-checks it every
  `refreshIntervalMinutes` (default 5). If it changed, the new content
  takes over automatically — no restart needed.
- The last-known-good manifest is cached in the browser's localStorage,
  so the Pi keeps looping familiar content if the network briefly drops.

## 1. Host your manifest

Simplest option: put a `manifest.json` in a public GitHub repo and use the
raw URL, e.g.:

```
https://raw.githubusercontent.com/yourname/yourrepo/main/manifest.json
```

Format (see `content/manifest.example.json`):

```json
{
  "items": [
    { "type": "image", "url": "https://example.com/ad1.jpg", "duration": 10 },
    { "type": "video", "url": "https://example.com/ad2.mp4", "maxSeconds": 60 }
  ]
}
```

- `type`: `"image"` or `"video"`
- `duration`: seconds to show an image (defaults to `slideDurationSeconds` in config.json)
- `maxSeconds`: safety cap for videos in case playback stalls

Images/videos themselves can be hosted anywhere too (they don't need to be
next to the manifest) — a CDN, your own site, GitHub, etc.

**To update the ad loop later**: just edit and re-upload `manifest.json`.
Every Pi running this player picks up the change within one refresh
interval, with zero manual intervention.

## 2. Set up the Raspberry Pi

Requirements: Raspberry Pi OS **with Desktop** (not Lite), set to boot to
desktop with auto-login.

```bash
sudo raspi-config
# System Options -> Boot / Auto Login -> Desktop Autologin
```

Copy this whole `pi-signage` folder onto the Pi, then:

```bash
cd pi-signage
chmod +x install.sh
./install.sh
```

Edit `~/pi-signage/config.json` and set `manifestUrl` to your hosted
manifest URL.

Reboot to test:

```bash
sudo reboot
```

The Pi should boot straight to the desktop and Chromium should launch
full-screen with your slideshow, no further input needed.

## 3. What the installer sets up

- **Autostart**: `~/.config/autostart/pi-signage.desktop` launches
  Chromium in kiosk mode on every login (XDG autostart — works across
  Raspberry Pi OS's desktop environments).
- **No screen blanking**: disables X11 screensaver/DPMS so the display
  doesn't sleep.
- **Watchdog**: a systemd user service (`pi-signage-watchdog.service`)
  checks every 30s that the kiosk browser is still running and relaunches
  it if it crashed or was closed.

## Updating the player software itself

Routine content updates never require touching the Pi. But if you want to
change the *player code* (e.g. add new transition effects), the simplest
approach for a fleet of Pis is:

1. Put this whole folder in a git repo.
2. On each Pi, add a cron job to `git pull` periodically and re-run
   `install.sh` if files changed:

```bash
crontab -e
# Add:
0 3 * * * cd /home/pi/pi-signage-src && git pull --quiet && ./install.sh >> /home/pi/pi-signage-update.log 2>&1
```

(Keep the git checkout in a separate folder like `pi-signage-src` and have
`install.sh` copy from there into `~/pi-signage`, which is already how the
script is written.)

For just a couple of Pis, `ssh`-ing in and re-running `install.sh` by hand
is also perfectly fine.

## Troubleshooting

- **Black screen after boot**: check auto-login is enabled and that
  `~/.config/autostart/pi-signage.desktop` exists.
- **Browser not relaunching after crash**: `systemctl --user status
  pi-signage-watchdog.service`
- **Content not updating**: check `config.json`'s `manifestUrl` is
  reachable from the Pi (`curl <manifestUrl>`), and check browser console
  via `chromium-browser --remote-debugging-port=9222` for fetch errors.
- **Wayland/Wayfire (Raspberry Pi OS Bookworm)**: XDG autostart is
  supported, but if kiosk launch doesn't fire, add the same
  `launch-kiosk.sh` command to `~/.config/wayfire.ini` under `[autostart]`.
