# AION 2

**Steam AppID**: 3393110  
**Proton**: proton-cachyos-native  
**API**: DX12 (VKD3D)  
**Engine**: Unreal Engine

## Launch Options

```
PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 VKD3D_CONFIG=descriptor_heap PROTON_DLSS_UPGRADE=1 PROTON_USE_WAYLAND=0 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,fps=0,cpu_stats=0,gpu_stats=0,height=25,font_size=14 LD_PRELOAD="" game-performance %command%
```

Was `VKD3D_CONFIG=descriptor_heap PROTON_DLSS_UPGRADE=1 PROTON_USE_WAYLAND=0 game-performance %command%`;
the additions follow what fixed [Farever](farever.md), the other DX12 Unreal game:

- `LD_PRELOAD=""` turns the Steam overlay and its Game Recorder off. On Farever it took the
  0.1% low from 11 to 47.5 fps - the micro-stutters. It must come before `%command%`.
- `PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1`: NVAPI for DLSS and Reflex.
- `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1`: keeps the driver's shader cache, so compiled shaders
  survive between sessions (fewer hitches on new areas).
- MangoHud's minimal frametime graph, to see the stutters ([index.md](index.md#mangohud--frametime-monitor-minimal)).

## Notes

- Paste the launch options in Steam (Properties > General); Steam rewrites its config file while running.
- `immediate = true` (the Smite 2 windowrule) does nothing here: `allow_tearing` is off in
  `hyprland.conf`, and tearing isn't a stutter fix. VRR is on.
- Game mode (`scripts/game-submap.sh`) applies: ALT+number switches workspace, ALT+SHIFT+number
  moves the game, Print / ALT+Print screenshot and record, every other ALT goes to the game.
- Audio crackled with a Bluetooth headset (PipeWire xruns at a 256-sample quantum); fixed by the
  larger minimum buffers in the `pipewire` and `wireplumber` packages.
- No DX11: the game requires DX12 and ignores `-dx11`.

## Crowded areas (CPU-bound)

In towns and mass fights the GPU sits at ~40% and the frame rate follows the CPU's main thread.
Two things helped, measured with MangoHud logs (`output_folder`, `autostart_log=1`):

1. **Free the CPU.** The 5800X3D ran at its 90 °C cap (Tctl) all session, at ~4.1 GHz, while
   background work took about four cores: the live wallpaper (`mpvpaper`, now paused by
   `scripts/game-submap.sh` while a game has focus), headless browsers left running, the dock,
   Docker.
2. **In-game crowd settings**: Mass Combat Quality Very Low, Identical Player Appearance On,
   Player Particle Effect Display Self and Party, other players' pets Off, shadows and effects
   Low or Normal. Don't drop View Distance to the minimum, it gains little.

| | Before | After |
|---|---|---|
| Average | 81 fps | 105 fps |
| 1% low | 28 fps | 52 fps |
| Hitches over 50 ms | 20/min | 9/min |
| Time CPU-bound (GPU < 55%) | 65% | 25% |
| Frame rate while CPU-bound | 57 fps | 109 fps |

Hitches of 0.2-1 s remain, at about 5/min, when VRAM climbs: the game streaming in new
characters and assets. That is the game's own and not tunable from here.
