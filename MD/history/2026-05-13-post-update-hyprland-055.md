# 2026-05-13 — Post-update fixes (paru -Syu → Hyprland 0.55.0)

## Symptoms

- Waybar crashando com `custom/gpu: Error parsing JSON`
- Hyprland error: `config option <dwindle:pseudotile> does not exist`
- Todas as janelas flutuantes abrindo em tiling

## Root causes & fixes

### 1. NVIDIA driver/library mismatch
`nvidia-smi` falhava com `Failed to initialize NVML: Driver/library version mismatch (NVML 595.71)`.
O update atualizou o driver mas o módulo antigo ainda estava carregado.
**Fix:** reboot.

### 2. `dwindle:pseudotile` removido no Hyprland 0.55.0
A opção foi removida do bloco `dwindle {}`.
**Fix:** remover a linha do config.

### 3. `move = center` quebra a regra inteira no Hyprland 0.55.0
Qualquer `windowrule {}` com `move = center` era silenciosamente ignorada por completo — nem o `float = yes` era aplicado. Nenhum erro aparecia em `hyprctl configerrors`.
Afetava: btop-float, vesktop-float, openvpn-float, nemo-float, lazydocker-float, steam-friends/settings/dialogs, qbittorrent-float.
**Fix:** substituir todos os `move = center` por `center = 1` (9 ocorrências).

## Pendente

- `waybar-calendar.service` usa gcalcli (OAuth expirado). Usuário migrou pro Thunderbird — `custom/date` já lê do SQLite do Thunderbird. Timer precisa ser desativado.
