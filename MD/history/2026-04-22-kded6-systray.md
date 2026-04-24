# 2026-04-22 — Waybar Systray Disappearing (kded6 Ghost)

## What happened

The waybar systray was randomly going blank — all tray icons (Slack, Vesktop, OpenVPN) would vanish. Restarting waybar did not fix it. The icons simply never came back.

## Investigation

Checked who owned the D-Bus `org.kde.StatusNotifierWatcher` name:

```bash
dbus-send --session --print-reply --dest=org.freedesktop.DBus \
  /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner \
  string:org.kde.StatusNotifierWatcher
```

Returned a process ID belonging to **kded6** — not waybar.

Then confirmed the object did not actually exist:

```bash
dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher \
  /StatusNotifierWatcher org.freedesktop.DBus.Introspect
# Error: No such object path '/StatusNotifierWatcher'
```

This is the "ghost": kded6 holds the D-Bus **name** but does not implement the **object** (its SNI module is disabled via `kded6rc`). Waybar starts, tries to register as SNI host, gets `UnknownObject`, and silently gives up — systray is dead.

## Root cause sequence

1. Boot: waybar starts → registers `org.kde.StatusNotifierWatcher` → systray works
2. Later: Dolphin opens → triggers `kactivitymanagerd` and `kded6` via D-Bus activation
3. kded6 can't steal the name while waybar holds it → harmless
4. Waybar crashes or restarts → releases the name
5. kded6 immediately grabs `org.kde.StatusNotifierWatcher` (ghost — name without object)
6. Waybar restarts → can't register → systray dead

## Fix applied

Created a systemd user service that kills kded6 **before every waybar start**, including crash auto-restarts:

**`~/.config/systemd/user/waybar.service`:**
```ini
[Service]
ExecStartPre=-/usr/bin/pkill kded6
ExecStartPre=/bin/sleep 0.5
ExecStart=/usr/bin/waybar
ExecStartPost=/bin/bash -c '(/home/lukesh/.config/waybar/tray-restart.sh) &'
Restart=on-failure
RestartSec=2
```

Also added `tray-restart.sh` — waits 3s for waybar to register the SNI watcher, then restarts Slack, Vesktop, and OpenVPN Connect (Electron apps that lose SNI registration when waybar restarts).

Removed `exec-once = waybar` from `hyprland.conf`, replaced with:
```
exec-once = systemctl --user start waybar.service
```

## Other fixes in this session

- Added Slack windowrule → pinned to workspace 2
- Added Vesktop windowrule → float, center, workspace 5
- Fixed OpenVPN Connect restart: runs as `electron37` process, must use `pkill -f "openvpn-connect-linux"` not `pkill -x openvpn-connect`
- Added `vpn-restart` fish function for manual OpenVPN Connect icon recovery
- Enabled waybar logging to `~/.config/waybar/waybar.log`
- Fixed `hyprpolkitagent` path: `/usr/lib/hyprpolkitagent/hyprpolkitagent`
