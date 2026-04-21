#!/bin/bash

WHATSAPP_MARKER="web.whatsapp.com"
WHATSAPP_VOLUME="30%"
DEFAULT_VOLUME="100%"

set_volume() {
    mapfile -t wa_pids < <(pgrep -f "$WHATSAPP_MARKER" 2>/dev/null)

    local idx=""
    local pid=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^"Sink Input #"([0-9]+) ]]; then
            idx="${BASH_REMATCH[1]}"
            pid=""
        fi
        if [[ "$line" =~ application\.process\.id\ =\ \"([0-9]+)\" ]]; then
            pid="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ application\.name\ =\ \"Chromium\" ]] && [ -n "$idx" ] && [ -n "$pid" ]; then
            local is_wa=0
            for p in "${wa_pids[@]}"; do
                [ "$pid" = "$p" ] && is_wa=1 && break
            done
            if [ "$is_wa" -eq 1 ]; then
                pactl set-sink-input-volume "$idx" "$WHATSAPP_VOLUME"
            else
                pactl set-sink-input-volume "$idx" "$DEFAULT_VOLUME"
            fi
        fi
    done < <(pactl list sink-inputs)
}

set_volume

pactl subscribe | grep --line-buffered "sink-input" | while read -r event; do
    if echo "$event" | grep -q "'new'"; then
        sleep 0.3
        set_volume
    fi
done
