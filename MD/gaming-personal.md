# Gaming on CachyOS — Personal Notes

Setup: AMD Ryzen 7 5800X3D · RTX 4080 16GB · 48GB RAM · CachyOS (Arch-based) · Hyprland/Wayland

---

## General Optimizations

### Launch Options Template

```
WINEESYNC=1 WINEFSYNC=1 DXVK_ASYNC=1 PROTON_NVIDIA_LIBS_NO_32BIT=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,no_display,frame_timing game-performance %command%
```

Append game-specific flags after `%command%` (e.g. `-dx11`).

> `MANGOHUD_CONFIG=position=top-right,no_display,frame_timing` — shows only the frametime graph. Frametime is more useful than FPS: a stable 60fps with spiking frametimes means stutters; frametime exposes that instantly.

| Variable | Why |
|----------|-----|
| `WINEESYNC=1 WINEFSYNC=1` | Faster kernel sync primitives, reduces CPU overhead |
| `DXVK_ASYNC=1` | Compile shaders in background — no frame freeze on first encounter |
| `PROTON_NVIDIA_LIBS_NO_32BIT=1` | RTX 4000+ specific: disables 32-bit Nvidia libs that cause perf issues |
| `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1` | Prevents Nvidia driver from evicting old shaders when cache fills |
| `game-performance` | CachyOS wrapper: switches power profile to performance for the game session, restores on exit |

### Don't combine `gamemoderun` with `ananicy-cpp`

`ananicy-cpp` runs as a system daemon and automatically manages process niceness for known apps. `gamemoderun` (Feral GameMode) also tries to set niceness on the game process — they conflict and can cause stutters.

**Solution**: use `game-performance` instead of `gamemoderun`. It doesn't touch niceness, so ananicy-cpp handles that without conflict.

### Shader Cache Size (Nvidia)

Default Nvidia shader cache limit is ~1GB. Large games exceed this and force recompilation every session.

Configured in `~/.config/environment.d/gaming.conf`:
```sh
__GL_SHADER_DISK_CACHE_SIZE=12000000000
```

Requires logout/login to apply.

### Steam Shader Pre-Caching

Disabled in `Steam → Settings → Downloads`:
- Allow background processing of Vulkan shaders → **off**
- Enable Shader Pre-Caching → **off**

**Why**: Steam's pre-cached shaders are compiled for Valve's Proton. They are not compatible with Proton-GE or proton-cachyos and don't get used anyway. DXVK builds its own cache on-the-fly via `DXVK_ASYNC=1`.

### DX12 Performance Drop on Nvidia (Linux)

Nvidia's Linux drivers do not implement GPU scheduling the same way as Windows. DX12 games via VKD3D-Proton show significant stutters and frame inconsistency — **this is a known Nvidia driver bug with no current workaround**.

> Reference: [Nvidia developer thread](https://forums.developer.nvidia.com/t/directx12-performance-is-terrible-on-linux/303207/488)

**Workaround**: use DX11 (`-dx11` launch flag) where the game supports it. DXVK (DX11 translation layer) is far more mature than VKD3D-Proton and produces stable frametimes on Nvidia.

### Proton Version Choice

- **Proton-GE**: good general choice, well-maintained, includes extra codecs and patches
- **proton-cachyos-slr**: recommended for games with EAC/BattlEye anti-cheat
- Avoid mixing `proton-cachyos` (non-SLR) with Steam Linux Runtime dependent games

---

## Hotkeys & Input Conflicts in Games

### `Ctrl+;` — Reserved by fcitx5

fcitx5 (input method framework) binds `Ctrl+;` globally as a clipboard popup shortcut. This intercepts the keybind inside games running under Proton/Wine.

**Root cause**: fcitx5 was installed as an input method for accented characters (pt-BR keyboard). It is not needed — Hyprland handles `us-intl` layout natively.

**Fix applied**: fcitx5 removed entirely. Keyboard configured directly in Hyprland:
```ini
# ~/.config/hypr/hyprland.conf
input {
    kb_layout = us
    kb_variant = intl
}
```

`Ctrl+;` is now free for use in games.

---

## Per-Game Notes

### Smite 2

**Proton version**: Proton-GE  
**API**: DX11 (`-dx11`)

**Launch options**:
```
WINEESYNC=1 WINEFSYNC=1 DXVK_ASYNC=1 PROTON_NVIDIA_LIBS_NO_32BIT=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,no_display,frame_timing game-performance %command% -dx11
```

**Why DX11**: Tested DX12 — severe micro-stutters throughout matches. Switching to DX11/DXVK resolved the frametime inconsistency almost entirely. This is the Nvidia/DX12 driver bug described above.

**Shader warmup**: first sessions in each new map area or with new ability effects will have brief single-frame hitches as DXVK compiles shaders. After first encounter they are cached permanently. Running a bot match before competitive play helps pre-warm common shaders.

**Other fixes applied**:
- Removed OpenRazer daemon (USB polling was generating interrupts during gameplay)
- Disabled UFW (firewall was blocking UDP game packets, generating kernel interrupts → stutters)
- Stopped TNS Docker stack during gaming (OpenSearch/Redis/MariaDB eating CPU/RAM)

---

### Slay the Spire 2

**Proton version**: Proton-GE  
**API**: Unity (OpenGL/Vulkan nativo — sem DXVK)

**Launch options**:
```
WINEESYNC=1 WINEFSYNC=1 PROTON_NVIDIA_LIBS_NO_32BIT=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,no_display,frame_timing game-performance %command%
```

> Sem `DXVK_ASYNC=1` — Unity não usa DX9/10/11, DXVK não se aplica.

## Troubleshooting Checklist

When a new game stutters:

1. Check DX version — try `-dx11` if DX12 is default (Nvidia/DX12 bug)
2. Check if `gamemoderun` is in launch options — replace with `game-performance`
3. Check running background services — `systemctl list-units --state=running` — stop heavy ones (Docker, etc.)
4. Check USB polling — if OpenRazer or similar HID daemons are running, stop them during gaming
5. Check UFW — if enabled, game UDP traffic may be getting blocked (`sudo ufw disable` to test)
6. Check if shader cache is warming up — first session per map/area is expected to have brief hitches
7. Check ProtonDB for game-specific flags and known issues
