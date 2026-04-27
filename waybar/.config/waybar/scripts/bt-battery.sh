#!/bin/bash

# Read battery for all connected BT devices via Serial Port Profile (AT commands)

OUTPUT_TEXT=""
OUTPUT_TOOLTIP=""
HAS_BATTERY=false

while IFS= read -r line; do
    MAC=$(echo "$line" | awk '{print $2}')
    NAME=$(echo "$line" | cut -d' ' -f3-)

    RESULT=$(bluetooth_battery "$MAC" 2>/dev/null)
    PERCENT=$(echo "$RESULT" | grep -oP '\d+(?=%)')

    [ -z "$PERCENT" ] && continue

    HAS_BATTERY=true

    if   [ "$PERCENT" -ge 90 ]; then ICON="󰥈"
    elif [ "$PERCENT" -ge 70 ]; then ICON="󰥆"
    elif [ "$PERCENT" -ge 50 ]; then ICON="󰥅"
    elif [ "$PERCENT" -ge 30 ]; then ICON="󰥄"
    elif [ "$PERCENT" -ge 10 ]; then ICON="󰥃"
    else                              ICON="󰥂"
    fi

    OUTPUT_TEXT="${OUTPUT_TEXT}${ICON} ${PERCENT}%  "
    OUTPUT_TOOLTIP="${OUTPUT_TOOLTIP}${NAME}: ${PERCENT}%\n"
done < <(bluetoothctl devices Connected 2>/dev/null)

if ! $HAS_BATTERY; then
    echo '{"text": "", "class": "hidden"}'
    exit 0
fi

OUTPUT_TEXT="${OUTPUT_TEXT%  }"
OUTPUT_TOOLTIP="${OUTPUT_TOOLTIP%\\n}"

printf '{"text": "%s", "tooltip": "%s", "class": "bt-battery"}\n' \
    "$OUTPUT_TEXT" "$OUTPUT_TOOLTIP"
