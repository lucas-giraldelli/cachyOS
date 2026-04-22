# System Tray — Waybar on Hyprland/Wayland

## Root Cause of Missing Tray Icons

On Wayland, system tray icons use the **StatusNotifierItem (SNI)** D-Bus protocol. The SNI watcher must be owned by the bar (waybar) before apps register their icons. Two things break this:

1. **kded6 stealing the SNI watcher** — KDE daemon starts early and claims the watcher, so apps register to kded6 instead of waybar. Icons never appear.
2. **Electron apps using Wayland backend** — When Electron runs natively on Wayland (`--ozone-platform=wayland`), it bypasses `libappindicator-gtk3` entirely and doesn't emit a StatusNotifierItem. The icon is simply never registered on D-Bus.

You can confirm what's registered on D-Bus:
```bash
dbus-monitor --session "interface='org.kde.StatusNotifierWatcher'" 2>/dev/null &
# Then launch the app and watch for RegisterStatusNotifierItem calls
```

---

## kded6 Fix

kded6 can steal the SNI watcher on session start. If waybar loads after kded6, apps register to kded6 and icons disappear.

**Temporary fix:**
```bash
pkill kded6
pkill waybar
waybar &
```

**Permanent fix:** ensure waybar starts before kded6, or block kded6's `statusnotifierwatcher` module. Check `~/.config/hypr/hyprland.conf` autostart ordering.

---

## Discord — Use Vesktop

The official Discord Linux client has a long-standing unfixed bug where the tray icon does not register on Wayland. The community solution is **Vesktop**:

```bash
paru -S vesktop
```

Vesktop is an unofficial Discord client built on Vencord (optional mods). It has native Wayland support and correctly registers the SNI tray icon in waybar. Functionally identical to Discord for daily use.

---

## Slack — Force XWayland

Slack ships with Wayland flags that disable libappindicator, so the tray icon is never registered. Fix: force it to run via XWayland.

**`~/.local/share/applications/slack.desktop`:**
```ini
Exec=env XDG_CURRENT_DESKTOP=Unity ELECTRON_OZONE_PLATFORM_HINT=x11 /usr/bin/slack --ozone-platform=x11 --disable-gpu-sandbox -s %U
```

Key flags:
- `ELECTRON_OZONE_PLATFORM_HINT=x11` — tells Electron to prefer X11 before the app parses argv
- `--ozone-platform=x11` — forces XWayland backend
- `XDG_CURRENT_DESKTOP=Unity` — triggers libappindicator SNI registration path in Electron

After editing the `.desktop`, kill and relaunch Slack from the app launcher (not terminal) so it picks up the new flags.

---

## Why `XDG_CURRENT_DESKTOP=Unity` Alone Isn't Enough

This is a common suggestion but it only works when Electron is running on X11/XWayland. If Electron is using the Wayland backend, it skips libappindicator entirely regardless of `XDG_CURRENT_DESKTOP`. Both flags are required together.

---

## Summary

| App | Problem | Fix |
|-----|---------|-----|
| Discord | Native client never registers SNI on Wayland | Use Vesktop instead |
| Slack | Ships with `--ozone-platform=wayland`, skips libappindicator | Force XWayland + `XDG_CURRENT_DESKTOP=Unity` in `.desktop` |
| Any Electron app | Same Wayland backend issue | Add `ELECTRON_OZONE_PLATFORM_HINT=x11 --ozone-platform=x11` |
| All icons missing | kded6 stole the SNI watcher | `pkill kded6 && pkill waybar && waybar &` |
