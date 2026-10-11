#!/usr/bin/env bash
# Switch to the "game" submap while a Steam game window has focus, so ALT
# binds (killactive, movefocus, ...) reach the game instead of Hyprland.
# The "game" submap keeps ALT+[0-9], so switching workspaces still works;
# leaving the game window drops back to the normal binds.
# The live wallpaper (mpvpaper) is paused while a game has focus: it is hidden
# anyway and takes most of a core the game needs.

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
            # Ask Hyprland for the real submap: a config reload resets it
            # without telling us. Only touch it when entering or leaving a
            # game, so a manually entered submap (e.g. resize) is left alone.
            current="$(hyprctl submap 2>/dev/null)"
            [ "$current" = default ] && current=""
            if [[ "$class" == steam_app_* ]]; then
                [ "$current" != game ] && hyprctl dispatch submap game > /dev/null
                pkill -STOP -x mpvpaper
            else
                [ "$current" = game ] && hyprctl dispatch submap reset > /dev/null
                pkill -CONT -x mpvpaper
            fi
            ;;
    esac
done
