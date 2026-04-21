# MangoHud — Personal Reference

## Current Config (launch options template)

```
MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,fps=0,cpu_stats=0,gpu_stats=0
```

Shows only the **frame_timing graph** (frametime over time). Frametime is more useful than FPS — a locked 60fps with spiking frametimes means stutters; the graph exposes that instantly.

To reduce the graph height:
```
MANGOHUD_CONFIG=position=top-right,fps=0,cpu_stats=0,gpu_stats=0,height=50
```

Default height is auto-calculated from `font_size` (default 24). Tweak `height=` until it fits.

---

## Key Options

| Variable | Description |
|----------|-------------|
| `fps=0` | Disable FPS counter (on by default) |
| `cpu_stats=0` | Disable CPU load (on by default) |
| `gpu_stats=0` | Disable GPU load (on by default) |
| `frame_timing=0` | Disable frametime graph (on by default) |
| `no_display` | Hide HUD by default — toggle with keybind |
| `position=` | `top-left`, `top-right`, `bottom-left`, `bottom-right` |
| `height=` | Override HUD height in pixels |
| `width=` | Override HUD width in pixels |
| `font_size=` | Font size, default `24` |
| `font_scale=` | Global font scale multiplier, default `1.0` |
| `frametime` | Show frametime value next to FPS text |
| `dynamic_frame_timing` | Y-axis adapts to current min/max frametime instead of static 0-50ms |
| `frame_timing_detailed` | More detailed frametime chart |
| `gpu_temp` | GPU temperature |
| `cpu_temp` | CPU temperature |
| `vram` | VRAM usage |
| `ram` | RAM usage |
| `full` | Enable most toggleable parameters |

## Default-On Parameters

These are enabled by default and must be explicitly disabled with `=0`:
- `fps`
- `frame_timing`
- `cpu_stats`
- `gpu_stats`

## Example: Minimal frametime only, compact

```
MANGOHUD_CONFIG=position=top-right,fps=0,cpu_stats=0,gpu_stats=0,height=40,font_size=16
```

## Config File

Persistent config lives at `~/.config/MangoHud/MangoHud.conf` — same keys, one per line without commas.

## Toggle HUD keybind

Default toggle: `Right Shift + F12`
