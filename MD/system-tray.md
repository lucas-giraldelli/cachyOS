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

## kded6 Permanent Fix

kded6 steals the SNI watcher on session start. Block its `statusnotifierwatcher` module permanently:

```bash
# Disable the module
cat > ~/.config/kded6rc << 'EOF'
[Module-statusnotifierwatcher]
autoload=false
EOF

# Fix immediately (kill kded6 so waybar takes over)
pkill kded6
pkill waybar
waybar &
```

This survives reboots. kded6 will still start but won't load the SNI watcher module.

**After waybar restarts**, all tray apps (Slack, Vesktop, etc.) must be restarted — they won't re-register automatically.

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
| All icons missing | kded6 stole SNI watcher | `~/.config/kded6rc` disables module permanently |
| Icons gone after waybar restart | Apps don't re-register SNI automatically | Restart each tray app after waybar restarts |
| pkexec fails silently (exit 127) | hyprpolkitagent not running | `systemctl --user enable --now hyprpolkitagent` |
| Ícone (?) no tray | nm-applet não renderiza no Wayland | `paru -Rns network-manager-applet` |
| Popup abre com Super+; | fcitx5 Clipboard trigger key | fcitx5-configtool → Addons → Clipboard → Empty |
