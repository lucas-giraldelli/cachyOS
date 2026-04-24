#!/bin/bash
# Clears dirty bit on NTFS volumes before mounting.
# Needed because Hyprland crashes leave volumes dirty.

DEVICES=(
    /dev/sdb2  # /mnt/main
    /dev/sda1  # /mnt/secondary
)

for dev in "${DEVICES[@]}"; do
    if ! blkid "$dev" | grep -q ntfs; then
        continue
    fi
    ntfsfix -d "$dev"
done
