# System Tray — Waybar on Hyprland/Wayland

## Root Cause of Missing Tray Icons

On Wayland, system tray icons use the **StatusNotifierItem (SNI)** D-Bus protocol. The SNI watcher must be owned by waybar before apps register their icons. Two things break this:

1. **kded6 stealing the SNI watcher** — KDE daemon starts early and claims the watcher, so apps register to kded6 instead of waybar. Icons never appear.
2. **Waybar restart** — When waybar is killed and restarted, all Electron apps lose their SNI registration and must be restarted too.

Check what's currently registered:
```bash
gdbus call --session --dest org.kde.StatusNotifierWatcher --object-path /StatusNotifierWatcher \
  --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
```

Check who owns the SNI watcher:
```bash
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.GetNameOwner org.kde.StatusNotifierWatcher
```

---

## kded6 — The Real Problem (Fully Diagnosed)

### What actually happens

kded6 is **not in the Hyprland autostart** — it is activated on-demand via **D-Bus activation** (triggered by blueman-applet or other KDE-dependent apps at session start).

The sequence that breaks the systray:

1. Boot: waybar starts first → registers `org.kde.StatusNotifierWatcher` on D-Bus → systray works
2. Later: some app (e.g. blueman-applet) triggers kded6 via D-Bus → kded6 starts
3. kded6 **cannot steal the name** (waybar holds it) → coexists harmlessly
4. Waybar crashes or is restarted → releases the D-Bus name
5. kded6 is **still running** → immediately grabs `org.kde.StatusNotifierWatcher`
6. kded6 holds the **name** but NOT the **object** `/StatusNotifierWatcher` (module is disabled via `kded6rc`)
7. Next waybar start → tries to register as SNI host → gets: `GDBus.Error:org.freedesktop.DBus.Error.UnknownObject: No such object path '/StatusNotifierWatcher'` → systray dead

The `kded6rc` fix (`autoload=false`) only disables the module — kded6 still registers the D-Bus **name** without implementing the object. This is the ghost that blocks waybar.

### Diagnostic commands

```bash
# Who owns the SNI watcher name?
dbus-send --session --print-reply --dest=org.freedesktop.DBus \
  /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner \
  string:org.kde.StatusNotifierWatcher

# Does the object actually exist?
dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher \
  /StatusNotifierWatcher org.freedesktop.DBus.Introspect
# If you get "No such object path" → kded6 ghost problem

# What's registered in the watcher?
gdbus call --session --dest org.kde.StatusNotifierWatcher \
  --object-path /StatusNotifierWatcher \
  --method org.freedesktop.DBus.Properties.Get \
  org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
```

### Permanent fix — waybar systemd service

The fix is a systemd user service that **kills kded6 before every waybar start**, including crash restarts:

**`~/.config/systemd/user/waybar.service`** (tracked in dotfiles under `systemd/`):
```ini
[Service]
ExecStartPre=-/usr/bin/pkill kded6
ExecStartPre=/bin/sleep 0.5
ExecStart=/usr/bin/waybar
ExecStartPost=/bin/bash -c '(/home/lukesh/.config/waybar/tray-restart.sh) &'
Restart=on-failure
RestartSec=2
```

Enable it:
```bash
systemctl --user enable --now waybar.service
```

Remove the `exec-once = waybar ...` line from `hyprland.conf` — replaced by:
```
exec-once = systemctl --user start waybar.service
```

### Auto-restart tray apps after waybar restarts

**`~/.config/waybar/tray-restart.sh`** (tracked in dotfiles):  
Waits 3 seconds for waybar to register the SNI watcher, then restarts Slack, Vesktop, and OpenVPN Connect if they were running. Runs as `ExecStartPost` in the waybar service.

- Slack/Vesktop: `pkill -x <name>` then relaunch
- OpenVPN Connect: runs as `electron37/electron` — use `pkill -f "openvpn-connect-linux"` (not `pkill -x openvpn-connect`)
- Fish alias: `vpn-restart` — manually restarts OpenVPN Connect if icon disappears

