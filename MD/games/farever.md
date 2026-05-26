# Farever

**Steam AppID**: 3672400  
**Proton**: proton-cachyos  
**API**: DX12 (VKD3D) — não suporta `-dx11`  
**Engine**: Unreal Engine  
**Status**: Early Access (v0.1.3.25689)

## Launch Options (atual)

```
PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 PROTON_VKD3D_HEAP=1 MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,fps=0,cpu_stats=0,gpu_stats=0,height=25,font_size=14 LD_PRELOAD="" game-performance %command%
```

> MangoHud config: frametime monitor minimal — ver [index.md](index.md#mangohud--frametime-monitor-minimal).

> `LD_PRELOAD=""` desativa o Steam Overlay e elimina stutters do Steam Game Recorder. **Deve vir antes do `%command%`** — depois vira argumento do executável e não tem efeito.

## Benchmarks (MangoHud)

| Sessão | Config | Avg FPS | 1% Low | 0.1% Low | GPU% |
|--------|--------|---------|--------|----------|------|
| #1 | powersave + Wayland | 83.6 | 46.6 | 11.0 | 56.9 |
| #2 | game-perf quebrado + Wayland | 65.5 | 33.9 | 8.5 | 52.4 |
| #3 | sem Wayland, sem game-perf | 80.5 | 44.7 | 15.6 | 57.5 |
| **#4** | **game-perf ✅ sem Wayland** | **85.9** | **61.5** | **47.5** | **61.4** |

## Notes

- **PROTON_ENABLE_WAYLAND=1**: causa crash "Program timeout (infinite loop?)" ao trocar de workspace no Hyprland. Removido — jogo deve rodar via XWayland.
- **XWayland socket**: o symlink `/tmp/.X11-unix/X1` pode sumir após reiniciar a Steam sem reiniciar o Hyprland. Quando isso ocorre, Wine não acha o XWayland e cai para Wayland nativo (`xwayland: false` no `hyprctl clients`) — causando o crash de workspace switching. Fix: `ln -sf /tmp/.X11-unix/X1_ /tmp/.X11-unix/X1`. O exec-once no hyprland.conf cria isso no boot mas não quando a Steam reinicia.
- **Verificar se está em XWayland**: `hyprctl -j clients | jq '.[] | select(.class == "steam_app_3672400") | {xwayland}'` — deve ser `true`. Se `false`, recriar o symlink.
- **render_unfocused no Hyprland 0.55**: a rule `render_unfocused` do windowrule block format não está sendo aplicada em 0.55.0 (bug conhecido). O `misc:render_unfocused_fps` foi ajustado para 120 (padrão era 15 — causava stall do VKD3D).
- **proton-cachyos 11 + Wayland nativo**: a versão 11 importou o `winewayland.drv` do Proton-EM, fazendo o Wine preferir Wayland nativo quando disponível. Versão 20260519 corrige o bug de "winewayland event dispatcher thread getting suspended" que causava o crash.
- **DX12 confirmado**: MangoHud mostra VKD3D. Tentativa de `-dx11` não teve efeito.
- **DLSS**: não encontrado nos menus do jogo. Jogo não suporta DLSS.
- **PROTON_NVIDIA_LIBS_NO_32BIT=1**: quebra o jogo — Farever depende de libs 32-bit da Nvidia.
- **Shader warmup**: primeira sessão tem 0.1% low severo (~11 FPS). A partir da segunda sessão o cache está quente e os spikes somem.
- **game-performance**: deve vir como wrapper antes do `%command%`. `MANGOHUD=1` deve ser variável de ambiente antes do wrapper — se vier depois, `powerprofilesctl` tenta executar `MANGOHUD=1` como programa e crasha.

## Logs

| Log | Caminho |
|-----|---------|
| Steam (crashes, launch) | `~/.steam/steam/logs/console-linux.txt` |
| Proton (ativar com `PROTON_LOG=1`) | `~/steam-3672400.log` |
| Jogo (Unreal Saved/Logs) | `~/.local/share/Steam/steamapps/compatdata/3672400/pfx/drive_c/users/steamuser/AppData/Local/Farever/Saved/Logs/` *(criado após primeiro launch bem-sucedido)* |
| MangoHud benchmarks | `~/benchmarks/` |

## Hyprland windowrule

```
windowrule {
    name = farever
    match:class = steam_app_3672400
    immediate = true
    render_unfocused = on
}

# render_unfocused inline (block format não aplica em 0.55.0)
windowrule = render_unfocused on, match:class steam_app_3672400
```

> `render_unfocused` mantém o jogo renderizando ao trocar de workspace. Em Hyprland 0.55.0, o block format não aplica o efeito — mantida a versão inline como fallback. `misc:render_unfocused_fps = 120` no hyprland.conf (padrão 15 causava stall do VKD3D/DX12).
