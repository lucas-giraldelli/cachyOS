# 2026-10-10 - NVIDIA 615.71.09 Deadlocks on DPMS Wake (DisplayPort)

After the 2026-10-09 system update (kernel `7.2.2` -> `7.2.9`, driver `610.57.04` ->
`615.71.09`), turning the monitor back on after a `dpms off` hung the display three
times in two days. Each time needed a hard reboot.

## Symptoms

- The monitor wakes up, shows "DisplayPort", then "No Signal".
- The machine is still reachable (SSH, remote sessions), but `hyprctl` returns nothing.
- `nvidia-modeset/kthread_q` is stuck in `D` state:

```
$ ps -eo stat,cmd | awk '$1~/D/'
D    [nvidia-modeset/kthread_q]
```

- The Hyprland log shows the modeset back to 2560x1440@360 Hz followed right away by a
  hotplug that drops the connector, and Hyprland falls back to its `FALLBACK` output:

```
drm: Modesetting DP-2 with 2560x1440@360.00Hz
drm: Connector DP-2 enabledState changed false -> true
drm: Got a hotplug event for /dev/dri/card1
drm: Connector DP-2 disconnected
ERR from aquamarine ]: drm: Cannot commit a disconnected output
```

## Root cause

A known regression in `615.71.09` (open kernel modules): waking a DisplayPort monitor
from DPMS deadlocks `nvidia-modeset` during link training. It is reported on KWin,
GNOME and Hyprland, on RTX 30, 40 and 50 cards, and mostly at high refresh rates.

- https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1371
- https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1392
- https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1416

The first two hangs were initially blamed on a screen capture taken while the monitor
was off. The capture rule still stands, but the driver was the trigger. Power cycling
the monitor with its physical button goes through the same code path.

## Fix

Roll back to the last working set from the pacman cache, and pin it:

```bash
cd /var/cache/pacman/pkg && sudo pacman -U \
  linux-cachyos-7.2.2-1-x86_64_v3.pkg.tar.zst \
  linux-cachyos-headers-7.2.2-1-x86_64_v3.pkg.tar.zst \
  linux-cachyos-nvidia-open-7.2.2-1-x86_64_v3.pkg.tar.zst \
  linux-cachyos-lts-6.18.42-1-x86_64_v3.pkg.tar.zst \
  linux-cachyos-lts-headers-6.18.42-1-x86_64_v3.pkg.tar.zst \
  linux-cachyos-lts-nvidia-open-6.18.42-1-x86_64_v3.pkg.tar.zst \
  nvidia-utils-610.57.04-1-x86_64_v3.pkg.tar.zst \
  lib32-nvidia-utils-610.57.04-1-x86_64_v3.pkg.tar.zst \
  opencl-nvidia-610.57.04-1-x86_64_v3.pkg.tar.zst \
  lib32-opencl-nvidia-610.57.04-1-x86_64_v3.pkg.tar.zst
```

The LTS kernel has to go back too, because its NVIDIA module depends on an exact
`nvidia-utils` version. All ten packages were appended to `IgnorePkg` in
`/etc/pacman.conf`.

## Undo

When a driver release is confirmed to fix the DPMS wake (`615.78.08` was reported as
only a partial fix), remove those ten names from `IgnorePkg` and update.
