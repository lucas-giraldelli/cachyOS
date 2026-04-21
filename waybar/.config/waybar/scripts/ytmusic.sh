#!/usr/bin/env bash

for player in $(playerctl -l 2>/dev/null | grep chromium); do
    title=$(playerctl -p "$player" metadata title 2>/dev/null)
    [ -z "$title" ] && continue
    echo "$title" | grep -qi "whatsapp" && continue

    artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
    echo "$artist" | grep -qi "whatsapp" && continue

    status=$(playerctl -p "$player" status 2>/dev/null)

    if [ "$status" = "Playing" ]; then
        icon="󰝚"
    else
        icon="󰏤"
    fi

    YTMUSIC_ICON="$icon" YTMUSIC_ARTIST="$artist" YTMUSIC_TITLE="$title" YTMUSIC_STATUS="$status" \
    python3 -c "
import json, os
icon   = os.environ['YTMUSIC_ICON']
artist = os.environ['YTMUSIC_ARTIST']
title  = os.environ['YTMUSIC_TITLE']
status = os.environ['YTMUSIC_STATUS']
text   = f'{icon}  {artist} - {title}'
print(json.dumps({'text': text, 'class': status.lower(), 'alt': status}, ensure_ascii=False))
"
    exit 0
done

echo '{"text": "", "class": "stopped"}'
