#!/usr/bin/env bash
# Alt+Print: record a region of the screen, or stop the recording in progress.
# While it records, the smart-shell dock shows a red dot and the elapsed time
# next to the caps lock (a click there stops it too). When it stops, a
# notification says where it was saved; clicking it opens the file in Nemo.

FILEFILE=/tmp/gsr-recorder.file
DOCK=(qs ipc -p "$HOME/projects/smart-shell/shell" call recording)

if pgrep -x gpu-screen-reco > /dev/null; then
    pkill -SIGINT -x gpu-screen-reco
    sleep 0.8
    "${DOCK[@]}" stopped >/dev/null 2>&1

    FILE=$(cat "$FILEFILE" 2>/dev/null)
    if [ -f "$FILE" ]; then
        action=$(notify-send "Gravação salva" "$(basename "$FILE") · clique para abrir" \
            --icon=video-x-generic --action=default=Abrir --wait)
        [ "$action" = default ] && nemo --select "$FILE" &
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

    "${DOCK[@]}" started >/dev/null 2>&1
    gpu-screen-recorder -w region -region "$REGION" -f 60 -a "default_output|default_input" -c mp4 -k h264 -q high -o "$FILE"
    "${DOCK[@]}" stopped >/dev/null 2>&1
fi
