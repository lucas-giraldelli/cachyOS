# NTFS Mounts — HDs externos

## Configuração atual (fstab)

| Dispositivo | Ponto de montagem | Label |
|-------------|-------------------|-------|
| `/dev/sdb2` | `/mnt/main` | Main HDD (1.8TB) |
| `/dev/sda1` | `/mnt/secondary` | Secondary SSD (480GB) |

`/etc/fstab` usa `ntfs3` (driver do kernel) com `nofail` — falhas silenciosas na inicialização.

---

## Problema: HDs não montam após crash

Após shutdown/crash não-limpo (ex: Hyprland SIGABRT), o NTFS fica marcado como "dirty". O driver `ntfs3` recusa montar volumes sujos sem a flag `force`.

**Sintoma no journal:**
```
ntfs3(sdb2): volume is dirty and "force" flag is not set!
Failed to mount /mnt/main
```

**Fix manual (one-liner):**
```bash
sudo ntfsfix /dev/sdb2 && sudo ntfsfix /dev/sda1 && sudo mount -a
```

> `ntfsfix` não formata — apenas limpa a flag dirty e ressincroniza o MFT mirror.

---

## Fix automático — systemd service

Serviço `fix-ntfs.service` que roda `ntfsfix` em ambos os volumes **antes** de montá-los no boot. Arquivos no dotfiles em `system/`.

**Instalar (one-liner):**
```bash
sudo cp ~/projects/cachyOS/system/usr/local/bin/fix-ntfs.sh /usr/local/bin/fix-ntfs.sh && sudo chmod +x /usr/local/bin/fix-ntfs.sh && sudo cp ~/projects/cachyOS/system/etc/systemd/system/fix-ntfs.service /etc/systemd/system/fix-ntfs.service && sudo systemctl daemon-reload && sudo systemctl enable fix-ntfs.service
```

**Verificar status:**
```bash
systemctl status fix-ntfs.service
```

---

## Nota sobre ntfs3 vs ntfs-3g

O `ntfs3` (kernel) é mais restrito com volumes dirty que o `ntfs-3g` (userspace). O serviço `fix-ntfs` contorna isso automaticamente — não é necessário trocar o driver.
