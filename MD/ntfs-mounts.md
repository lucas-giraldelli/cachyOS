# NTFS Mounts — HDs externos

## Configuração atual (fstab)

| Dispositivo | Ponto de montagem | Label |
|-------------|-------------------|-------|
| `/dev/sdb2` | `/mnt/main` | Main HDD (1.8TB) |
| `/dev/sda1` | `/mnt/secondary` | Secondary SSD (480GB) |

`/etc/fstab` usa `ntfs3` (driver do kernel) com `nofail` — falhas silenciosas na inicialização.

---

## Problema: HDs não montam após crash

Após shutdown/crash não-limpo, o NTFS fica marcado como "dirty" (MFT corrompido). O driver `ntfs3` recusa montar volumes sujos.

**Sintoma:**
```
$MFTMirr does not match $MFT (record 3).
Failed to mount '/dev/sdbX': Input/output error
```

**Fix:**
```bash
sudo ntfsfix /dev/sdb2
sudo ntfsfix /dev/sda1
sudo mount -t ntfs-3g /dev/sdb2 /mnt/main
sudo mount -t ntfs-3g /dev/sda1 /mnt/secondary
```

> `ntfsfix` não formata — apenas limpa a flag dirty e ressincroniza o MFT mirror.

---

## Nota sobre ntfs3 vs ntfs-3g

O kernel 7.0 usa `ntfs3` por padrão no fstab, mas ele é mais restrito com volumes dirty. Se os HDs continuarem falhando na inicialização após crashes, considerar trocar no fstab para `ntfs-3g`.
