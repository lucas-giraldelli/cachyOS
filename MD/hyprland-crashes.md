# Hyprland Crashes

## Crash: hyprgraphics library mismatch (v0.54.3)

**Sintoma:** Hyprland crasha com SIGABRT/SIGSEGV, geralmente ao desconectar monitor ou em eventos de hotplug.

**Causa:** `libhyprgraphics` foi atualizada no sistema (0.5.1) mas o pacote `hyprland` ainda foi compilado contra a versão antiga (0.5.0). O mismatch causa `std::bad_any_cast` no signal handler durante `CWLSurfaceResource::commitState`.

**Stack trace:**
```
CExtImageCopyCaptureFrameV1 → CWLSurfaceResource::commitState
→ CSurfaceStateQueue::tryProcess → signal emit → bad_any_cast → ABORT
```

**Crash report:** `~/.cache/hyprland/hyprlandCrashReport<PID>.txt`

**Fix:** Aguardar o CachyOS rebuildar o pacote `hyprland` contra as libs atuais:
```bash
paru -S hyprland
```

**Gatilho comum:** Desconectar o monitor DP-2 (hotplug event no DRM).

---

## Diagnóstico geral de crashes

```bash
# Ver crash reports
ls ~/.cache/hyprland/

# Ver coredumps recentes
coredumpctl list | tail -20

# Ver logs do boot anterior
journalctl -b -1 -p err --no-pager | head -50

# Histórico de reboots/crashes
last reboot | head -10
```
