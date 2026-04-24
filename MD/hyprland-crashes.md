# Hyprland Crashes

## Crash: hyprgraphics library mismatch (v0.54.3)

**Sintoma:** Hyprland crasha com SIGABRT/SIGSEGV ao desligar/desconectar o monitor DP-2.

**Causa:** `libhyprgraphics` foi atualizada no sistema (0.5.1) mas o pacote `hyprland` foi compilado contra a versão antiga (0.5.0). O mismatch causa `std::bad_any_cast` durante `CWLSurfaceResource::commitState` no hotplug event do DRM.

**Confirmar no crash report:**
```bash
cat ~/.cache/hyprland/hyprlandCrashReport*.txt | grep "Hyprgraphics"
# Hyprgraphics: built against 0.5.0, system has 0.5.1  ← problema
```

**Stack trace:**
```
CExtImageCopyCaptureFrameV1 → CWLSurfaceResource::commitState
→ CSurfaceStateQueue::tryProcess → signal emit → bad_any_cast → ABORT
```

**Gatilho:** desligar o monitor pelo botão físico → DP-2 manda hotplug event → crash.

**Efeitos colaterais:** NTFS volumes em `/mnt` ficam dirty e não montam no próximo boot (ver `ntfs-mounts.md`).

---

## Mitigações implementadas

### 1. Monitor headless fallback (`hyprland.conf`)

Quando DP-2 desconecta, o Hyprland sobrevive movendo janelas para o monitor virtual em vez de crashar:

```ini
monitor=DP-2,2560x1440@360,0x0,1
monitor=,preferred,auto,1  # headless fallback
```

### 2. DPMS em vez de botão físico

Desligar o monitor via software não gera hotplug event — evita o crash:

```bash
hyprctl dispatch dpms toggle DP-2
```

**Keybind:** `Super+F10` — toggle DPMS do DP-2.

**Regra:** enquanto o bug do hyprgraphics existir, **não usar o botão físico do monitor** para desligar. Usar Super+F10.

### 3. Fix automático dos NTFS no boot

`fix-ntfs.service` roda `ntfsfix` antes de montar `/mnt/main` e `/mnt/secondary`. Transparente — não requer ação manual.

---

## Fix definitivo (aguardando CachyOS)

O CachyOS precisa rebuildar o pacote `hyprland` contra `hyprgraphics 0.5.1`. Verificar se saiu update:

```bash
paru -Qu hyprland
```

Quando aparecer versão nova (ex: `0.54.3-3.1` ou `0.55`), fazer:

```bash
paru -Syu
```

---

## Diagnóstico geral de crashes

```bash
# Ver crash reports e causa
cat ~/.cache/hyprland/hyprlandCrashReport*.txt | grep -E "Hyprgraphics|signal|built against"

# Ver log do boot anterior
journalctl -b -1 -p err --no-pager | grep -E "Hyprland|hyprgraphics|SIGSEGV|ABORT"

# Ver coredumps recentes
coredumpctl list | tail -5

# Histórico de crashes
last reboot | head -10
```
