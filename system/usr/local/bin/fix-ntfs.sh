#!/bin/bash
# Clears dirty bit on NTFS volumes before mounting.
# Needed because Hyprland crashes / unclean shutdowns leave volumes dirty,
# which makes the kernel ntfs3 driver refuse to mount them.
#
# Requires `ntfsfix`, provided by the `ntfsprogs` package. This used to ship
# inside `ntfs-3g` but was split out; if ntfsprogs is missing the volumes will
# silently fail to mount, so we fail loudly instead.

if ! command -v ntfsfix >/dev/null 2>&1; then
    echo "fix-ntfs: ntfsfix not found — install the 'ntfsprogs' package" >&2
    exit 1
fi

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
