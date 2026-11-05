# 2026-11-05 - Hyprland Config Migrated to Lua

Hyprland 0.57 removed `.conf` support (hyprwm/Hyprland#15539), and a system update would
have moved this machine from `0.56.2` to `0.57.1`. `hyprland` is not in `IgnorePkg`, so the
config was migrated first, while `0.56.2` could still fall back to the old file.

## What changed

- `hypr/.config/hypr/hyprland.lua` replaces `hyprland.conf`. Hyprland prefers the Lua file at
  startup when both exist.
- `hyprctl` callers were converted, because a Lua config changes what they accept:
  - `hyprctl dispatch` is now a shorthand for `hl.dispatch(...)` and takes Lua.
  - `hyprctl keyword` refuses to run. Use `hyprctl eval`.
- Converted callers: `game-submap.sh`, `weather-popup.sh`, `calendar-popup.sh`, and in the
  smart-shell repo `Notifications.qml`, `Media.qml` and `SystemPane.qml`.

## Verification

`Hyprland --verify-config --config <file>` reports unknown fields and bad keys. The file
passed on `0.56.2` and on `0.57.1`, the latter run from the extracted packages with
`LD_LIBRARY_PATH`, without installing them. The session was then tested by hand on `0.56.2`.

## Notes

- Named window rules are evaluated before anonymous ones. The inline `windowrule =` lines
  became anonymous `hl.window_rule` calls to keep that order.
- `/usr/share/hypr/stubs/hl.meta.lua` is the API reference for the installed version. The
  wiki defaults to latest git.
- Logging out kills the compositor under Electron apps. Claude Desktop reacted to that on
  this logout by disabling its own hardware acceleration (`GPU process gone`,
  `launch-failed`). Re-enable it from the Help menu. It is not a driver fault.

## NVIDIA status on this date

The DPMS wake deadlock is still open (NVIDIA/open-gpu-kernel-modules#1371, internal bug
7029722). `615.78.08` looks better on the DPMS path but still hangs on S3 resume for some
users, so the driver and kernel stay pinned. See
`2026-10-10-nvidia-615-dpms-wake-deadlock.md`.
