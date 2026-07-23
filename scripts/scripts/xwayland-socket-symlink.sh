#!/bin/bash
# Keep the plain XWayland socket (/tmp/.X11-unix/X<N>) pointing at the socket
# Hyprland actually binds (/tmp/.X11-unix/X<N>_).
#
# Steam and other X clients connect to the plain name. Hyprland sometimes binds
# only the trailing-underscore variant, and the symlink also disappears when
# Steam restarts XWayland without restarting Hyprland.
#
# The display number is discovered at runtime: it depends on what is already
# taken when the session starts (:1 on one login, :0 on the next), so it must
# not be hardcoded.

set -u

XDIR=/tmp/.X11-unix

while :; do
    for sock in "$XDIR"/X*_; do
        [ -S "$sock" ] || continue
        plain="${sock%_}"

        # XWayland bound the plain name directly — nothing to do.
        if [ -S "$plain" ] && [ ! -L "$plain" ]; then
            continue
        fi

        # Link already correct.
        if [ "$(readlink "$plain" 2>/dev/null)" = "$sock" ]; then
            continue
        fi

        # A leftover owned by another user: /tmp's sticky bit makes it
        # unremovable from here. Say so instead of looping on a silent
        # "ln: Operation not permitted" forever.
        if [ -e "$plain" ] && [ ! -O "$plain" ]; then
            echo "stale $plain owned by another user; needs: sudo rm -f $plain" >&2
            continue
        fi

        ln -sf "$sock" "$plain"
    done
    sleep 3
done
