#!/usr/bin/env bash

FILEFILE=/tmp/gsr-recorder.file
NOTIFFILE=/tmp/gsr-recorder.notifid

if pgrep -f gpu-screen-recorder > /dev/null; then
    pkill -SIGINT -f gpu-screen-recorder
    sleep 0.8

    NOTIF_ID=$(cat "$NOTIFFILE" 2>/dev/null)
    [ -n "$NOTIF_ID" ] && gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.CloseNotification \
        "$NOTIF_ID" 2>/dev/null

    FILE=$(cat "$FILEFILE" 2>/dev/null)
    if [ -f "$FILE" ]; then
        notify-send "Gravação salva" "$(basename "$FILE")" --icon=video-x-generic
        nemo --select "$FILE" &
    fi
else
    # slurp: "X,Y WxH" → gpu-screen-recorder: "-region WxH+X+Y"
    GEOM=$(slurp) || exit 1
    XY="${GEOM%% *}"
    WH="${GEOM##* }"
    X="${XY%%,*}"
    Y="${XY##*,}"
    REGION="${WH}+${X}+${Y}"

    FILE="$HOME/Videos/rec-$(date +%Y%m%d-%H%M%S).mp4"
    mkdir -p "$HOME/Videos"
    echo "$FILE" > "$FILEFILE"

    NOTIF_ID=$(notify-send "Gravando..." "Alt+Print para parar" \
        --urgency=critical \
        --icon=media-record \
        --print-id)
    echo "$NOTIF_ID" > "$NOTIFFILE"

    gpu-screen-recorder -w region -region "$REGION" -f 60 -c mp4 -k h264 -q high -o "$FILE"
fi
