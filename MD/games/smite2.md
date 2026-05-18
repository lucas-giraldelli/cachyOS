# Smite 2

**Steam AppID**: 2437170  
**Proton**: Proton-GE  
**API**: DX11 (`-dx11`)

## Launch Options

```
WINEESYNC=1 WINEFSYNC=1 DXVK_ASYNC=1 PROTON_NVIDIA_LIBS_NO_32BIT=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 MANGOHUD=1 MANGOHUD_CONFIG=position=top-right,fps=0,cpu_stats=0,gpu_stats=0,height=25,font_size=14 game-performance %command% -dx11
```

> MangoHud config: frametime monitor minimal — ver [index.md](index.md#mangohud--frametime-monitor-minimal).

## Notes

- **DX11 obrigatório**: DX12 causava micro-stutters severos durante as partidas. DXVK (DX11) resolveu os frametimes quase completamente — bug conhecido do driver Nvidia no Linux com DX12.
- **Shader warmup**: primeiras sessões em mapas/áreas novas têm hitches pontuais enquanto o DXVK compila shaders. Rodar uma partida de bot antes do competitivo ajuda a pre-aquecer.
- **Hyprland windowrule**: `immediate = true` aplicado — reduz latência de frame.

## Logs

| Log | Caminho |
|-----|---------|
| Steam (crashes, launch) | `~/.steam/steam/logs/console-linux.txt` |
| Proton (ativar com `PROTON_LOG=1`) | `~/steam-2437170.log` |
| Jogo (Unreal Saved/Logs) | `~/.local/share/Steam/steamapps/compatdata/2437170/pfx/drive_c/users/steamuser/AppData/Local/SMITE2Alpha/Saved/Logs/Hemingway.log` |

## Hyprland windowrule

```
windowrule {
    name = smite2
    match:class = steam_app_2437170
    immediate = true
}
```

## Fixes Aplicados

- Removido OpenRazer daemon durante gameplay (polling USB gerava interrupções)
- Desabilitado UFW durante gameplay (bloqueava pacotes UDP do jogo → stutters)
- Parado Docker stack durante gaming (OpenSearch/Redis/MariaDB consumindo CPU/RAM)
