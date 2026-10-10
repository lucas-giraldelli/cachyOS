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
        # nemo opens the folder with the file selected when given a file
        [ "$action" = default ] && nemo "$FILE" &
    fi
else
    # slurp: "X,Y WxH" → gpu-screen-recorder: "-region WxH+X+Y"
    GEOM=$(slurp) || exit 1
    XY="${GEOM%% *}"
    WH="${GEOM##* }"
    X="${XY%%,*}"
    Y="${XY##*,}"
    W="${WH%%x*}"
    H="${WH##*x}"
    # NVENC refuses frames below ~145 px a side: grow a small selection
    # around its centre to 160 px
    MIN=160
    if [ "$W" -lt $MIN ]; then X=$(( X - (MIN - W) / 2 )); W=$MIN; fi
    if [ "$H" -lt $MIN ]; then Y=$(( Y - (MIN - H) / 2 )); H=$MIN; fi
    [ "$X" -lt 0 ] && X=0
    [ "$Y" -lt 0 ] && Y=0
    REGION="${W}x${H}+${X}+${Y}"

    FILE="$HOME/Videos/rec-$(date +%Y%m%d-%H%M%S).mp4"
    mkdir -p "$HOME/Videos"
    echo "$FILE" > "$FILEFILE"

    # the dock's indicator right away, without waiting for the IPC call
    "${DOCK[@]}" started >/dev/null 2>&1 &
    gpu-screen-recorder -w "$REGION" -f 60 -a "default_output|default_input" -c mp4 -k h264 -q high -o "$FILE" \
        2> /tmp/gsr-recorder.log
    code=$?
    "${DOCK[@]}" stopped >/dev/null 2>&1
    # a recorder that failed says why (the last error line of its log)
    if [ $code -ne 0 ]; then
        notify-send -u critical "Gravação falhou" "$(grep -m1 -i error /tmp/gsr-recorder.log)" --icon=media-record
    fi
fi
