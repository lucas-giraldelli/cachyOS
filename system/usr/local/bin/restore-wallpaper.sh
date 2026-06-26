#!/bin/bash
# Reapply the desktop wallpaper after awww/hyprland package upgrades.
#
# Triggered by a pacman PostTransaction hook. Upgrading awww restarts its
# daemon mid-session, which drops back to a black background; the Hyprland
# exec-once line only runs at login, so nothing reloads the image. This
# script re-enters the user's Wayland session and reapplies it.
#
# Pacman runs hooks as root and outside the user session, so the runtime dir
# and Wayland socket are passed explicitly. No-op when no live session exists
# (e.g. updating from a TTY or over SSH).

USER_NAME=lukesh
UID_NUM=1000
WALLPAPER="/home/${USER_NAME}/Pictures/pkmn.png"
RUNTIME_DIR="/run/user/${UID_NUM}"

# Find a live Wayland socket; bail out if the user isn't in a graphical session.
WL_DISPLAY=""
for sock in "${RUNTIME_DIR}"/wayland-*; do
    if [ -S "$sock" ]; then
        WL_DISPLAY="$(basename "$sock")"
        break
    fi
done
[ -n "$WL_DISPLAY" ] || exit 0

sudo -u "$USER_NAME" \
    XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    WAYLAND_DISPLAY="$WL_DISPLAY" \
    bash -c '
        wp="$1"
        # Try setting directly; if the daemon died or is version-mismatched
        # after the upgrade, restart it and retry once.
        if ! awww img "$wp" 2>/dev/null; then
            pkill -x awww-daemon 2>/dev/null
            sleep 0.5
            setsid awww-daemon >/dev/null 2>&1 &
            sleep 0.7
            awww img "$wp"
        fi
    ' _ "$WALLPAPER"

exit 0
