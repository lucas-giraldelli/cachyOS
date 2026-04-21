#!/usr/bin/env bash

for player in $(playerctl -l 2>/dev/null | grep chromium); do
    title=$(playerctl -p "$player" metadata title 2>/dev/null)
    [ -z "$title" ] && continue

    artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
    status=$(playerctl -p "$player" status 2>/dev/null)
    class=$(echo "$status" | tr '[:upper:]' '[:lower:]')

    if [ "$status" = "Playing" ]; then
        text="󰝚  $artist - $title"
    else
        text="󰏤  $artist - $title"
    fi

    printf '{"text": "%s", "class": "%s", "alt": "%s"}\n' \
        "$text" "$class" "$status"
    exit 0
done

echo '{"text": "", "class": "stopped"}'
