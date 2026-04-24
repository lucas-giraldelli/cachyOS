# 2026-04-24 — Removed KDE Stack, Replaced Dolphin with Nemo

## What happened

The waybar systray was disappearing again despite the `waybar.service` fix from 2026-04-22. The `pkill kded6` in `ExecStartPre` only runs on waybar restart — but kded6 was coming back mid-session without waybar restarting, then waiting silently to steal the SNI watcher on the next crash.

## Root cause — Dolphin was waking kded6

Every time Dolphin opened (`Alt+E`), it triggered `kactivitymanagerd` and `kded6` via D-Bus activation. After the waybar service ran, kded6 was dead — but the first Dolphin open of the session resurrected it.

Confirmed via journal:
```
kactivitymanagerd[115247]: There are no outputs - creating placeholder screen
dolphin[119484]: There are no outputs - creating placeholder screen
kded6[117867]: There are no outputs - creating placeholder screen
```

## Fix — remove the entire KDE stack

Dolphin is a full KDE application. Installing it dragged in `plasma-workspace`, `plasma-integration`, and `xdg-desktop-portal-kde` as dependencies. None of these are needed on a Hyprland setup — `xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk` were already installed and doing the job.

Removed:
```bash
paru -Rns dolphin xdg-desktop-portal-kde plasma-workspace plasma-integration
```

`kded6` was removed as an orphan. Cleaned remaining orphans with `paru -Rns $(paru -Qdtq)`.

Blocked future reinstallation via `IgnorePkg` in `/etc/pacman.conf`:
```
IgnorePkg = lazydocker plasma-workspace plasma-integration xdg-desktop-portal-kde kded dolphin
```

Also documented in `CLAUDE.md` so AI agents don't suggest reinstalling them.

## Replaced Dolphin with Nemo

Thunar was tried first but lacked too many features (no drive sidebar, no volume management). Switched to **Nemo** (Cinnamon's file manager) — GTK3, no KDE dependencies, native drive listing, visually close to Dolphin.

```bash
paru -S nemo papirus-icon-theme
```

- `papirus-icon-theme` → folder icons, set as default icon theme via `gsettings`
- GTK theme (`Tokyonight-Dark`) inherited automatically from existing `~/.config/gtk-3.0/settings.ini`
- Hyprland windowrule updated: `match:class = nemo`, float, `1170x703`, centered
- `$fileManager = nemo` in `hyprland.conf`
- Rofi cache cleared so Nemo appears in launcher

## Drive bookmarks in Nemo

`/mnt/main` and `/mnt/secondary` are static fstab mounts (not udisks2-managed), so Nemo does not list them automatically. Added as GTK bookmarks in `~/.config/gtk-3.0/bookmarks`:

```
file:///home/lukesh/Downloads Downloads
file:///mnt/main Main
file:///mnt/secondary Secondary
```

These appear in Nemo's sidebar under Bookmarks.
