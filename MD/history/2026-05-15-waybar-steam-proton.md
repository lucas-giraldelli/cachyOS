# 2026-05-15 — Waybar cleanup, Proton CachyOS, Steam XWayland fix

## Waybar

- Removidos os módulos `cpu` e `custom/gpu` do grupo `perf` — ficou só `memory`
- Unificados `custom/date` e `clock` em um único módulo `clock`:
  - Formato: `󰅐  {:%a %d %b   %H:%M}`
  - On-click abre o popup do calendário (antes era separado)
  - Script Python `calendar.py` aposentado
- Popup do calendário reposicionado via windowrule do Hyprland: `move = 2235 1088`

## Proton / Steam

- Pesquisa sobre versões de Proton disponíveis:
  - **GE-Proton10-34** — já estava instalado (mais recente)
  - **proton-cachyos 11.0.20260429-1** — instalado via `paru -S proton-cachyos`
  - Recomendação: usar `proton-cachyos` como padrão no CachyOS, GE como fallback
- Launch options recomendadas para o Farever:
  ```
  PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 PROTON_VKD3D_HEAP=1 MANGOHUD=1 %command%
  ```
  - `PROTON_USE_NTSYNC=1` removido (proton-cachyos já ativa por padrão)
  - `PROTON_ENABLE_HDR=1` opcional (requer HDR ativo no Hyprland)

## Fix: Steam não abria ("Unable to open a connection to X")

**Causa:** Hyprland cria o socket do XWayland como `/tmp/.X11-unix/X1_` em vez de `X1`. O Steam procura por `X1` e falha com segfault.

**Fix temporário:** symlink manual — `ln -sf /tmp/.X11-unix/X1_ /tmp/.X11-unix/X1`

**Fix permanente** adicionado ao `hyprland.conf`:
```bash
exec-once = bash -c 'while [ ! -S /tmp/.X11-unix/X1_ ]; do sleep 0.5; done; ln -sf /tmp/.X11-unix/X1_ /tmp/.X11-unix/X1'
```
Loop aguarda o socket `X1_` existir antes de criar o symlink — robusto contra boot lento.

**Nota:** Se um update do Hyprland mudar o nome do socket, esse exec-once precisará ser revisado.
