# NTFS Mounts — External Drives

## Current setup (fstab)

| Device | Mount point | Label |
|--------|-------------|-------|
| `/dev/sdb2` | `/mnt/main` | Main HDD (1.8TB) |
| `/dev/sda1` | `/mnt/secondary` | Secondary SSD (480GB) |

`/etc/fstab` uses `ntfs3` (kernel driver) with `nofail` — silent failures on boot.

---

## Problem: drives don't mount after a crash

After an unclean shutdown or crash (e.g. Hyprland SIGABRT), NTFS volumes are marked as dirty. The `ntfs3` driver refuses to mount dirty volumes without the `force` flag.

**Journal symptom:**
```
ntfs3(sdb2): volume is dirty and "force" flag is not set!
Failed to mount /mnt/main
```

**Manual fix (one-liner):**
```bash
sudo ntfsfix /dev/sdb2 && sudo ntfsfix /dev/sda1 && sudo mount -a
```

> `ntfsfix` does not format — it only clears the dirty flag and resyncs the MFT mirror.

---

## Automatic fix — systemd service

`fix-ntfs.service` runs `ntfsfix` on both volumes **before** mounting them at boot. Files tracked in dotfiles under `system/`.

**Install (one-liner):**
```bash
sudo cp ~/projects/cachyOS/system/usr/local/bin/fix-ntfs.sh /usr/local/bin/fix-ntfs.sh && sudo chmod +x /usr/local/bin/fix-ntfs.sh && sudo cp ~/projects/cachyOS/system/etc/systemd/system/fix-ntfs.service /etc/systemd/system/fix-ntfs.service && sudo systemctl daemon-reload && sudo systemctl enable fix-ntfs.service
```

**Check status:**
```bash
systemctl status fix-ntfs.service
```

---

## Note on ntfs3 vs ntfs-3g

`ntfs3` (kernel) is stricter about dirty volumes than `ntfs-3g` (userspace). The `fix-ntfs` service works around this automatically — no need to switch drivers.