### If systray dies again

```bash
# Check if kded6 is the ghost
dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher \
  /StatusNotifierWatcher org.freedesktop.DBus.Introspect
# "No such object path" → yes, kded6 ghost

# Fix: restart the waybar service (kills kded6 + relaunches tray apps)
systemctl --user restart waybar.service
```

---

## Discord — Use Vesktop

The official Discord Linux client has a long-standing unfixed bug where the tray icon does not register on Wayland.

**Solution:** use Vesktop instead:
```bash
paru -S vesktop
```

Vesktop is an unofficial Discord client built on Vencord (optional mods). It has native Wayland support and correctly registers the SNI tray icon in waybar. Functionally identical to Discord.

Hyprland windowrule: floats on workspace 5, centered.

---

## Slack — Working Configuration

**`~/.local/share/applications/slack.desktop`:**
```ini
Exec=env XDG_CURRENT_DESKTOP=Unity /usr/bin/slack --disable-gpu-sandbox %U
```

- `XDG_CURRENT_DESKTOP=Unity` — triggers libappindicator SNI registration
- `--disable-gpu-sandbox` — required for GPU/sandbox compatibility
- **Do NOT add** `--ozone-platform=x11` or `ELECTRON_OZONE_PLATFORM_HINT=x11` — causes Slack to fail to start or open without a window on this setup

If Slack won't open after pkill, remove stale singleton locks:
```bash
rm -f ~/.config/Slack/Singleton*
```

Then relaunch from rofi (not terminal — terminal lacks the Hyprland env vars).

---

## hyprpolkitagent

Required for apps that use `pkexec` (e.g. OpenVPN Connect). Without it, elevated processes silently fail with exit code 127.

Binary path: `/usr/lib/hyprpolkitagent/hyprpolkitagent`  
Enabled via: `systemctl --user enable hyprpolkitagent`  
Autostart in hyprland.conf: `exec-once = /usr/lib/hyprpolkitagent/hyprpolkitagent`

---

## nm-applet — Ícone (?) no tray

O `network-manager-applet` não renderiza no Wayland/waybar e aparece como `(?)`. Não é necessário — setup usa ethernet estática e OpenVPN Connect tem tray próprio.

**Remover:**
```bash
paru -Rns network-manager-applet
pkill nm-applet  # matar instância atual sem reiniciar
```

O pacote vinha de `/etc/xdg/autostart/nm-applet.desktop` (global do sistema).

---

## fcitx5 — Clipboard popup conflitando com atalhos

O addon **Clipboard** do fcitx5 usa `Super+;` como trigger padrão, abrindo o histórico de Ctrl+C/V inesperadamente.

**Fix:** `fcitx5-configtool` → Addons → Clipboard → Trigger Key → Empty/None

---

## Summary

| App | Problem | Fix |
|-----|---------|-----|
| Discord | Native client never registers SNI on Wayland | Use Vesktop instead |
| Slack | Wrong flags cause no window / no tray | `XDG_CURRENT_DESKTOP=Unity --disable-gpu-sandbox` only |
| All icons missing | kded6 ghost-owns SNI watcher (name without object) | `waybar.service` kills kded6 before starting |
| Icons gone after waybar restart | Apps don't re-register SNI automatically | `tray-restart.sh` auto-restarts Slack, Vesktop, OpenVPN |
| OpenVPN Connect icon missing | Runs as electron37, not openvpn-connect | `vpn-restart` fish function or `systemctl --user restart waybar.service` |
| pkexec fails silently (exit 127) | hyprpolkitagent not running | `systemctl --user enable --now hyprpolkitagent` |
| Ícone (?) no tray | nm-applet não renderiza no Wayland | `paru -Rns network-manager-applet` |
| Popup abre com Super+; | fcitx5 Clipboard trigger key | fcitx5-configtool → Addons → Clipboard → Empty |
