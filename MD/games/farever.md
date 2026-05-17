# Farever

**Steam AppID**: 3672400  
**Proton**: proton-cachyos  
**API**: DX12 (VKD3D) — não suporta `-dx11`  
**Engine**: Unreal Engine  
**Status**: Early Access (v0.1.3.25689)

## Launch Options (atual)

```
PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 PROTON_VKD3D_HEAP=1 MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,fps=0,cpu_stats=0,gpu_stats=0,height=25,font_size=14 game-performance %command% LD_PRELOAD=""
```

> MangoHud config: frametime monitor minimal — ver [index.md](index.md#mangohud--frametime-monitor-minimal).

> `LD_PRELOAD=""` desativa o Steam Overlay mas elimina stutters do Steam Game Recorder.

## Benchmarks (MangoHud)

| Sessão | Config | Avg FPS | 1% Low | 0.1% Low | GPU% |
|--------|--------|---------|--------|----------|------|
| #1 | powersave + Wayland | 83.6 | 46.6 | 11.0 | 56.9 |
| #2 | game-perf quebrado + Wayland | 65.5 | 33.9 | 8.5 | 52.4 |
| #3 | sem Wayland, sem game-perf | 80.5 | 44.7 | 15.6 | 57.5 |
| **#4** | **game-perf ✅ sem Wayland** | **85.9** | **61.5** | **47.5** | **61.4** |

## Notes

- **PROTON_ENABLE_WAYLAND=1**: causa crash "Program timeout (infinite loop?)" ao trocar de workspace no Hyprland. Removido — jogo roda via XWayland estável.
- **DX12 confirmado**: MangoHud mostra VKD3D. Tentativa de `-dx11` não teve efeito.
- **DLSS**: não encontrado nos menus do jogo. Jogo não suporta DLSS.
- **PROTON_NVIDIA_LIBS_NO_32BIT=1**: quebra o jogo — Farever depende de libs 32-bit da Nvidia.
- **Shader warmup**: primeira sessão tem 0.1% low severo (~11 FPS). A partir da segunda sessão o cache está quente e os spikes somem.
- **game-performance**: deve vir como wrapper antes do `%command%`. `MANGOHUD=1` deve ser variável de ambiente antes do wrapper — se vier depois, `powerprofilesctl` tenta executar `MANGOHUD=1` como programa e crasha.

## Hyprland windowrule

```
windowrule {
    name = farever
    match:class = steam_app_3672400
    immediate = true
    render_unfocused = true
}
```

> `render_unfocused = true` mantém o jogo renderizando ao trocar de workspace, reduzindo crashes por timeout.
