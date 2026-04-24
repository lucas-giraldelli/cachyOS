# 2026-04-23 — Hyprland DP-2 Crash + NTFS Dirty Volumes

## What happened

Hyprland crashed (SIGABRT) when the monitor's physical power button was used. After reboot, the NTFS drives at `/mnt/main` and `/mnt/secondary` refused to mount, leaving the system without access to both drives until manually fixed.

## Crash — root cause

`libhyprgraphics` was updated on the system (0.5.1) but the `hyprland` package was compiled against the old version (0.5.0). The mismatch causes `std::bad_any_cast` during `CWLSurfaceResource::commitState` on a DRM hotplug event.

**Trigger:** physical monitor power button → DP-2 sends a hotplug event → crash.

**Confirmed via crash report:**
```bash
cat ~/.cache/hyprland/hyprlandCrashReport*.txt | grep "Hyprgraphics"
# Hyprgraphics: built against 0.5.0, system has 0.5.1
```

## Crash mitigations

**1. Headless monitor fallback** — when DP-2 disconnects, Hyprland moves windows to a virtual monitor instead of crashing:
```ini
monitor=DP-2,2560x1440@360,0x0,1
monitor=,preferred,auto,1
```

**2. DPMS instead of physical button** — software DPMS does not generate a hotplug event:
```bash
hyprctl dispatch dpms toggle DP-2
```
Bound to `Super+F10`. Rule: do not use the physical power button while the hyprgraphics bug exists.

**Permanent fix:** waiting on CachyOS to rebuild `hyprland` against `hyprgraphics 0.5.1`. Monitor with `paru -Qu hyprland`.

## NTFS dirty volumes — root cause

After an unclean shutdown (crash), NTFS volumes are marked dirty. The `ntfs3` kernel driver refuses to mount dirty volumes without the `force` flag. Journal shows:
```
ntfs3(sdb2): volume is dirty and "force" flag is not set!
```

## NTFS fix

**Manual:**
```bash
sudo ntfsfix -d /dev/sdb2 && sudo ntfsfix -d /dev/sda1 && sudo mount -a
```

**Automatic:** `fix-ntfs.service` — systemd unit that runs `ntfsfix` on both volumes before the fstab mounts at boot. Transparent, no manual action needed after this was installed.

## Other fixes in this session

- Fully diagnosed kded6 ghost behavior (follow-up from 2026-04-22)
- Documented `sudo faillock` blocking sudo after repeated failed attempts (unrelated bug hit during debugging)
- Translated all MD docs to English, added language rule to CLAUDE.md
