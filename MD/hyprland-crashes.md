# Hyprland Crashes

## Crash: hyprgraphics library mismatch (v0.54.3)

**Symptom:** Hyprland crashes with SIGABRT/SIGSEGV when turning off or disconnecting monitor DP-2.

**Cause:** `libhyprgraphics` was updated on the system (0.5.1) but the `hyprland` package was compiled against the old version (0.5.0). The mismatch causes `std::bad_any_cast` during `CWLSurfaceResource::commitState` on a DRM hotplug event.

**Confirm in crash report:**
```bash
cat ~/.cache/hyprland/hyprlandCrashReport*.txt | grep "Hyprgraphics"
# Hyprgraphics: built against 0.5.0, system has 0.5.1  ← problem
```

**Stack trace:**
```
CExtImageCopyCaptureFrameV1 → CWLSurfaceResource::commitState
→ CSurfaceStateQueue::tryProcess → signal emit → bad_any_cast → ABORT
```

**Trigger:** turning off the monitor with the physical button → DP-2 sends a hotplug event → crash.

**Side effect:** NTFS volumes in `/mnt` are left dirty and won't mount on the next boot (see `ntfs-mounts.md`).

---

## Mitigations in place

### 1. Headless monitor fallback (`hyprland.conf`)

When DP-2 disconnects, Hyprland survives by moving windows to a virtual monitor instead of crashing:

```ini
monitor=DP-2,2560x1440@360,0x0,1
monitor=,preferred,auto,1  # headless fallback — keeps Hyprland alive if DP-2 glitches/disconnects
```

### 2. DPMS instead of the physical button

Turning off the monitor via software does not generate a hotplug event — avoids the crash:

```bash
hyprctl dispatch dpms toggle DP-2
```

**Keybind:** `Super+F10` — toggles DPMS on DP-2.

**Rule:** while the hyprgraphics bug exists, **do not use the monitor's physical power button**. Use Super+F10 instead.

### 3. Automatic NTFS fix on boot

`fix-ntfs.service` runs `ntfsfix` before mounting `/mnt/main` and `/mnt/secondary`. Transparent — no manual action needed.

---

## Permanent fix (waiting on CachyOS)

CachyOS needs to rebuild the `hyprland` package against `hyprgraphics 0.5.1`. Check for the update:

```bash
paru -Qu hyprland
```

When a new version appears (e.g. `0.54.3-3.1` or `0.55`), run:

```bash
paru -Syu
```

---

## General crash diagnosis

```bash
# Check crash report for library mismatch
cat ~/.cache/hyprland/hyprlandCrashReport*.txt | grep -E "Hyprgraphics|signal|built against"

# Check previous boot errors
journalctl -b -1 -p err --no-pager | grep -E "Hyprland|hyprgraphics|SIGSEGV|ABORT"

# List recent coredumps
coredumpctl list | tail -5

# Crash/reboot history
last reboot | head -10
```
