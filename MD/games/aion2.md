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
- If stutters remain: try `-dx11` after `%command%` (it fixed Smite 2; not every Unreal game ships
  DX11), and stop Docker, UFW and OpenRazer while playing, as for Smite 2.
