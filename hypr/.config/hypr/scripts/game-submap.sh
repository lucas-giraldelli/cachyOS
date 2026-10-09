#!/usr/bin/env bash
# Switch to the "game" submap while a Steam game window has focus, so ALT
# binds (killactive, movefocus, ...) reach the game instead of Hyprland.
# The "game" submap keeps ALT+[0-9], so switching workspaces still works;
# leaving the game window drops back to the normal binds.

SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
current=""

socat -U - UNIX-CONNECT:"$SOCK" | while IFS= read -r line; do
    case "$line" in
        submap\>\>*)
            current="${line#submap>>}"
            ;;
        activewindow\>\>*)
            class="${line#activewindow>>}"
            class="${class%%,*}"
            # Only touch the submap when entering or leaving a game, so a
            # manually entered submap (e.g. resize) is left alone.
            if [[ "$class" == steam_app_* ]]; then
                [ "$current" != game ] && hyprctl dispatch submap game > /dev/null
            elif [ "$current" = game ]; then
                hyprctl dispatch submap reset > /dev/null
            fi
            ;;
    esac
done
